import base64
import copy
import logging
import ssl
import threading
from dataclasses import dataclass, field
from pathlib import Path
from typing import (
    Any,
    Callable,
    Dict,
    List,
    Optional,
    Set,
    Tuple,
    Union,
)
from wsgiref.simple_server import make_server
import bcrypt
from prometheus_client import REGISTRY, generate_latest
from prometheus_client.exposition import (
    _get_best_family,
    _get_ssl_ctx,
    _SilentHandler,
    make_wsgi_app,
    ThreadingWSGIServer,
)
from prometheus_client.registry import Collector

logger = logging.getLogger(__name__)


@dataclass
class ServerConfig:
    """
    Validated, immutable-ish snapshot of server configuration.
    """

    port: int = 9090
    addr: str = "0.0.0.0"

    # TLS
    certfile: Optional[str] = None
    keyfile: Optional[str] = None
    protocol: int = ssl.PROTOCOL_TLS_SERVER

    # mTLS
    client_cafile: Optional[str] = None
    client_capath: Optional[str] = None
    client_auth_required: bool = False

    # CN allow-list (empty = allow all authenticated clients)
    allowed_cns: Set[str] = field(default_factory=set)

    # Basic auth: {username: bcrypt_hash}
    basic_auth_users: Dict[str, str] = field(default_factory=dict)

    # Auth realm
    realm: str = "Prometheus"

    def __post_init__(self) -> None:
        self._validate()

    def _validate(self) -> None:
        # TLS pair must be both-or-neither
        if bool(self.certfile) != bool(self.keyfile):
            raise ValueError("Provide both certfile and keyfile, or neither")

        # mTLS requires TLS
        if (self.client_cafile or self.client_capath or self.client_auth_required) \
                and not self.certfile:
            raise ValueError(
                "mTLS settings (client_cafile / client_auth_required) "
                "require TLS — provide certfile and keyfile"
            )

        # CN allow-list requires mTLS
        if self.allowed_cns and not self.client_auth_required:
            raise ValueError(
                "allowed_cns requires client_auth_required=True (mTLS must be on)"
            )

        # Validate bcrypt hashes
        for user, hsh in self.basic_auth_users.items():
            if not hsh.startswith(("$2a$", "$2b$", "$2y$")):
                raise ValueError(
                    f"Hash for user '{user}' is not a valid bcrypt hash.  "
                    f"Generate one with: "
                    f"python -c \"import bcrypt; print(bcrypt.hashpw(b'pw', bcrypt.gensalt(12)).decode())\""
                )

    @property
    def tls_enabled(self) -> bool:
        return bool(self.certfile and self.keyfile)

    @property
    def scheme(self) -> str:
        return "https" if self.tls_enabled else "http"

    @property
    def features(self) -> List[str]:
        f: List[str] = []
        if self.tls_enabled and self.client_auth_required:
            f.append("mTLS")
        elif self.tls_enabled:
            f.append("TLS")
        if self.allowed_cns:
            f.append(f"CN-filter ({len(self.allowed_cns)} CN(s))")
        if self.basic_auth_users:
            f.append(f"basic-auth ({len(self.basic_auth_users)} user(s))")
        return f


class BasicAuthMiddleware:
    """
    WSGI middleware — HTTP Basic Auth with bcrypt password verification.
    """

    def __init__(
        self,
        app: Callable,
        users: Dict[str, str],
        realm: str = "Prometheus",
    ) -> None:
        self.app = app
        self.users = users
        self.realm = realm

    def __call__(self, environ: dict, start_response: Callable) -> Any:
        if not self.users:
            return self.app(environ, start_response)

        if self._authenticate(environ):
            return self.app(environ, start_response)

        start_response(
            "401 Unauthorized",
            [
                ("WWW-Authenticate", f'Basic realm="{self.realm}"'),
                ("Content-Type", "text/plain; charset=utf-8"),
            ],
        )
        return [b"Unauthorized\n"]

    def _authenticate(self, environ: dict) -> bool:
        header = environ.get("HTTP_AUTHORIZATION", "")
        if not header.startswith("Basic "):
            return False

        try:
            decoded = base64.b64decode(header[6:]).decode("utf-8")
            username, password = decoded.split(":", 1)
        except Exception:
            return False

        expected_hash = self.users.get(username)
        if expected_hash is None:
            return False

        return bcrypt.checkpw(
            password.encode("utf-8"),
            expected_hash.encode("utf-8"),
        )


class CNValidationMiddleware:
    """
    WSGI middleware; restrict access by client certificate Common Name.
    """

    def __init__(
        self,
        app: Callable,
        allowed_cns: Set[str],
    ) -> None:
        self.app = app
        self.allowed_cns = allowed_cns

    def __call__(self, environ: dict, start_response: Callable) -> Any:
        if not self.allowed_cns:
            return self.app(environ, start_response)

        cn = self._extract_cn(environ)
        if cn in self.allowed_cns:
            return self.app(environ, start_response)

        logger.warning(
            "CN rejected: %r not in allowed set %s",
            cn, self.allowed_cns,
        )
        start_response(
            "403 Forbidden",
            [("Content-Type", "text/plain; charset=utf-8")],
        )
        msg = f"Forbidden: CN '{cn}' is not in the allow-list\n"
        return [msg.encode("utf-8")]

    @staticmethod
    def _extract_cn(environ: dict) -> Optional[str]:
        """
        Extract the Common Name from the client certificate.
        """
        # Fast path: pre-extracted CN
        cn = environ.get("SSL_CLIENT_S_DN_CN")
        if cn:
            return cn

        # Fallback: parse from the full peercert dict
        peercert = environ.get("peercert")
        if peercert:
            for rdn_seq in peercert.get("subject", ()):
                for key, value in rdn_seq:
                    if key == "commonName":
                        return value

        return None


class PrometheusServer:
    """
    Lifecycle manager for a Prometheus metrics HTTPS server.
    """

    _UNSET = object()

    def __init__(
        self,
        registry: Collector = REGISTRY,
        *,
        port: Union[int, object] = _UNSET,
        addr: Union[str, object] = _UNSET,
        certfile: Union[Optional[str], object] = _UNSET,
        keyfile: Union[Optional[str], object] = _UNSET,
        protocol: Union[int, object] = _UNSET,
        client_cafile: Union[Optional[str], object] = _UNSET,
        client_capath: Union[Optional[str], object] = _UNSET,
        client_auth_required: Union[bool, object] = _UNSET,
        allowed_cns: Union[Optional[Set[str]], object] = _UNSET,
        basic_auth_users: Union[Optional[Dict[str, str]], object] = _UNSET,
        realm: Union[str, object] = _UNSET,
    ) -> None:
        self._registry = registry
        self._config: Optional[ServerConfig] = None

        self._httpd: Optional[ThreadingWSGIServer] = None
        self._thread: Optional[threading.Thread] = None
        self._lock = threading.Lock()

        _fields = {
            "port": port,
            "addr": addr,
            "certfile": certfile,
            "keyfile": keyfile,
            "protocol": protocol,
            "client_cafile": client_cafile,
            "client_capath": client_capath,
            "client_auth_required": client_auth_required,
            "allowed_cns": allowed_cns,
            "basic_auth_users": basic_auth_users,
            "realm": realm,
        }
        provided = {k: v for k, v in _fields.items() if v is not self._UNSET}

        if provided:
            # Normalise set/dict fields that might have been passed as None
            if "allowed_cns" in provided and provided["allowed_cns"] is None:
                provided["allowed_cns"] = set()
            if "basic_auth_users" in provided and provided["basic_auth_users"] is None:
                provided["basic_auth_users"] = {}

            self.load(ServerConfig(**provided))

    @property
    def is_connected(self) -> bool:
        """True if the server thread is running."""
        return self._thread is not None and self._thread.is_alive()

    @property
    def config(self) -> Optional[ServerConfig]:
        """Current loaded configuration (read-only copy)."""
        return copy.copy(self._config) if self._config else None

    def load(
        self,
        config: Union[str, Path, Dict[str, Any], ServerConfig, None] = None,
        *,
        port: Union[int, object] = _UNSET,
        addr: Union[str, object] = _UNSET,
        certfile: Union[Optional[str], object] = _UNSET,
        keyfile: Union[Optional[str], object] = _UNSET,
        protocol: Union[int, object] = _UNSET,
        client_cafile: Union[Optional[str], object] = _UNSET,
        client_capath: Union[Optional[str], object] = _UNSET,
        client_auth_required: Union[bool, object] = _UNSET,
        allowed_cns: Union[Optional[Set[str]], object] = _UNSET,
        basic_auth_users: Union[Optional[Dict[str, str]], object] = _UNSET,
        realm: Union[str, object] = _UNSET,
    ) -> ServerConfig:
        """
        Parse and store server configuration.
        """
        if self.is_connected:
            raise RuntimeError(
                "Cannot load() while connected — call disconnect() first, "
                "or use reload()"
            )

        _fields = {
            "port": port,
            "addr": addr,
            "certfile": certfile,
            "keyfile": keyfile,
            "protocol": protocol,
            "client_cafile": client_cafile,
            "client_capath": client_capath,
            "client_auth_required": client_auth_required,
            "allowed_cns": allowed_cns,
            "basic_auth_users": basic_auth_users,
            "realm": realm,
        }
        overrides = {k: v for k, v in _fields.items() if v is not self._UNSET}

        # Normalise None → empty container for set/dict fields
        if "allowed_cns" in overrides and overrides["allowed_cns"] is None:
            overrides["allowed_cns"] = set()
        if "basic_auth_users" in overrides and overrides["basic_auth_users"] is None:
            overrides["basic_auth_users"] = {}

        # Resolve config source
        if config is None and not overrides:
            raise TypeError("load() requires a config source or keyword arguments")

        if config is None:
            # Pure kwargs → build ServerConfig directly
            cfg = ServerConfig(**overrides)
        elif isinstance(config, ServerConfig):
            if overrides:
                # Merge: start from existing config, apply overrides
                base = {f.name: getattr(config, f.name)
                        for f in config.__dataclass_fields__.values()}
                base.update(overrides)
                cfg = ServerConfig(**base)
            else:
                cfg = config
        elif isinstance(config, dict):
            cfg = self._parse_dict(config)
            if overrides:
                base = {f.name: getattr(cfg, f.name)
                        for f in cfg.__dataclass_fields__.values()}
                base.update(overrides)
                cfg = ServerConfig(**base)
        elif isinstance(config, (str, Path)):
            cfg = self._parse_yaml(config)
            if overrides:
                base = {f.name: getattr(cfg, f.name)
                        for f in cfg.__dataclass_fields__.values()}
                base.update(overrides)
                cfg = ServerConfig(**base)
        else:
            raise TypeError(
                f"config must be str, Path, dict, ServerConfig, or None — "
                f"got {type(config).__name__}"
            )

        self._config = cfg
        logger.info(
            "Configuration loaded: %s://:%d %s",
            cfg.scheme, cfg.port, cfg.features or "(no auth)",
        )
        return cfg

    def connect(self) -> None:
        """
        Start the HTTPS server in a daemon thread.
        """
        with self._lock:
            if self.is_connected:
                raise RuntimeError("Server is already connected")

            cfg = self._config
            if cfg is None:
                raise RuntimeError("No configuration loaded — call load() first")

            # Build WSGI app with middleware chain:
            #   request → CN validation → basic auth → prometheus metrics app
            app: Callable = make_wsgi_app(self._registry)

            if cfg.basic_auth_users:
                app = BasicAuthMiddleware(app, cfg.basic_auth_users, cfg.realm)

            if cfg.allowed_cns:
                app = CNValidationMiddleware(app, cfg.allowed_cns)

            class _Server(ThreadingWSGIServer):
                pass

            _Server.address_family, resolved_addr = _get_best_family(cfg.addr, cfg.port)

            handler_class = self._build_handler(cfg)
            self._httpd = make_server(
                resolved_addr, cfg.port, app, _Server,
                handler_class=handler_class,
            )

            if cfg.tls_enabled:
                context = _get_ssl_ctx(
                    cfg.certfile,
                    cfg.keyfile,
                    cfg.protocol,
                    cafile=cfg.client_cafile,
                    capath=cfg.client_capath,
                    client_auth_required=cfg.client_auth_required,
                )
                self._httpd.socket = context.wrap_socket(
                    self._httpd.socket, server_side=True,
                )

            self._thread = threading.Thread(
                target=self._httpd.serve_forever,
                name="prometheus-metrics-server",
                daemon=True,
            )
            self._thread.start()

            feat = f" [{', '.join(cfg.features)}]" if cfg.features else ""
            logger.info(
                "Connected: %s://%s:%d/metrics%s",
                cfg.scheme, cfg.addr, cfg.port, feat,
            )

    def verify(
        self,
        timeout: float = 5.0,
        cert: Optional[Tuple[str, str]] = None,
        auth: Optional[Tuple[str, str]] = None,
    ) -> bool:
        """
        HEAD the live server to confirm it's healthy.
        """
        if not self.is_connected or self._config is None:
            raise RuntimeError("Server is not connected")

        cfg = self._config
        host = "localhost" if cfg.addr in ("0.0.0.0", "::") else cfg.addr
        url = f"{cfg.scheme}://{host}:{cfg.port}/metrics"

        try:
            return self._verify_requests(url, timeout, cfg, cert, auth)
        except ImportError:
            return self._verify_urllib(url, timeout, cfg, cert, auth)

    @staticmethod
    def _verify_requests(
        url: str,
        timeout: float,
        cfg: ServerConfig,
        cert: Optional[Tuple[str, str]],
        auth: Optional[Tuple[str, str]],
    ) -> bool:
        import requests as req

        kwargs: Dict[str, Any] = {"timeout": timeout}

        if cfg.tls_enabled:
            kwargs["verify"] = cfg.client_cafile or True

        if cert:
            kwargs["cert"] = cert
        if auth:
            kwargs["auth"] = auth

        resp = req.head(url, **kwargs)
        return resp.status_code < 500

    @staticmethod
    def _verify_urllib(
        url: str,
        timeout: float,
        cfg: ServerConfig,
        cert: Optional[Tuple[str, str]],
        auth: Optional[Tuple[str, str]],
    ) -> bool:
        import urllib.request

        ctx: Optional[ssl.SSLContext] = None
        if cfg.tls_enabled:
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            if cfg.client_cafile:
                ctx.load_verify_locations(cfg.client_cafile)
            else:
                ctx.load_default_certs()
            if cert:
                ctx.load_cert_chain(certfile=cert[0], keyfile=cert[1])

        request = urllib.request.Request(url, method="HEAD")
        if auth:
            cred = base64.b64encode(f"{auth[0]}:{auth[1]}".encode()).decode()
            request.add_header("Authorization", f"Basic {cred}")

        handler = urllib.request.HTTPSHandler(context=ctx) if ctx else urllib.request.HTTPHandler()
        opener = urllib.request.build_opener(handler)

        try:
            resp = opener.open(request, timeout=timeout)
            return resp.status < 500
        except urllib.error.HTTPError as e:
            return e.code < 500

    def disconnect(self) -> None:
        """
        Gracefully shut down the server.

        Safe to call even if not connected (no-op).
        """
        with self._lock:
            if self._httpd is not None:
                self._httpd.shutdown()
                self._httpd.server_close()
                self._httpd = None
            if self._thread is not None:
                self._thread.join(timeout=5.0)
                self._thread = None
            logger.info("Disconnected")

    def state(self) -> str:
        """
        Return the raw text that the server would serve at /metrics.
        """
        return generate_latest(self._registry).decode("utf-8")

    def reload(
        self,
        config: Optional[Union[str, Path, Dict[str, Any], ServerConfig]] = None,
        **kwargs,
    ) -> ServerConfig:
        """
        Disconnect, (re-)load configuration, and reconnect.
        """
        self.disconnect()

        if config is not None or kwargs:
            self.load(config, **kwargs)
        elif self._config is None:
            raise RuntimeError("No configuration to reload — provide one")
        else:
            logger.info("Reloading existing configuration")

        self.connect()
        return self._config

    @staticmethod
    def _build_handler(cfg: ServerConfig) -> type:
        class _Handler(_SilentHandler):
            """WSGIRequestHandler that injects SSL peer cert info."""

            def get_environ(self) -> dict:
                environ = super().get_environ()
                if cfg.client_auth_required and hasattr(self.request, "getpeercert"):
                    try:
                        peercert = self.request.getpeercert()
                        if peercert:
                            environ["peercert"] = peercert
                            for rdn_seq in peercert.get("subject", ()):
                                for key, value in rdn_seq:
                                    if key == "commonName":
                                        environ["SSL_CLIENT_S_DN_CN"] = value
                                        break
                    except Exception:
                        pass
                return environ

        return _Handler

    @staticmethod
    def _parse_dict(
        raw: Dict[str, Any],
        base_dir: Optional[Path] = None,
    ) -> ServerConfig:
        """Parse a Prometheus-style config dict into a ServerConfig."""
        tls = raw.get("tls_server_config") or {}

        def _resolve(p: Optional[str]) -> Optional[str]:
            if p and base_dir and not Path(p).is_absolute():
                return str(base_dir / p)
            return p

        auth_type = (tls.get("client_auth_type") or "").lower()
        client_auth = "require" in auth_type and "verify" in auth_type

        raw_cns = raw.get("allowed_cns") or tls.get("allowed_cns") or []
        if isinstance(raw_cns, str):
            raw_cns = [raw_cns]

        return ServerConfig(
            port=raw.get("port", 9090),
            addr=raw.get("addr", "0.0.0.0"),
            certfile=_resolve(tls.get("cert_file")),
            keyfile=_resolve(tls.get("key_file")),
            client_cafile=_resolve(tls.get("client_ca_file")),
            client_capath=_resolve(tls.get("client_capath")),
            client_auth_required=client_auth,
            allowed_cns=set(raw_cns),
            basic_auth_users=raw.get("basic_auth_users") or {},
            realm=raw.get("realm", "Prometheus"),
        )

    @staticmethod
    def _parse_yaml(path: Union[str, Path]) -> ServerConfig:
        """Parse a Prometheus-style web.yml file."""
        try:
            import yaml
        except ImportError:
            raise ImportError(
                "PyYAML is required to load YAML config files: "
                "pip install pyyaml"
            )

        path = Path(path)
        with open(path) as f:
            raw = yaml.safe_load(f) or {}

        return PrometheusServer._parse_dict(raw, base_dir=path.parent)
