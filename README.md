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