## Service Manager v/ Ansible

1. [WSL Setup](#wsl-setup)
    - [Create a SSH Forwarded WSL Server Host](#creating-a-ssh-forwarded-wsl-server-host)
    - [Opening WSL as a Remote Host in VSCode](#opening-wsl-as-a-remote-host-in-vscode)
2. [Environment Setup](#environment-setup)
    - [Installing Docker and Docker Compose](#installing-docker-and-docker-compose)
    - [Deploying The Ansible Node Servers](#deploying-the-ansible-node-servers)

### WSL Setup

#### Creating a SSH Forwarded WSL Server Host

One of the best ways to utilize WSL is using the subsystem as a forwarded server host. What is meant by a forwarded server host is that the connection is treated as a remote host connection but still sits on the Windows subsystem. Using it as a forwarded host means that it can be connected to from within the Windows host machines local network and can be entered into by other applications like IDEs such as VSCode. This can be done by establishing an ssh connection between the localhost and the WSL subnet. Firstly, open a PowerShell session and:

```powershell
# Install the ubuntu distribution
#
# This distribution should be the default but it never hurts to be explicit.
wsl --install --distribution ubuntu

# Set the default wsl install to ubuntu
#
# This will ensure that when WSL is opened with the plain 'wsl' command
# or using the plain Windows application that the client will also
# enter in as your ubuntu WSL distribution.
wsl --set-default ubuntu
```

Before you enter the WSL environment you will need to ensure you have ssh keys setup for remote access. If you already have some form of ssh key setup you can just utilize those keys, howevever this guide specifies rsa keys specifically.

```powershell
# If you have not already created ssh keys then run the following.
#
# As WSL is not entirely sandboxed (i.e. is not VM) people can still
# access a decent bit of regular Windows from within the subsystem.
# In this guide, users will be opening a forward to enable access to
# WSL via ssh by binding the port to the machines localhost from
# outside the subnet. This means that in theory you can ssh to your
# machines IP address directly to WSL using the provisioned port (2222).
# This in itself is not a problem as you will still require the rsa
# private key to gain this access, and this will only work within your
# routers local network. 
#
# What this means in short, is that you should not share this private
# key as it is not just a development key, and will be used for persistent
# access to your WSL system.
#
# Additionally, a passphrase maybe added, but is not required unless you
# intend to potentially have other users are network administrators using
# your computer. For development on a personal device, I would recommend
# not setting a password.
ssh-keygen -t rsa -b 4096

# Expected Output:
#
# Generating public/private rsa key pair.
# Enter passphrase (empty for no passphrase): 
# Enter same passphrase again: 
# Your identification has been saved in /home/<username>/.ssh/id_rsa
# Your public key has been saved in /home/<username>/.ssh/id_rsa.pub
# The key fingerprint is:
# SHA256:sDGB1m3W6jf5a12L/fKBqQ8aUwm3UPbkBFz4qaDLEbM <username>:<hostname>
# The key's randomart image is:
# ...

# Get you username in PowerShell
echo $env:USERNAME

# Expected Output:
#
# <username>

# Enter the WSL environment.
#
# Enter the username obtained for the command above in the allocated position.
# If you have allocated a username different from this when setting up WSL, then
# in further parts throughout this guide use that when a username is specified
# or required.
wsl --distribution ubuntu --user <username>
```

Within WSL you will want to setup the required dependencies, directories, and keystores to ensure that you can utilize WSL as an ssh server.

```bash
# Update the packages to the most recent versions. This is ideal to ensure
# when installing packages everything is up-to-date, compatitable, and 
# secure for your environment.
sudo apt update

# Install OpenSSH Sever, this is the best generic ssh server used most places.
sudo apt install openssh-server

# Add the server to the system services and enable it so it starts on boot.
sudo service ssh start
sudo systemctl enable ssh --now

# Ensure the .ssh directory exists with correct permissions
#
# If the ssh directory does not have specific strict permissions. In some cases
# ssh connections will terminate due to potential foul-play with file edits
# to files which are intended to be user based.
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Append your Windows public key to authorized_keys by copying it over from
# the base Windows system.
#
# This is the key we generated earlier, if another public key is elected
# for use replace the location with that public key. This assumes your Windows
# drive is mounted at /mnt/c (which is default).
cat /mnt/c/Users/<windows user>/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Set correct permissions (ssh will reject the key if these are too open)
#
# In general, 600 permissions are reccomended for access to authorized keys.
# This is the file which will determine which remote hosts can ssh into your
# machine. As such it requires strict permissions to prevent tampering.
chmod 600 ~/.ssh/authorized_keys
```

Next you will need to change the default port ssh is running on. This is specifically due to the fact ssh is likely running already on your base Windows machine. If this port remains on the default port - 22 - then it will likely cause clashes. The common port which is utilized as an additional ssh port on a machine is often port 2222. This can be updated within the `Port` setting under the `/etc/ssh/sshd_config` file. You will need sudo permissions to update this file which can be done with:

```bash
# Open the file in your editor of choice, i.e. vi, vim, nano
sudo vim /etc/ssh/sshd_config

# Update configuration:
#
# ...
# Port 2222                 <- Update the port here, was likely originally 22
# #AddressFamily any
# #ListenAddress 0.0.0.0
# #ListenAddress ::
# ...
```

After updating the ssh configuration and setting up the server. You can restart the daemon, causing the configurations to reload.

```bash
sudo systemctl daemon-reload
```

Next you will need to setup your default user in WSL. Your computer should default to this user if you only have a singular WSL user but to ensure this user is always used you should add it to WSL's config file. This user will be the one which was found earlier in PowerShell, but in the case when you installed WSL you changed the default username to something else, set that username as the default by updating the `/etc/wsl.conf` file with the following:

```toml
# ...
[user]
default={username}
```

After that is completed, within WSL we want to get the subnet IP address which is assigned to your WSL subsystem. This IP address seperates your WSL instance from your base system but only within a subnet within your system. In the next section, I will explain how these IP addresses work, and how traffic is actually being routed. For now just get the WSL instance IP address by using the below command.

```bash
hostname -I | awk '{print $1}'
```

You can now exit WSL and open a new PowerShell terminal in administrator mode. We need to setup the firewall rules to enable ssh into WSL. This is where we will use the WSL IP address we obtained above.

```powershell
# Setup the proxy into the WSL box.
#
# To explain what is actually happening here we can go through a couple concepts.
# The first being the concept of a proxy.
# What a proxy is in its most basic sense is a network interface
# i.e. protocol + ip address + port - which routes data from one network interface
# to another. For example if you have a public facing network interface you might
# want to use that interface to route data to some private interfaces you don't want
# to expose.
#
# This moves us on to the next topic, network structures. To keep it brief we will cover
# the concepts of ip structures and subnets. Essentially, the way the internet is structured
# is by stringing together a bunch or IP addresses which range from 0.0.0.0 - 255.255.255.255.
# This is specifically referencing IPv4 which has 4,294,967,296 combinations which is derived
# from the address space 2^32. This can be inferred as there are 256 combinations between each
# '.', where 256 can be interpreted as 2^8. Because we have 4 independant positions the address
# space can be represented as 2^8 x 2^8 x 2^8 x 2^8 = 2^32. Although this number seems quite
# large, it in fact is quite small. Recent estimates indicate there might be anywhere between
# ~30 billion and ~75 billion internet connected devices currently; 4.3 billion IP addresses
# could not service those all alone. Thus the idea of subnets (sub-networks) was originally
# created. The idea is essentially, we reserve specific address ranges for specific uses.
# For the purpose of our use we will focus on three types, Internet IPs, LAN IPs, and Private
# IPs. When I talk about ranges these are generally:
# 
# Internet IPs            : 1.0.0.0 to 223.255.255.255           <- With exclusion of private classes
# Private       - Class A : 10.0.0.0 – 10.255.255.255
# Private       - Class B : 172.16.0.0 – 172.31.255.255
# Private (LAN) - Class C : 192.168.0.0 – 192.168.255.255
# Loopback                : 127.0.0.0 – 127.255.255.255          <- Not relevant
# APIPA (Link-Local)      : 169.254.0.0 – 169.254.255.255        <- Not relevant
#
# Essentially the way we get around this IP shortage is that every house (not always anymore),
# bussiness, or other entity has one public IP address. For the general person this is the IP
# that if you ping will hit your router. Then here is where your router comes in; every device
# in your house is assigned a Private Class C (LAN) IP address, and when someone requests your
# computer they will use your public IP address, followed by your internal LAN address. Your
# router receives the request for the public IP address and then routes it to the internal LAN
# address. This follows the simple map of:
#
# Someone sends request -> Router (Internet IP) -> Computer (Private LAN Address)
#
# This is how a lot of communication with the internet actually works in principle. The other
# type we will cover is the Private Class B internet address which will likely be what your
# WSL IP address is bound to. This is used for internal subnets which sit on devices inside a
# LAN (Local Area Network) which are used for routing within a device. So if something wanted
# to reach this IP Address they would have to go through the process of:
#
# Someone sends request -> Router (Internet IP) -> Computer (Private LAN Address) -> Subsystem (Private Class B Address)
#
# This is why we need to setup a proxy. By default this address is private, your local computer cannot by default route
# information to this IP address without setting up a forward. In this case we are using the address 0.0.0.0 to forward
# data coming through on port 2222 to information on port 2222 on our WSL IP. This voodoo magic happens because when we
# bind an address to 0.0.0.0 it tells the computer that we want all traffic on this computer on this port no matter what
# IP to route directly to this specific subnet interface. And this is the case where we use this proxy.
netsh interface portproxy add v4tov4 listenport=2222 listenaddress=0.0.0.0 connectport=2222 connectaddress=<wsl-ip>

# Open the firewall to allow traffic onto ssh port 2222.
#
# This command essentially just allows data to flow from within the local network to your device
# on port 2222 if its using the TCP protocol. Which is the protocol used for data / file transfer.
netsh advfirewall firewall add rule name="WSL SSH" dir=in action=allow protocol=TCP localport=2222
```

After creating all is done, edit on your windows machine you `~/.ssh/config` file to have the contents:

```yaml
Host wsl
    Hostname localhost
    IdentityFile ~/.ssh/id_rsa
    User <username (from powershell)>
    Port 2222
```

#### Opening WSL as a Remote Host in VSCode

A good way to run WSL as a server is to connect via VSCode's remote connection capability. This can be done by using the WSL forwarding server that was created as above. To ensure this works WSL has to be always running, so before we move onto VSCode we need to create a background subprocess for WSL to occupy on the current session.

Create a file under called `~/.ssh/wsl_open.vbs` and enter in the following.

```powershell
Set shell = CreateObject("WScript.Shell")
shell.Run "wsl -d ubuntu -u parke sleep infinity", 0, False
```

Open PowerShell and execute the script as a background task.

```powershell
# Run the Windows script and close the terminal.
wscript ~/.ssh/wsl_open.vbs
```

Next you will need to open VSCode and then:

1. On the left hand side click the four blocks to open the `Extensions` tab.
2. In the search bar on the left under the `EXTENSIONS: MARKETPLACE` enter `Remote - SSH`.
3. Click on `Remote - SSH` and `Install`.
4. On the bottom left hand corner click the remote ssh button (`><`).
5. Select the option `Connect to Host`.
6. Select the host we setup earlier named `wsl`.
7. On the left hand side click `Open Folder`.
8. Select a working folder, and now you are ready to go.

### Environment Setup

#### Installing Docker and Docker Compose

To utilize the remote ansible environment you will need to get docker and docker compose. This is a great way to interact with remote hosts for ansible as it allows you to configure images to mimic the deployment environment. It is also quick and easy to setup across machines which reduces issues with relying on more solid VM options such as multipass which may not work for users already within a VM or which do not have sudo access. Installing docker can be done with the following steps:

```bash
# Update packages and install docker
sudo apt update
sudo apt install docker
```

Next you will need to create the groups for docker to run as non-sudo user.

```bash
# Create the docker group and gid (group id)
sudo groupadd docker

# Add the docker group to the user.
sudo usermod -aG docker $USER

# Update docker groups to apply to new users.
newgrp docker

# Verify that the docker permissions were updated sucessfully for the user.
docker run hello-world

# Expected Output:
#
# Hello from Docker!
# This message shows that your installation appears to be working correctly.
# 
# To generate this message, Docker took the following steps:
#  1. The Docker client contacted the Docker daemon.
#  2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
#     (amd64)
#  3. The Docker daemon created a new container from that image which runs the
#     executable that produces the output you are currently reading.
#  4. The Docker daemon streamed that output to the Docker client, which sent it
#     to your terminal.
# 
# To try something more ambitious, you can run an Ubuntu container with:
#  $ docker run -it ubuntu bash
# 
# Share images, automate workflows, and more with a free Docker ID:
#  https://hub.docker.com/
# 
# For more examples and ideas, visit:
#  https://docs.docker.com/get-started/
```

After installing docker, add the following docker compose plugin to the docker engine by.

```bash
# This will add the docker compose binary from source to docker.
#
# This method is best as it is the most specific, this service manager
# utilizes a version of docker compose >=2.0.0, which this command installs.
# Specific is generally best as package managers for distributions often
# default to older, less desirable versions of specific packages. Installing
# the binary directly is often the best way.
mkdir -p ~/.docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

# Expected Output:
#
#   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                  Dload  Upload   Total   Spent    Left  Speed
#   0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
# 100 57.6M  100 57.6M    0     0  5400k      0  0:00:10  0:00:10 --:--:-- 5434k
```

#### Deploying The Ansible Node Servers

As part of setting up the service manager you will have to setup the node servers (build servers) which allow ansible to connect to remote hosts (psuedo remote hosts in this case using docker). This is all encapsulated in the `./builds/Dockerfile.node` and the `deployment.yaml`. Firstly, you will need to setup some pre-requisites before the node servers are deployed. Namely, the ssh keys required for the node server. This can be done by:

```bash
# Generate the key which will be used to auth into the node servers.
#
# The best type of key for this is 'ed25519' as it is the most modern.
# Some new versions of alpine (which is the distribution being used) do
# not support keys like rsa by default for ssh.
#
# Additionally, it is reccomended to not set a passphrase for the key,
# as the key is just used for a virtual development environment. This will
# make it easier when interfacing with ansible via ssh. To skip entering
# a key passphrase, just click 'Enter' when the prompt comes up.
ssh-keygen -t ed25519 -f ~/.ssh/ansible -C "ansible"

# Expected Output:
#
# Enter same passphrase again: 
# Your identification has been saved in /home/<username>/.ssh/ansible
# Your public key has been saved in /home/username>/.ssh/ansible.pub
# The key fingerprint is:
# SHA256:D//dHVLYZQck1FA1qvR8+WXCpsBK2g8/5D0rMcH3Ryg ansible
# The key's randomart image is:
# ...
```

Afterwhich, you should be able to apply the docker compose deployment directly, as the build is dynamic and baked into the docker compose deployment file.

```bash
# Apply the deployment from the build context
#
# In this case the build context is just the root of the repository.
#
# It is reccomended that the compose is run in detached mode (-d) due
# to the fact once an ssh connection is created with a specific port / ip configuration;
# your machines ssh client saves the hosts ssh key fingerprint as a 'knownhost'.
# If this known host key changes, when attempting to ssh into the remote host
# port / ip combination, it will fail due to security risks with
# MITM (Man In The Middle) Attacks. If the server needs to be restarted, the host
# key fingerprint will need to be removed in the '~/.ssh/known_hosts' file.
docker compose -f deployment.yaml up -d --build

# Expected Output:
#
# ...
# [+] Running 4/4
# ✔ Network builds_default  Created                                                                                                                         0.0s 
# ✔ Container node-1        Started                                                                                                                         0.5s 
# ✔ Container node-2        Started                                                                                                                         0.4s 
# ✔ Container node-3        Started                                                                                                                         0.4s 

# Verify all the containers are up and running
docker container ls

# Expected Output:
#
# CONTAINER ID   IMAGE                 COMMAND                  CREATED             STATUS             PORTS                                                             NAMES
# d15d450687f4   builds-node-1         "/entrypoint.sh"         About an hour ago   Up About an hour   0.0.0.0:2223->22/tcp, [::]:2223->22/tcp                           node-1
# 454312c00d8a   builds-node-2         "/entrypoint.sh"         About an hour ago   Up About an hour   0.0.0.0:2224->22/tcp, [::]:2224->22/tcp                           node-2
# f8b99bb66e7e   builds-node-3         "/entrypoint.sh"         About an hour ago   Up About an hour   0.0.0.0:2225->22/tcp, [::]:2225->22/tcp                           node-3
```