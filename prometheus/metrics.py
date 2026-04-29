#!/usr/bin/env python3
"""
metrics.py - Standalone HTTPS server with mTLS + bcrypt auth
 
Runs a bash command, parses pipe-delimited output with regex,
and serves metrics over HTTPS with:
  - Mutual TLS (client must present a cert signed by your CA)
  - bcrypt password hashing (salted, slow by design)
  - Rate limiting on failed auth attempts
  - Restricted TLS ciphers (no weak suites)
  - Localhost-only binding
 
Expected input format:
    |field|field1|field2|field3|
    |a|0.0|0.0|0.2|
    |an|0.2|0|0.2|
 
Produces:
    custom_field1{field="a"} 0.0
    custom_field3{field="an"} 0.2
 
Dependencies:
    pip install bcrypt
 
Generate your password hash:
    python3 -c "import bcrypt; print(bcrypt.hashpw(b'YOUR_PASSWORD', bcrypt.gensalt(rounds=12)).decode())"
"""
 
import base64
import hmac
import re
import ssl
import subprocess
import sys
import time
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
 
import bcrypt
 

BASH_COMMAND = "your-command-here"
LISTEN_PORT = 9101
METRIC_PREFIX = "custom"
 
# TLS - paths to your certs
TLS_SERVER_CERT = "/etc/prometheus/certs/server.crt"
TLS_SERVER_KEY = "/etc/prometheus/certs/server.key"
TLS_CA_CERT = "/etc/prometheus/certs/ca.crt"
 
# bcrypt auth
# Generate with: python3 -c "import bcrypt; print(bcrypt.hashpw(b'YOUR_PASSWORD', bcrypt.gensalt(rounds=12)).decode())"
AUTH_USERNAME = "prometheus"
AUTH_PASSWORD_BCRYPT = "$2b$12$PUT_YOUR_BCRYPT_HASH_HERE"
 
# Rate limiting
MAX_FAILED_ATTEMPTS = 5        # lock out after this many failures
LOCKOUT_DURATION_SECONDS = 300  # 5 minute lockout
 
# TLS hardening - only strong ciphers
TLS_CIPHERS = (
    "ECDHE+AESGCM:"
    "ECDHE+CHACHA20:"
    "!aNULL:!MD5:!DSS:!RC4:!3DES:!SHA1"
)
 

class AuthRateLimiter:
    """Track failed auth attempts per IP and enforce lockouts."""
 
    def __init__(self, max_attempts, lockout_seconds):
        self.max_attempts = max_attempts
        self.lockout_seconds = lockout_seconds
        self._lock = threading.Lock()
        self._attempts = {}  # ip -> (count, first_failure_time)
 
    def is_locked(self, ip):
        with self._lock:
            if ip not in self._attempts:
                return False
            count, first_time = self._attempts[ip]
            if time.monotonic() - first_time > self.lockout_seconds:
                del self._attempts[ip]
                return False
            return count >= self.max_attempts
 
    def record_failure(self, ip):
        with self._lock:
            now = time.monotonic()
            if ip in self._attempts:
                count, first_time = self._attempts[ip]
                if now - first_time > self.lockout_seconds:
                    self._attempts[ip] = (1, now)
                else:
                    self._attempts[ip] = (count + 1, first_time)
            else:
                self._attempts[ip] = (1, now)
 
    def clear(self, ip):
        with self._lock:
            self._attempts.pop(ip, None)
 
 
rate_limiter = AuthRateLimiter(MAX_FAILED_ATTEMPTS, LOCKOUT_DURATION_SECONDS)
 

def run_command():
    try:
        result = subprocess.run(
            BASH_COMMAND, shell=True,
            capture_output=True, text=True, timeout=30,
        )
        return result.stdout
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return ""
 
 
def parse_output(raw):
    """Parse pipe-delimited table using regex into Prometheus text format."""
    lines = raw.strip().splitlines()
 
    table_rows = []
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#") or re.match(r'^[#\s]+$', line):
            continue
        if re.match(r'^\|.+\|$', line):
            cells = [c.strip() for c in line.strip("|").split("|")]
            if len(cells) >= 2:
                table_rows.append(cells)
 
    if len(table_rows) < 2:
        return ""
 
    header = table_rows[0]
    data = table_rows[1:]
 
    label_key = header[0]
    metric_names = header[1:]
 
    output = []
    for mname in metric_names:
        full = f"{METRIC_PREFIX}_{mname}"
        output.append(f"# HELP {full} Custom metric from bash command")
        output.append(f"# TYPE {full} gauge")
 
    for row in data:
        label_val = row[0]
        for i, mname in enumerate(metric_names):
            if i + 1 < len(row):
                try:
                    val = float(row[i + 1])
                except ValueError:
                    continue
                full = f"{METRIC_PREFIX}_{mname}"
                output.append(f'{full}{{field="{label_val}"}} {val}')
 
    return "\n".join(output) + "\n"
 

def check_basic_auth(headers, client_ip):
    """Validate Basic auth with bcrypt + rate limiting."""
    if rate_limiter.is_locked(client_ip):
        return False, "locked"
 
    auth_header = headers.get("Authorization", "")
    if not auth_header.startswith("Basic "):
        rate_limiter.record_failure(client_ip)
        return False, "missing"
 
    try:
        decoded = base64.b64decode(auth_header[6:]).decode("utf-8")
        username, password = decoded.split(":", 1)
    except Exception:
        rate_limiter.record_failure(client_ip)
        return False, "malformed"
 
    # Constant-time username check
    username_match = hmac.compare_digest(username.encode(), AUTH_USERNAME.encode())
 
    # bcrypt verify (inherently slow - that's the point)
    password_match = bcrypt.checkpw(
        password.encode("utf-8"),
        AUTH_PASSWORD_BCRYPT.encode("utf-8"),
    )
 
    if username_match and password_match:
        rate_limiter.clear(client_ip)
        return True, "ok"
 
    rate_limiter.record_failure(client_ip)
    return False, "invalid"
 

class MetricsHandler(BaseHTTPRequestHandler):
    # Strip server identification headers
    server_version = ""
    sys_version = ""
 
    def do_GET(self):
        client_ip = self.client_address[0]
 
        authed, reason = check_basic_auth(self.headers, client_ip)
        if not authed:
            if reason == "locked":
                self.send_response(429)
                self.send_header("Retry-After", str(LOCKOUT_DURATION_SECONDS))
                self.end_headers()
                self.wfile.write(b"Too many failed attempts\n")
            else:
                self.send_response(401)
                self.send_header("WWW-Authenticate", 'Basic realm="metrics"')
                self.end_headers()
                self.wfile.write(b"Unauthorized\n")
            return
 
        if self.path == "/metrics":
            raw = run_command()
            body = parse_output(raw)
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body.encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()
 
    # Block all other HTTP methods
    def do_POST(self):
        self.send_response(405)
        self.end_headers()
 
    def do_PUT(self):
        self.send_response(405)
        self.end_headers()
 
    def do_DELETE(self):
        self.send_response(405)
        self.end_headers()
 
    def log_message(self, format, *args):
        pass
 
 
def main():
    # Bind to localhost only - not 0.0.0.0
    server = HTTPServer(("127.0.0.1", LISTEN_PORT), MetricsHandler)
 
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(TLS_SERVER_CERT, TLS_SERVER_KEY)
    ctx.load_verify_locations(TLS_CA_CERT)
    ctx.verify_mode = ssl.CERT_REQUIRED          # mTLS - client must present cert
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.set_ciphers(TLS_CIPHERS)
    ctx.options |= ssl.OP_NO_COMPRESSION         # CRIME attack mitigation
    ctx.options |= ssl.OP_NO_RENEGOTIATION       # Renegotiation attack mitigation
 
    server.socket = ctx.wrap_socket(server.socket, server_side=True)
 
    print(f"Serving metrics on https://127.0.0.1:{LISTEN_PORT}/metrics (mTLS + bcrypt auth)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    server.server_close()
 
 
if __name__ == "__main__":
    main()
