## Simple Application

### Compiling and Preparing the Application

The code for the application is already ready to go and should compile without issues on debian systems. Below is how you can verify the application compilation and setup locally.

```bash
# Create the required directories.
mkdir -p ~/application/{bin,run,config}

# Compile the application into the application bin.
gcc -Wall -Wextra -O2 src/application.c -o ~/application/bin/application

# Make the application executable,
chmod +x ~/application/bin/application

# Add the application bin to the front of the path.
export PATH="$HOME/application/bin:$PATH"
```

### Configuring the Application

The application is simple but has three configurations for testing. These configurations are stored under the application configuration file path which is always set to `/home/$USER/application/config/CONFIG_FILE`. The configuration file is tab seperated and has the ability to have comments with `#` as denoted. As an example you can save the configuration as below as apart of your configuration file:

```bash
# APPLICATION_RUN_INTERVAL: seconds between updates.
# APPLICATION_PID_FILE: output file for the application process id.
# APPLICATION_DATA_FILE: output file where the application data is written to.
APPLICATION_RUN_INTERVAL        3
APPLICATION_PID_FILE            /home/${USER}/application/run/application.pid
APPLICATION_DATA_FILE           /home/${USER}/application/run/application.data
```

### Using the Application

The application has five generic commands: start, stop, restart, status, and help. Each of these commands have the following effects when ran.

```bash
# Starts the application writing to the specified pid & data files.
application start

# Stops the application cleanly, removes data and pid files.
application stop

# Stops the application cleanly, then starts the application again.
application restart

# Checks if the application is running via the pid file and outputs to terminal.
application status

# Describes each command and lists the functions of the application.
application help
```