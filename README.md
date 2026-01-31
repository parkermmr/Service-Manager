#### Create a WSL SSH Forwarding

One of the best ways to utilize WSL is using a the subsystem as a forward or "run server". This can be done by establishing an SSH connection between the localhost and the WSL subnet. Firstly, open a PowerShell session and:

```ps
# Install the ubuntu distribution
wsl --install --distribution ubuntu

# Set the default wsl install to ubuntu
wsl --set-default ubuntu

# Enter the WSL environment as a root user
wsl --distribution ubuntu --user root
```

In WSL as root do the following to change the root password (don't forget this).

```bash
# Change the root passwd
passwd
```

After changing the password, enter the WSL environment as user.

```ps
# Get you username in PowerShell
echo $env:USERNAME

# Enter the WSL environment
wsl --distribution ubuntu --user <username>
```

Within WSL you will want to setup the required items:

```bash
# Install packages and ssh
sudo apt update
sudo apt install openssh-server
sudo service ssh start
sudo systemctl enable ssh --now

# Ensure the .ssh directory exists with correct permissions
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Append your Windows public key to authorized_keys
# This assumes your Windows drive is mounted at /mnt/c
# If you haven't made ssh keys on windows yet, do ssh-keygen -t rsa
cat /mnt/c/Users/<windows user>/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Set correct permissions (SSH will reject the key if these are too open)
chmod 600 ~/.ssh/authorized_keys

# Open /etc/ssh/sshd_config and change 'Port' to 2222

sudo systemctl daemon-reload
```

Next you will need to setup you user in WSL, under the `/etc/wsl.conf` file add the following:

```config
...
[user]
default=<username (from powershell)>
```

After that is completed, within WSL we want to get the subnet IP address which can be obtained with:
```bash
hostname -I | awk '{print $1}'
```

You can now exit WSL and open a new PowerShell terminal in administrator mode. We need to setup the firewall rules to enable ssh into WSL.

```ps
# Setup the proxy into the WSL box
netsh interface portproxy add v4tov4 listenport=2222 listenaddress=0.0.0.0 connectport=2222 connectaddress=<wsl-ip>

# Open the firewall to allow traffic onto ssh port 2222
netsh advfirewall firewall add rule name="WSL SSH" dir=in action=allow protocol=TCP localport=2222
```

After creating all is done, edit on your windows machine you `~/.ssh/config` file to have the contents:

```config
Host wsl
    Hostname localhost
    IdentityFile ~/.ssh/id_rsa
    User <username (from powershell)>
    Port 2222
```

#### Opening WSL as a Remote Host in VSCode

A good way to run WSL as a server is to connect via VSCode's remote connection capability. This can be done by using the WSL forwarding server that was created as above. To ensure this works WSL has to be always running, so before we move onto VSCode we need to create a background subprocess for WSL to occupy on the current session.

Create a file under called `~/.ssh/wsl_open.vbs` and enter in the following.

```ps
Set shell = CreateObject("WScript.Shell")
shell.Run "wsl -d ubuntu -u parke sleep infinity", 0, False
```

Open PowerShell and execute the script as a background task.

```ps
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

#### Installing Docker and Docker Compose WSL

To utilize the remote ansible environment you will need to get Docker and Docker Compose. This can be done with the following steps. Firstly, to install Docker:

```bash
# Update packages and install docker
sudo apt update
sudo apt install docker
```

Next you will need to create the groups for docker to run as non-sudo user.

```bash
# Add the docker group and give permissions to the current user
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

# Verify that the docker permissions were update sucessfully
docker run hello-world
```

After installing docker, add the following docker compose plugin to the docker engine by.

```bash
mkdir -p ~/.docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose
```
