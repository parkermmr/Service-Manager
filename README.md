# Service Manager - Docker-based Development Environment

A complete Docker-based infrastructure for managing multi-node development environments with Ansible automation, Prometheus monitoring, and Grafana visualization.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Usage](#usage)
  - [Building Images](#building-images)
  - [Deploying Nodes](#deploying-nodes)
  - [Managing Services](#managing-services)
  - [Ansible Automation](#ansible-automation)
- [Configuration](#configuration)
- [Monitoring](#monitoring)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)
- [WSL Setup Guide](#wsl-setup-guide)

---

## Overview

Service Manager provides a complete local development environment that simulates a production cluster using Docker containers. Each node runs SSH, Prometheus, Node Exporter, and your custom application, fully configurable via Ansible.

**Architecture:**
- **Base Image**: Ubuntu 22.04 with Prometheus & Node Exporter pre-installed
- **Node Image**: Application runtime with SSH, Ansible support, and non-root user
- **Monitoring Stack**: Centralized Prometheus + Grafana for metrics visualization
- **Automation**: Ansible playbooks for configuration management

---

## Features

- **Multi-stage Docker builds** with aggressive layer caching  
- **Non-root container execution** for security  
- **SSH access** to all nodes via key-based authentication  
- **Prometheus metrics** collection from all nodes  
- **Grafana dashboards** for visualization  
- **Ansible automation** for configuration deployment  
- **Environment activation** script for easy CLI access  
- **Flexible configuration** via environment variables or CLI flags  

---

## Prerequisites

### Quick Install (Ubuntu/Debian)

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
sudo apt install docker.io -y
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose plugin
mkdir -p ~/.docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

# Install Python and pip
sudo apt install python3-pip python3.8-venv -y

# Verify installations
docker --version
docker compose version
python3 --version
```

---

## Quick Start

### 1. Clone Repository

```bash
git clone <repository-url>
cd service-manager
```

### 2. Generate SSH Keys

```bash
# Generate SSH key for Ansible
ssh-keygen -t ed25519 -f ~/.ssh/ansible -C "ansible"

# Press Enter when prompted for passphrase (no passphrase recommended for dev)
```

### 3. Activate Environment

```bash
# Source the activation script
source ./bin/activate.sh

# Your prompt should now show: (service-manager)
```

### 4. Build Images

```bash
# Build all Docker images
build all

# Or build with custom registry
build --registry docker.io --push-registry localhost all
```

### 5. Deploy Cluster

```bash
# Deploy all nodes and monitoring
deploy all

# Verify deployment
deploy status
```

### 6. Access Nodes

```bash
# SSH into any node
ssh -i ~/.ssh/ansible -p 2223 somebody@localhost  # node-1
ssh -i ~/.ssh/ansible -p 2224 somebody@localhost  # node-2
ssh -i ~/.ssh/ansible -p 2225 somebody@localhost  # node-3

# Or use Ansible
cd ansible
ansible all -m ping
```

### 7. Access Monitoring

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)

---

## Project Structure

```
service-manager/
├── bin/
│   ├── activate.sh                 # Environment activation script
│   ├── build.sh                    # Docker build script
│   ├── deploy.sh                   # Deployment script
│   ├── clean.sh                    # Cleanup script
│   └── entrypoint.sh               # Container entrypoint
├── ansible/        
│   ├── ansible.cfg                 # Ansible configuration
│   ├── Makefile                    # Ansible shortcuts
│   ├── inventory/      
│   │   ├── hosts.yaml              # Inventory definition
│   │   ├── group_vars/             # Group variables
│   │   └── host_vars/              # Host-specific variables
│   └── playbooks/      
│       ├── site.yaml               # Main playbook
│       ├── status.yaml             # Status check playbook
│       ├── stop.yaml               # Stop services playbook
│       ├── tasks/                  # Task files
│       └── templates/              # Jinja2 templates
├── application/        
│   ├── src/        
│   │   └── application.c           # Example C application
│   ├── config/                     # Config files (generated)
│   └── bin/                        # Binaries (generated)
├── deployments/        
│   ├── deployment.yaml             # Node cluster deployment
│   └── monitoring.yaml             # Monitoring stack deployment
├── prometheus/     
│   ├── prometheus.yaml             # Per-node Prometheus config
│   ├── prometheus-cluster.yaml     # Cluster-wide config
│   └── alerts.yaml                 # Alert rules
├── Dockerfile.base                 # Base image with Prometheus
├── Dockerfile.node                 # Application node image
├── .env.example                    # Environment variables template
├── .dockerignore                   # Docker ignore patterns
└── README.md                       # This file
```

---

## Usage

### Building Images

The build system uses a multi-stage approach with two images:

1. **Base Image** (`node-base`): Ubuntu + Prometheus + Node Exporter
2. **Node Image** (`node-generic`): Base + Application + SSH + Ansible

```bash
# Activate environment first
source ./bin/activate.sh

# Build everything
build all

# Build with custom registry
build --registry docker.io all

# Build and push to registry
build --registry docker.io --push-registry myregistry.com --push all

# Build only base image
build base

# Build only node image
build node

# Get help
build --help
```

**Build Configuration Options:**

```bash
build [OPTIONS] {base|node|all}

Options:
  --registry REGISTRY          Source registry for Ubuntu (default: docker.io)
  --push-registry REGISTRY     Target registry for built images (default: localhost)
  --version VERSION            Image version tag (default: v1.0.0)
  --user USERNAME              Non-root username (default: somebody)
  --uid UID                    User UID (default: 1000)
  --gid GID                    User GID (default: 1000)
  --github-mirror URL          GitHub mirror URL (default: https://github.com)
  --prometheus-version VER     Prometheus version (default: 3.5.1)
  --node-exporter-version VER  Node Exporter version (default: 1.10.2)
  --push                       Push images after building
```

**Using .env File:**

```bash
# Copy example
cp .env.example .env

# Edit configuration
vim .env

# Build with .env settings
build all
```

### Deploying Nodes

```bash
# Deploy everything (nodes + monitoring)
deploy all

# Deploy only nodes
deploy nodes

# Deploy only monitoring
deploy monitoring

# Check status
deploy status

# View logs
deploy logs node-1

# Stop services
deploy stop-all
```

### Managing Services

```bash
# Clean up containers
clean containers

# Remove images
clean images

# Remove build cache
clean cache

# Remove everything
clean all

# Docker system prune
clean prune
```

### Ansible Automation

#### Setup Python Virtual Environment

```bash
# Create virtual environment
python3.8 -m venv .venv

# Activate it
source .venv/bin/activate

# Install Ansible
pip install --upgrade pip
pip install ansible

# Verify
ansible --version
```

#### Run Playbooks

```bash
cd ansible

# Deploy application configurations
ansible-playbook playbooks/site.yaml

# Deploy only to node-1
ansible-playbook playbooks/site.yaml --limit node-1

# Deploy only metrics
ansible-playbook playbooks/site.yaml --tags metrics

# Check service status
ansible-playbook playbooks/status.yaml

# Stop all services
ansible-playbook playbooks/stop.yaml

# Or use Make shortcuts
make deploy
make status
make stop
```

#### Ansible Inventory

**Hosts** (`inventory/hosts.yaml`):

```yaml
all:
  children:
    nodes:
      hosts:
        node-1:
          ansible_host: localhost
          ansible_port: 2223
          node_id: 1
        node-2:
          ansible_host: localhost
          ansible_port: 2224
          node_id: 2
        node-3:
          ansible_host: localhost
          ansible_port: 2225
          node_id: 3
```

**SSH Configuration** (`~/.ssh/config`):

```
Host node-1
    Hostname localhost
    Port 2223
    User somebody
    IdentityFile ~/.ssh/ansible

Host node-2
    Hostname localhost
    Port 2224
    User somebody
    IdentityFile ~/.ssh/ansible

Host node-3
    Hostname localhost
    Port 2225
    User somebody
    IdentityFile ~/.ssh/ansible
```

---

## Configuration

### Environment Variables

Create a `.env` file in the project root:

```bash
# Docker Registry Configuration
REGISTRY=docker.io
PUSH_REGISTRY=localhost
VERSION=v1.0.0

# User Configuration
USERNAME=somebody
USER_UID=1000
USER_GID=1000

# Mirror Configuration
GITHUB_MIRROR=https://github.com

# Prometheus Configuration
PROMETHEUS_VERSION=3.5.1
NODE_EXPORTER_VERSION=1.10.2
```

### Node Configuration

Each node can be configured individually via `ansible/inventory/host_vars/`:

**node-1.yaml:**
```yaml
---
hostname: node-1
application_run_interval: 3
```

**node-2.yaml:**
```yaml
---
hostname: node-2
application_run_interval: 5
```

### Application Configuration Template

The application config is generated from `ansible/playbooks/templates/application-config.j2`:

```jinja2
# Application Configuration for {{ inventory_hostname }}
APPLICATION_RUN_INTERVAL        {{ application_run_interval | default(3) }}
APPLICATION_PID_FILE            {{ app_dir }}/run/application.pid
APPLICATION_DATA_FILE           {{ app_dir }}/run/application.data
```

---

## Monitoring

### Prometheus

**Access**: http://localhost:9090

**Configuration**:
- Per-node config: `prometheus/prometheus.yaml` (copied into each container)
- Cluster config: `prometheus/prometheus-cluster.yaml` (used by central Prometheus)

**Targets**:
- Prometheus itself (9090)
- Node Exporter on each node (9100-9103)

**Example Queries**:
```promql
# CPU usage
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100
```

### Grafana

**Access**: http://localhost:3000  
**Default Credentials**: admin/admin

**Setup**:

1. Add Prometheus data source:
   - URL: `http://prometheus:9090`
   - Access: Server (default)

2. Import dashboard:
   - Dashboard ID: `1860` (Node Exporter Full)
   - Or upload: `prometheus/dashboards/node-exporter-full.json`

### Alert Rules

Alert rules are defined in `prometheus/alerts.yaml`:

- **NodeDown**: Node unreachable for 2+ minutes
- **HighCpuUsage**: CPU > 80% for 5+ minutes
- **HighMemoryUsage**: Memory > 85% for 5+ minutes
- **HighDiskUsage**: Disk > 85% for 5+ minutes

---

## Advanced Usage

### Custom Application Deployment

1. **Add your application source** to `application/src/`

2. **Update entrypoint.sh** compilation section:
```bash
if [ -f "$APP_SRC" ]; then
    echo "[entrypoint] Compiling application..."
    gcc -Wall -Wextra -O2 "$APP_SRC" -o "$APP_BIN"
    chmod +x "$APP_BIN"
fi
```

3. **Deploy configuration** via Ansible:
```bash
cd ansible
ansible-playbook playbooks/site.yaml --tags application
```

### Multi-Registry Workflow

```bash
# Build from Docker Hub, tag locally
build --registry docker.io --push-registry localhost all

# Build locally, push to private registry
build --registry localhost --push-registry myregistry.com --push all

# Pull from private, push to Docker Hub
build --registry myregistry.com --push-registry docker.io/myuser --push all
```

### Scaling Nodes

1. **Update** `deployments/deployment.yaml`:
```yaml
node-4:
  image: ${REGISTRY:-localhost}/node-generic:${VERSION:-v1.0.0}
  container_name: node-4
  hostname: node-4
  ports:
    - "2226:2222"
    - "9104:9100"
  # ... rest of config
```

2. **Add to inventory** (`ansible/inventory/hosts.yaml`):
```yaml
node-4:
  ansible_host: localhost
  ansible_port: 2226
  node_id: 4
```

3. **Create host vars** (`ansible/inventory/host_vars/node-4.yaml`):
```yaml
---
hostname: node-4
application_run_interval: 3
```

4. **Deploy**:
```bash
deploy nodes
```

---

## Troubleshooting

### Containers Won't Start

```bash
# Check logs
deploy logs node-1

# Common issue: Permission denied creating directories
# Solution: Rebuild images
clean images
build all
deploy all
```

### SSH Connection Refused

```bash
# Check if SSH is running in container
docker exec node-1 pgrep sshd

# Check SSH logs
docker exec node-1 cat /home/somebody/.ssh/sshd_config

# Verify public key is mounted
docker exec node-1 cat /home/somebody/.ssh/authorized_keys

# Test connection
ssh -vvv -i ~/.ssh/ansible -p 2223 somebody@localhost
```

### Ansible Can't Connect

```bash
# Test connectivity
cd ansible
ansible all -m ping

# Check inventory
ansible-inventory --list

# Verify SSH key
ssh -i ~/.ssh/ansible -p 2223 somebody@localhost

# Check known_hosts conflicts
vim ~/.ssh/known_hosts  # Remove conflicting entries
```

### Prometheus Not Scraping

```bash
# Check Prometheus targets
# Visit: http://localhost:9090/targets

# Check if Node Exporter is running
ansible all -m shell -a "pgrep node_exporter"

# Restart metrics services
cd ansible
ansible-playbook playbooks/site.yaml --tags metrics
```

### Port Already in Use

```bash
# Find process using port
lsof -i :2223

# Kill process or change port in deployments/deployment.yaml
```

### Build Cache Issues

```bash
# Remove all build cache
clean cache

# Nuclear option - remove everything
clean all
docker system prune -af --volumes
```

---

## WSL Setup Guide

### Understanding WSL and Network Architecture

Before diving into the setup, it's important to understand what WSL (Windows Subsystem for Linux) is and how networking works in this context.

**What is WSL?**

WSL is a compatibility layer developed by Microsoft that allows you to run a Linux distribution directly on Windows without the overhead of a traditional virtual machine. There are two versions:

- **WSL 1**: Translates Linux system calls to Windows system calls in real-time
- **WSL 2**: Uses a lightweight virtual machine with a real Linux kernel (recommended)

**Why Use WSL as an SSH Server?**

Using WSL as an SSH-forwarded server host provides several benefits:

1. **Native Linux Development**: Full Linux environment on Windows
2. **IDE Integration**: Connect VSCode, IntelliJ, etc. as remote hosts
3. **Network Accessibility**: Other devices on your local network can access it
4. **Resource Efficiency**: Lower overhead than full VMs
5. **Persistent Environment**: Maintains state across reboots (with proper configuration)

**Network Architecture Overview**

Understanding the network topology is crucial for SSH forwarding:

```
┌──────────────────────────────────────────────────────────────────┐
│                        Your Computer                             │
│                                                                  │
│  ┌──────────────┐         ┌─────────────────────────┐            │
│  │   Windows    │         │         WSL2            │            │
│  │              │         │                         │            │
│  │  Public IP:  │         │  Subnet IP:             │            │
│  │  (from ISP)  │         │  172.x.x.x              │            │
│  │              │         │  (Internal Only)        │            │
│  │  LAN IP:     │         │                         │            │
│  │  192.168.x.x │◄───────►│  Port: 2222 (SSH)       │            │
│  │              │  Proxy  │                         │            │
│  │  localhost   │  via    │                         │            │
│  │  127.0.0.1   │  netsh  │                         │            │
│  └──────────────┘         └─────────────────────────┘            │
│         ▲                                                        │
│         │                                                        │
└─────────┼────────────────────────────────────────────────────────┘
          │
    ┌─────┴──────┐
    │   Router   │  192.168.1.1 (typically)
    │ (Gateway)  │
    └────────────┘
          │
    ┌─────┴──────────┐
    │    Internet    │
    │  (Public IPs)  │
    └────────────────┘
```

**IP Address Classes Explained:**

Understanding IP addressing is essential for network configuration:

| Class | Range | Purpose | Example |
|-------|-------|---------|---------|
| **Internet IPs** | 1.0.0.0 - 223.255.255.255* | Public routing on internet | 8.8.8.8 (Google DNS) |
| **Private Class A** | 10.0.0.0 - 10.255.255.255 | Large private networks | 10.0.0.1 |
| **Private Class B** | 172.16.0.0 - 172.31.255.255 | Medium private networks, **WSL uses this** | 172.18.240.1 |
| **Private Class C (LAN)** | 192.168.0.0 - 192.168.255.255 | Home/small office networks | 192.168.1.100 |
| **Loopback** | 127.0.0.0 - 127.255.255.255 | Local machine only | 127.0.0.1 (localhost) |
| **Link-Local (APIPA)** | 169.254.0.0 - 169.254.255.255 | Auto-assigned when DHCP fails | 169.254.1.1 |

*Excludes reserved private ranges

**How Traffic Flows:**

```
External Request → Router (Public IP) → Computer (LAN IP 192.168.x.x) → 
Port Forward (netsh proxy) → WSL (Subnet IP 172.x.x.x:2222)
```

**Why We Need Port Forwarding:**

WSL's IP address (172.x.x.x) is in a **private subnet** that's only accessible from your Windows host. To make SSH accessible:

1. From your local machine: Use `0.0.0.0:2222` binding
2. From your LAN: Request goes to your computer's LAN IP (192.168.x.x:2222)
3. Windows forwards it to WSL's subnet IP (172.x.x.x:2222)

The `0.0.0.0` address is special - it tells the network interface to listen on **all available network interfaces**, which means:
- localhost (127.0.0.1)
- Your LAN IP (192.168.x.x)
- Any other IPs your computer has

This is what makes the port forward work - traffic coming to ANY IP on port 2222 gets routed to WSL.

---

### Part 1: Installing and Configuring WSL

#### Step 1: Install WSL Ubuntu Distribution

Open **PowerShell as Administrator** and run:

```powershell
# Install Ubuntu distribution
# This downloads and installs Ubuntu from the Microsoft Store
wsl --install --distribution ubuntu
```

**Expected Output:**
```
Installing: Windows Subsystem for Linux
Windows Subsystem for Linux has been installed.
Installing: Ubuntu
Ubuntu has been installed.
The requested operation is successful. Changes will not be effective until the system is rebooted.
```

**If WSL is already installed**, you'll see:
```
Windows Subsystem for Linux is already installed.
```

```powershell
# Set Ubuntu as the default distribution
# This ensures 'wsl' command launches Ubuntu, not another distro
wsl --set-default ubuntu
```

**Expected Output:**
```
The operation completed successfully.
```

**Verify Installation:**

```powershell
# List all installed distributions
wsl --list --verbose
```

**Expected Output:**
```
  NAME      STATE           VERSION
* Ubuntu    Running         2
```

The `*` indicates the default distribution. `VERSION 2` means WSL 2 (recommended).

**If you need to upgrade from WSL 1 to WSL 2:**

```powershell
wsl --set-version Ubuntu 2
```

**First Time Setup:**

When you first launch WSL, you'll be prompted to create a user:

```bash
# Launch WSL
wsl
```

**Expected Prompts:**
```
Installing, this may take a few minutes...
Please create a default UNIX user account. The username does not need to match your Windows username.
For more information visit: https://aka.ms/wslusers
Enter new UNIX username: youruser
New password:
Retype new password:
passwd: password updated successfully
Installation successful!
```

**Important Notes:**
- Your WSL username doesn't need to match your Windows username
- Choose a simple username (lowercase, no spaces)
- Remember this password - you'll need it for `sudo` commands

---

#### Step 2: Generate SSH Keys on Windows

SSH keys provide secure, password-less authentication. We'll generate these on the Windows side first.

```powershell
# Check if you already have SSH keys
Test-Path ~/.ssh/id_rsa
```

**If it returns `False`, generate new keys:**

```powershell
# Generate RSA key pair (4096-bit for security)
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
```

**Expected Prompts and Responses:**

```
Generating public/private rsa key pair.
Enter file in which to save the key (C:\Users\YourName/.ssh/id_rsa):
# ← Press Enter to accept default location

Enter passphrase (empty for no passphrase):
# ← Press Enter for no passphrase (recommended for development)

Enter same passphrase again:
# ← Press Enter again

Your identification has been saved in C:\Users\YourName/.ssh/id_rsa
Your public key has been saved in C:\Users\YourName/.ssh/id_rsa.pub

The key fingerprint is:
SHA256:aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890 your-email@example.com

The key's randomart image is:
+---[RSA 4096]----+
|        .o+.     |
|       . o.o     |
|        o + .    |
|       . = +     |
|        S = o    |
|       . = B .   |
|        . B =    |
|         o =     |
|          .      |
+----[SHA256]-----+
```

**Understanding the Output:**

- **Private key** (`id_rsa`): Keep this SECRET - it's like your password
- **Public key** (`id_rsa.pub`): Safe to share - will be copied to WSL
- **Fingerprint**: Unique identifier for this key
- **Randomart**: Visual representation of the key (for verification)

**Security Note on Passphrases:**

For **production/shared environments**: Use a strong passphrase  
For **personal development machines**: No passphrase is convenient and acceptable

The key provides security because:
1. Private key never leaves your machine
2. Even if someone gets your public key, they can't impersonate you
3. Passphrase adds another layer (but isn't required for basic security)

```powershell
# Get your Windows username (you'll need this later)
echo $env:USERNAME
```

**Expected Output:**
```
YourWindowsUsername
```

**Save this username** - you'll use it multiple times in the following steps.

---

### Part 2: Configuring SSH Server in WSL

Now we'll set up WSL to accept SSH connections.

#### Step 1: Enter WSL and Update System

```powershell
# Enter WSL as your user (replace with your WSL username)
wsl --distribution ubuntu --user youruser
```

You should now see a Linux prompt:
```bash
youruser@COMPUTER-NAME:~$
```

```bash
# Update package lists and upgrade installed packages
# This ensures you have the latest security patches and software versions
sudo apt update && sudo apt upgrade -y
```

**Expected Output:**
```
Hit:1 http://archive.ubuntu.com/ubuntu jammy InRelease
Get:2 http://archive.ubuntu.com/ubuntu jammy-updates InRelease [119 kB]
Get:3 http://archive.ubuntu.com/ubuntu jammy-backports InRelease [109 kB]
Get:4 http://security.ubuntu.com/ubuntu jammy-security InRelease [110 kB]
...
Fetched 25.1 MB in 8s (3,144 kB/s)
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
All packages are up to date.

Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Calculating upgrade... Done
0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
```

**What this does:**
- `apt update`: Refreshes the list of available packages
- `apt upgrade -y`: Installs newer versions of installed packages
- `-y`: Auto-confirms all prompts

---

#### Step 2: Install OpenSSH Server

```bash
# Install OpenSSH Server package
sudo apt install openssh-server -y
```

**Expected Output:**
```
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  ncurses-term openssh-sftp-server ssh-import-id
Suggested packages:
  molly-guard monkeysphere ssh-askpass
The following NEW packages will be installed:
  ncurses-term openssh-server openssh-sftp-server ssh-import-id
0 upgraded, 4 newly installed, 0 to remove and 0 not upgraded.
Need to get 564 kB of archives.
After this operation, 5,782 kB of additional disk space will be used.
...
Setting up openssh-server (1:8.9p1-3ubuntu0.4) ...
Creating SSH2 RSA key; this may take some time ...
3072 SHA256:xXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXx root@COMPUTER-NAME (RSA)
Creating SSH2 ECDSA key; this may take some time ...
256 SHA256:yYyYyYyYyYyYyYyYyYyYyYyYyYyYyYyYyYyYyYyYyYy root@COMPUTER-NAME (ECDSA)
Creating SSH2 ED25519 key; this may take some time ...
256 SHA256:zZzZzZzZzZzZzZzZzZzZzZzZzZzZzZzZzZzZzZzZzZz root@COMPUTER-NAME (ED25519)
...
Processing triggers for ufw (0.36.1-4build1) ...
```

**What gets installed:**
- `openssh-server`: Main SSH daemon
- `openssh-sftp-server`: Secure file transfer support
- Host keys are automatically generated (RSA, ECDSA, ED25519)

```bash
# Start SSH service immediately
sudo service ssh start
```

**Expected Output:**
```
 * Starting OpenBSD Secure Shell server sshd    [ OK ]
```

**Troubleshooting:**

If you see `[ FAIL ]`, check the logs:
```bash
sudo journalctl -u ssh
```

```bash
# Enable SSH to start automatically
# Note: In WSL, systemctl commands may not work as expected
# Use 'service' commands instead
sudo systemctl enable ssh --now
```

**Expected Output:**
```
Synchronizing state of ssh.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install enable ssh
```

**Or you might see (in WSL):**
```
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
```

**This is normal in WSL!** The `service ssh start` command is what matters.

**Verify SSH is Running:**

```bash
# Check if sshd process is running
sudo service ssh status
```

**Expected Output:**
```
 * sshd is running
```

**Or check with ps:**
```bash
ps aux | grep sshd
```

**Expected Output:**
```
root        1234  0.0  0.0  12345  6789 ?        Ss   10:30   0:00 sshd: /usr/sbin/sshd [listener] 0 of 10-100 startups
youruser    5678  0.0  0.0   6543  2109 pts/0    S+   10:31   0:00 grep --color=auto sshd
```

---

#### Step 3: Configure SSH Directory and Permissions

SSH is very strict about file permissions for security. Incorrect permissions will cause authentication to fail.

```bash
# Create .ssh directory if it doesn't exist
mkdir -p ~/.ssh

# Set directory permissions to 700 (rwx------)
# Owner: read, write, execute
# Group: no access
# Others: no access
chmod 700 ~/.ssh
```

**No output means success.**

**Verify:**
```bash
ls -la ~/ | grep .ssh
```

**Expected Output:**
```
drwx------  2 youruser youruser 4096 Feb  7 10:35 .ssh
```

**Understanding Permissions:**

The `drwx------` breaks down as:
- `d`: Directory
- `rwx`: Owner can read, write, execute
- `---`: Group has no permissions
- `---`: Others have no permissions

**Why 700?**  
SSH refuses to use directories/files that could be read or modified by other users, as this could allow someone to inject their own keys.

---

#### Step 4: Copy Windows SSH Public Key to WSL

Now we'll authorize your Windows SSH key to access WSL.

```bash
# Copy public key from Windows to WSL authorized_keys
# Replace 'YourWindowsUsername' with your actual Windows username from Step 2
cat /mnt/c/Users/YourWindowsUsername/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
```

**Expected Output:**  
None (silence means success)

**How Windows drives are mounted in WSL:**
- C: drive → `/mnt/c/`
- D: drive → `/mnt/d/`
- etc.

**Verify the key was added:**

```bash
cat ~/.ssh/authorized_keys
```

**Expected Output:**
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDExampleKeyContentHereThisIsVeryLong...
...moreKeyContent... your-email@example.com
```

**You should see:**
- `ssh-rsa` (or `ssh-ed25519` if you used that algorithm)
- A long string of random-looking characters
- Your email or comment at the end

```bash
# Set correct permissions on authorized_keys (600 = rw-------)
chmod 600 ~/.ssh/authorized_keys
```

**Verify:**
```bash
ls -la ~/.ssh/
```

**Expected Output:**
```
total 12
drwx------ 2 youruser youruser 4096 Feb  7 10:40 .
drwxr-xr-x 5 youruser youruser 4096 Feb  7 10:40 ..
-rw------- 1 youruser youruser  741 Feb  7 10:40 authorized_keys
```

**Critical:** `authorized_keys` must be `-rw-------` (600). Any other permissions and SSH will ignore it.

---

#### Step 5: Configure SSH to Use Port 2222

We change the default SSH port from 22 to 2222 to avoid conflicts with Windows OpenSSH (if installed).

```bash
# Open SSH daemon configuration file
# You can use vim, nano, or any editor you prefer
sudo vim /etc/ssh/sshd_config

# If you prefer nano:
# sudo nano /etc/ssh/sshd_config
```

**Find the line that says:**
```
#Port 22
```

**Change it to:**
```
Port 2222
```

**Remove the `#` to uncomment it!**

**In vim:**
1. Press `/` to search
2. Type `Port` and press Enter
3. Press `i` to enter insert mode
4. Make your changes
5. Press `Esc` to exit insert mode
6. Type `:wq` and press Enter to save and quit

**In nano:**
1. Use arrow keys to navigate
2. Edit the line
3. Press `Ctrl+X` to exit
4. Press `Y` to confirm save
5. Press `Enter` to confirm filename

**Verify your changes:**
```bash
grep "^Port" /etc/ssh/sshd_config
```

**Expected Output:**
```
Port 2222
```

**Important:** Make sure there's no `#` at the start of the line!

```bash
# Restart SSH service to apply changes
sudo service ssh restart
```

**Expected Output:**
```
 * Restarting OpenBSD Secure Shell server sshd    [ OK ]
```

**Verify SSH is listening on port 2222:**

```bash
sudo netstat -tlnp | grep sshd
```

**Expected Output:**
```
tcp        0      0 0.0.0.0:2222            0.0.0.0:*               LISTEN      1234/sshd: /usr/sbi
tcp6       0      0 :::2222                 :::*                    LISTEN      1234/sshd: /usr/sbi
```

**What this shows:**
- SSH is listening on `0.0.0.0:2222` (IPv4, all interfaces)
- SSH is listening on `:::2222` (IPv6, all interfaces)
- Process ID 1234 is running the SSH daemon

**If `netstat` isn't installed:**
```bash
sudo apt install net-tools -y
```

---

#### Step 6: Set Default WSL User

This ensures WSL always launches with your user account, not root.

```bash
# Open or create WSL configuration file
sudo vim /etc/wsl.conf

# Or with nano:
# sudo nano /etc/wsl.conf
```

**Add the following content:**
```toml
[user]
default=youruser
```

**Replace `youruser` with your actual WSL username!**

**If the file already has content**, just add the `[user]` section at the end.

**Save and exit** (`:wq` in vim, `Ctrl+X` then `Y` then `Enter` in nano)

**Verify:**
```bash
cat /etc/wsl.conf
```

**Expected Output:**
```toml
[user]
default=youruser
```

**This change takes effect after WSL restarts** (we'll do that later).

---

#### Step 7: Get WSL IP Address

WSL 2 uses a virtual network adapter with a dynamic IP address that can change on reboot.

```bash
# Get the primary IP address of WSL
hostname -I | awk '{print $1}'
```

**Expected Output:**
```
172.18.240.1
```

**Your IP will likely be different!** It will be in the range:
- `172.16.0.0` to `172.31.255.255` (Private Class B range)

**Alternative method:**
```bash
ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1
```

**Expected Output:**
```
172.18.240.1
```

**Important:** Write down this IP address! You'll need it in the next section.

**Note:** This IP can change when you restart WSL or Windows. Later, we'll discuss methods to make it static.

---

### Part 3: Windows Network Configuration

Now we configure Windows to forward SSH traffic to WSL.

#### Step 1: Exit WSL and Open PowerShell as Administrator

```bash
# Exit WSL
exit
```

**In Windows:**
1. Press `Win + X`
2. Select "Windows PowerShell (Admin)" or "Terminal (Admin)"
3. If prompted by UAC, click "Yes"

---

#### Step 2: Configure Port Forwarding

This is where the networking magic happens. We're creating a proxy that forwards traffic from your computer's network interfaces to WSL's subnet.

```powershell
# Create port forward from all interfaces (0.0.0.0) port 2222 to WSL port 2222
# Replace <WSL-IP> with the IP address from Step 7
netsh interface portproxy add v4tov4 `
  listenport=2222 `
  listenaddress=0.0.0.0 `
  connectport=2222 `
  connectaddress=172.18.240.1
```

**CRITICAL: Replace `172.18.240.1` with YOUR actual WSL IP!**

**Expected Output:**
```
Ok.
```

**Understanding the Command:**

Let's break down what this does:

```
netsh interface portproxy add v4tov4
```
- `netsh`: Network Shell (Windows network configuration tool)
- `interface portproxy`: Configure port forwarding/proxying
- `add v4tov4`: Add a new IPv4-to-IPv4 proxy rule

```
listenport=2222
listenaddress=0.0.0.0
```
- Listen on port 2222
- On ALL network interfaces (`0.0.0.0` means "any IP this computer has")

```
connectport=2222
connectaddress=172.18.240.1
```
- Forward traffic to port 2222
- On WSL's IP address

**The Traffic Flow:**

```
Your Computer's Network Interfaces:
├── 127.0.0.1:2222 (localhost)
├── 192.168.1.100:2222 (LAN IP)
└── Any other IPs:2222

         ↓ (Port Forward via netsh)

WSL Subnet:
└── 172.18.240.1:2222 (SSH Server)
```

**Why `0.0.0.0`?**

By binding to `0.0.0.0`, we're saying "accept connections from ANY of my computer's IP addresses." This means:

1. **From the same computer:**  
   `ssh -p 2222 localhost` → Works

2. **From another computer on your LAN:**  
   `ssh -p 2222 192.168.1.100` → Works (where 192.168.1.100 is your computer's LAN IP)

3. **From your phone on WiFi:**  
   `ssh -p 2222 192.168.1.100` → Works

If we used `127.0.0.1` instead, only connections from localhost would work.

**Verify the proxy is active:**

```powershell
netsh interface portproxy show v4tov4
```

**Expected Output:**
```
Listen on ipv4:             Connect to ipv4:

Address         Port        Address         Port
--------------- ----------  --------------- ----------
0.0.0.0         2222        172.18.240.1    2222
```

**If you need to delete/modify the rule:**

```powershell
# Delete existing rule
netsh interface portproxy delete v4tov4 listenport=2222 listenaddress=0.0.0.0

# Then add a new one with correct IP
netsh interface portproxy add v4tov4 listenport=2222 listenaddress=0.0.0.0 connectport=2222 connectaddress=<NEW-WSL-IP>
```

---

#### Step 3: Configure Windows Firewall

Windows Firewall blocks incoming connections by default. We need to create a rule to allow SSH traffic.

```powershell
# Create firewall rule to allow inbound TCP traffic on port 2222
netsh advfirewall firewall add rule `
  name="WSL SSH" `
  dir=in `
  action=allow `
  protocol=TCP `
  localport=2222
```

**Expected Output:**
```
Ok.
```

**Understanding the Command:**

```
name="WSL SSH"
```
- Human-readable name for the rule (you'll see this in Windows Firewall)

```
dir=in
```
- Direction: inbound (traffic coming TO your computer)
- `out` would be for outbound traffic

```
action=allow
```
- Allow this traffic through
- Alternative: `block` would deny it

```
protocol=TCP
```
- Only allow TCP protocol (SSH uses TCP, not UDP)

```
localport=2222
```
- Only allow on port 2222
- Doesn't affect other ports

**Verify the firewall rule:**

```powershell
netsh advfirewall firewall show rule name="WSL SSH"
```

**Expected Output:**
```
Rule Name:                            WSL SSH
----------------------------------------------------------------------
Enabled:                              Yes
Direction:                            In
Profiles:                             Domain,Private,Public
Grouping:
LocalIP:                              Any
RemoteIP:                             Any
Protocol:                             TCP
LocalPort:                            2222
RemotePort:                           Any
Edge traversal:                       No
Action:                               Allow
```

**Security Implications:**

This rule allows ANY device on your network to attempt SSH connection to port 2222. However:

 **You're still protected because:**
- SSH requires the private key (`id_rsa`) to authenticate
- Without the key, connections will be refused
- If you didn't set a password on the key, someone would need to steal the file from your computer

 **Best practices:**
- Only use on trusted networks (home/office)
- On public WiFi, consider disabling this rule or using a VPN
- Never share your private key (`id_rsa`)
- The public key (`id_rsa.pub`) is safe to share

**To temporarily disable the rule:**

```powershell
netsh advfirewall firewall set rule name="WSL SSH" new enable=no
```

**To re-enable:**

```powershell
netsh advfirewall firewall set rule name="WSL SSH" new enable=yes
```

**To delete the rule completely:**

```powershell
netsh advfirewall firewall delete rule name="WSL SSH"
```

---

### Part 4: Testing and Configuring SSH Access

#### Step 1: Create SSH Config on Windows

SSH config files make connection easier - you can use `ssh wsl` instead of remembering ports and keys.

```powershell
# Create .ssh directory if it doesn't exist
New-Item -ItemType Directory -Force -Path ~/.ssh

# Open SSH config file in Notepad
notepad ~/.ssh/config
```

**If the file doesn't exist**, Notepad will ask "Do you want to create a new file?" - click **Yes**.

**Add the following content:**

```
Host wsl
    Hostname localhost
    Port 2222
    User youruser
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
```

**Replace `youruser` with your WSL username!**

**Save and close Notepad** (`Ctrl+S`, then close)

**Understanding the Config:**

```
Host wsl
```
- This is the alias you'll use: `ssh wsl`
- You can name it anything: `ubuntu`, `dev`, `linux`, etc.

```
Hostname localhost
```
- Connect to localhost (127.0.0.1)
- Since we're on the same machine, localhost works
- From another computer, you'd use your LAN IP

```
Port 2222
```
- Use port 2222 instead of default 22
- Must match the port in WSL's sshd_config

```
User youruser
```
- SSH will log in as this user
- Must match your WSL username

```
IdentityFile ~/.ssh/id_rsa
```
- Use this private key for authentication
- Path to your private key file

```
StrictHostKeyChecking no
```
- Don't prompt about host key changes
- Useful in development since WSL host keys change
- **Don't use this in production!**

**Alternative (more secure) config:**

```
Host wsl
    Hostname localhost
    Port 2222
    User youruser
    IdentityFile ~/.ssh/id_rsa
    UserKnownHostsFile ~/.ssh/known_hosts_wsl
```

This uses a separate known_hosts file for WSL, so changes don't affect other SSH connections.

---

#### Step 2: Test SSH Connection

```powershell
# Connect to WSL via SSH
ssh wsl
```

**First Connection - Expected Output:**

```
The authenticity of host '[localhost]:2222 ([127.0.0.1]:2222)' can't be established.
ED25519 key fingerprint is SHA256:AbCdEfGhIjKlMnOpQrStUvWxYz0123456789ABCDEF.
This key fingerprint will be added to the list of known hosts.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
```

**Type `yes` and press Enter**

```
Warning: Permanently added '[localhost]:2222' (ED25519) to the list of known hosts.
Welcome to Ubuntu 22.04.1 LTS (GNU/Linux 5.15.90.1-microsoft-standard-WSL2 x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage
 
Last login: Fri Feb  7 10:45:00 2025 from 172.18.240.1
youruser@COMPUTER-NAME:~$
```

**Success!** You're now connected to WSL via SSH!

**Subsequent Connections:**

After the first connection, it will connect immediately:

```powershell
ssh wsl
```

```
Welcome to Ubuntu 22.04.1 LTS (GNU/Linux 5.15.90.1-microsoft-standard-WSL2 x86_64)
Last login: Fri Feb  7 11:00:00 2025 from 172.18.240.1
youruser@COMPUTER-NAME:~$
```

**Testing from another device on your network:**

1. Find your Windows computer's LAN IP:
```powershell
ipconfig | Select-String "IPv4"
```

**Expected Output:**
```
   IPv4 Address. . . . . . . . . . . : 192.168.1.100
```

2. From another computer/phone (connected to the same WiFi/LAN):
```bash
ssh -p 2222 youruser@192.168.1.100
```

**Expected:** Same successful connection as above!

**Troubleshooting Connection Issues:**

**Problem: "Connection refused"**

```bash
# Check if SSH is running in WSL
wsl sudo service ssh status

# Check if port proxy is active
netsh interface portproxy show v4tov4

# Check firewall rule
netsh advfirewall firewall show rule name="WSL SSH"
```

**Problem: "Permission denied (publickey)"**

```bash
# Check authorized_keys in WSL
wsl cat ~/.ssh/authorized_keys

# Verify it matches your public key
type ~/.ssh/id_rsa.pub

# Check file permissions in WSL
wsl ls -la ~/.ssh/
```

**Problem: "Host key verification failed"**

This happens when WSL's host keys change (after reinstall, etc.)

```powershell
# Remove old host key
ssh-keygen -R "[localhost]:2222"

# Try connecting again
ssh wsl
```

---

### Part 5: Keeping WSL Running

By default, WSL shuts down when no processes are running. For SSH access, we need to keep it alive.

#### Method 1: Background Sleep Process (Simple)

**Create keepalive script on Windows:**

```powershell
# Create script file
notepad ~/.ssh/wsl_keepalive.vbs
```

**Add this content:**

```vbscript
Set shell = CreateObject("WScript.Shell")
shell.Run "wsl -d Ubuntu -u youruser sleep infinity", 0, False
```

**Replace `youruser` with your WSL username!**

**Save and close Notepad**

**Understanding the Script:**

```vbscript
Set shell = CreateObject("WScript.Shell")
```
- Creates a Windows Script Host shell object
- Allows running commands silently

```vbscript
shell.Run "wsl -d Ubuntu -u youruser sleep infinity", 0, False
```
- `wsl -d Ubuntu`: Launch Ubuntu distribution
- `-u youruser`: As this user
- `sleep infinity`: Run sleep command forever (keeps WSL alive)
- `0`: Hidden window (no visible console)
- `False`: Don't wait for the command to finish

**Run the script:**

```powershell
wscript ~/.ssh/wsl_keepalive.vbs
```

**Expected:** No output, no window - it runs silently in the background

**Verify WSL is running:**

```powershell
wsl --list --verbose
```

**Expected Output:**
```
  NAME      STATE           VERSION
* Ubuntu    Running         2
```

**To run on Windows startup:**

1. Press `Win + R`
2. Type `shell:startup` and press Enter
3. Create a shortcut to `C:\Users\YourName\.ssh\wsl_keepalive.vbs`

**Or via PowerShell:**

```powershell
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\WSL-Keepalive.lnk")
$Shortcut.TargetPath = "$env:USERPROFILE\.ssh\wsl_keepalive.vbs"
$Shortcut.Save()
```

---

#### Method 2: Windows Task Scheduler (More Robust)

This method is more reliable and restarts WSL if it crashes.

**Create the task:**

```powershell
# Create a scheduled task that runs at startup
$action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-d Ubuntu -u youruser sleep infinity"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName "WSL-Keepalive" `
  -Action $action `
  -Trigger $trigger `
  -Principal $principal `
  -Settings $settings `
  -Description "Keep WSL running for SSH access"
```

**Expected Output:**
```
TaskPath                                       TaskName                          State
--------                                       --------                          -----
\                                              WSL-Keepalive                     Ready
```

**Start the task manually:**

```powershell
Start-ScheduledTask -TaskName "WSL-Keepalive"
```

**Verify it's running:**

```powershell
Get-ScheduledTask -TaskName "WSL-Keepalive" | Get-ScheduledTaskInfo
```

**Expected Output:**
```
LastRunTime        : 2/7/2025 11:30:00 AM
LastTaskResult     : 267009
NextRunTime        : 
NumberOfMissedRuns : 0
TaskName           : WSL-Keepalive
TaskPath           : \
```

**To remove the task:**

```powershell
Unregister-ScheduledTask -TaskName "WSL-Keepalive" -Confirm:$false
```

---

#### Method 3: WSL systemd (Most Native - Requires WSL 0.67.6+)

Modern WSL versions support systemd, which can keep services running automatically.

**Enable systemd in WSL:**

```bash
# Add to /etc/wsl.conf
sudo tee -a /etc/wsl.conf > /dev/null <<EOF
[boot]
systemd=true
EOF
```

**Restart WSL:**

```powershell
wsl --shutdown
wsl
```

**Verify systemd is running:**

```bash
ps aux | grep systemd | head -1
```

**Expected Output:**
```
root           1  0.0  0.1  103156 11234 ?        Ss   11:35   0:00 /sbin/init
```

Process 1 should be systemd (or `/sbin/init` which symlinks to systemd).

**Now SSH will stay enabled automatically!**

```bash
sudo systemctl enable ssh
sudo systemctl start ssh
```

---

### Part 6: VSCode Remote Development

VSCode can connect to WSL via SSH and treat it like a remote server.

#### Step 1: Install VSCode Extensions

1. Open **VSCode**
2. Click the **Extensions** icon (four squares) on the left sidebar
3. Search for: `Remote - SSH`
4. Click **Install** on "Remote - SSH" by Microsoft

**You should also install:**
- **Remote - SSH: Editing Configuration Files**
- **Remote Explorer**

#### Step 2: Connect to WSL

**Method A: Using the Remote Icon**

1. Click the **Remote Icon** in the bottom-left corner (looks like `><`)
2. Select **"Connect to Host..."**
3. Select **`wsl`** from the list
4. A new VSCode window will open

**Method B: Using Command Palette**

1. Press `Ctrl+Shift+P` (or `F1`)
2. Type: `Remote-SSH: Connect to Host`
3. Press `Enter`
4. Select `wsl`

**First Connection:**

VSCode will install the VSCode Server on WSL:

```
[11:40:00] Starting VS Code Server...
[11:40:01] Resolving connection to wsl...
[11:40:02] Running script with connection command: ssh -T -D 12345 "wsl" bash
[11:40:03] Installing VS Code Server for Linux...
[11:40:10] VS Code Server for Linux installed
[11:40:11] Server started successfully!
```

**You'll see in the bottom-left corner:**
```
SSH: wsl
```

This means you're connected!

#### Step 3: Open Your Project

1. Click **"Open Folder"** on the Welcome screen  
   OR  
   Press `Ctrl+K Ctrl+O`

2. Navigate to your project directory:
   ```
   /home/youruser/service-manager
   ```

3. Click **OK**

**VSCode is now running on WSL!** Any terminals you open will be in WSL, file saves go to WSL, etc.

#### Step 4: Useful VSCode Extensions for WSL

Install these in your **WSL VSCode** (not Windows):

- **Python** (for Ansible)
- **Docker** (for container management)
- **YAML** (for Ansible/Docker Compose)
- **GitLens** (for git integration)

**To install:**
1. Click Extensions
2. Search for extension
3. Click **Install in SSH: wsl**

---

### Part 7: Advanced Topics

#### Making WSL IP Static

WSL 2's IP changes on reboot. Here are solutions:

**Option 1: Script to Update Port Proxy**

Create `update-wsl-proxy.ps1`:

```powershell
# Get current WSL IP
$wslIP = (wsl hostname -I).Trim()

# Remove old proxy
netsh interface portproxy delete v4tov4 listenport=2222 listenaddress=0.0.0.0

# Add new proxy with current IP
netsh interface portproxy add v4tov4 `
  listenport=2222 `
  listenaddress=0.0.0.0 `
  connectport=2222 `
  connectaddress=$wslIP

Write-Host "Updated port proxy to WSL IP: $wslIP"
```

**Run on startup:**

Add to Task Scheduler or startup folder.

**Option 2: WSL 2 Static IP (Experimental)**

Edit `/etc/wsl.conf` in WSL:

```toml
[network]
generateResolvConf = false
```

Create `/etc/systemd/network/wsl.network`:

```ini
[Match]
Name=eth0

[Network]
Address=172.20.1.2/24
Gateway=172.20.1.1
DNS=8.8.8.8
```

**Restart WSL and update Windows routing.**

This is experimental and may break with WSL updates.

---

#### SSH Key-Based Login Without Password

You've already set this up! But here's what's happening:

1. **Your private key** (`~/.ssh/id_rsa` on Windows) proves your identity
2. **WSL has your public key** (`~/.ssh/authorized_keys`)
3. **SSH uses cryptographic challenge-response** to verify you own the private key
4. **No password is transmitted** over the network

**How it works:**

```
1. Client (Windows): "I want to connect as 'youruser'"
2. Server (WSL):      "Prove you have the private key for this public key"
3. Server (WSL):      [sends encrypted challenge]
4. Client (Windows):  [decrypts with private key, sends response]
5. Server (WSL):      [verifies response matches]
6. Server (WSL):      "Access granted"
```

**Security benefits:**
- No password to steal/guess
- Can't brute-force the key (2048-4096 bits)
- Even if someone intercepts network traffic, they can't replay it
- Private key never leaves your machine

---

#### Troubleshooting WSL Network Issues

**WSL can't reach internet:**

```bash
# Check DNS resolution
ping google.com

# If it fails, manually set DNS
sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
```

**Port proxy not working after Windows update:**

```powershell
# List all proxies
netsh interface portproxy show v4tov4

# If missing, re-add
netsh interface portproxy add v4tov4 `
  listenport=2222 `
  listenaddress=0.0.0.0 `
  connectport=2222 `
  connectaddress=$(wsl hostname -I).Trim()
```

**WSL won't start:**

```powershell
# Check WSL status
wsl --status

# Update WSL
wsl --update

# Restart WSL service
Restart-Service LxssManager
```

**SSH works from localhost but not LAN:**

```powershell
# Check if Windows Firewall is blocking
Test-NetConnection -ComputerName localhost -Port 2222

# From another computer:
Test-NetConnection -ComputerName YOUR_WINDOWS_IP -Port 2222

# If second test fails, firewall is blocking
# Re-add firewall rule:
netsh advfirewall firewall delete rule name="WSL SSH"
netsh advfirewall firewall add rule name="WSL SSH" dir=in action=allow protocol=TCP localport=2222
```

---

### Summary

You now have:

- **WSL 2** installed and configured  
- **SSH Server** running on port 2222  
- **Port forwarding** from Windows to WSL  
- **Firewall rule** allowing SSH access  
- **Key-based authentication** configured  
- **VSCode remote development** setup  
- **Automatic startup** for WSL  

**Quick Reference Commands:**

```powershell
# Windows (PowerShell)
ssh wsl                          # Connect to WSL
wsl --list --verbose             # Check WSL status
wsl --shutdown                   # Shutdown WSL
netsh interface portproxy show v4tov4  # View port forwards
```

```bash
# WSL (Linux)
sudo service ssh status          # Check SSH status
sudo service ssh restart         # Restart SSH
hostname -I                      # Get WSL IP
sudo systemctl enable ssh        # Auto-start SSH
```

**Next Steps:**
- Set up your development environment in WSL
- Configure git in WSL
- Install Docker in WSL
- Clone your projects to `/home/youruser/`

