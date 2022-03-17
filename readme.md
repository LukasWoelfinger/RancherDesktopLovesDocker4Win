# Rancher Desktop loves Docker for Windows

This project contains support scripts and information to setup

- Rancher Desktop
- Docker daemon for Windows OS based containers
- docker compose CLI (Windows and WSL)

as more powerfull replacement for Docker Desktop.

## Setup How-To

The overall setup will take place in following steps.

1. Ensure prerequirements for Rancher Desktop are installed
1. Install Rancher Desktop
1. Install Docker daemon for Windows containers
1. Install Docker Compose plugin

### Import PowerShell support methods

To simplify the setup there are several supporters in side the "Install-DockerdWin" PowerShell module. For using it

1. Open a _Windows_ PowerShell instance with elevated permissions.
1. Execute

   ```powershell
   Import-Module '.\Install-DockerdWin.psm1'
   ```

1. All following commands have to be performed within this instance of PowerShell.

### Ensure prerequirements for Rancher Desktop are installed

As mentioned in [Rancher Desktop documentation](https://docs.rancherdesktop.io/getting-started/installation#windows) the vitualization capabilites and Windows Subsystem for Linux needs to be in place. Since we will install Docker daemon for Windows later we also need Container services enabled.

1. Within the _Windows_ PowerShell perform

   ```powershell
   Install-DockerPrerequirements
   ```

1. Restart the system
1. Open _Windows_ PowerShell instance with elevated permissions and [import the module](#import-powershell-support-methods) again
1. Ensure WSL is on latest version by executing `wsl --update` followed by `wsl --shutdown`
   output should be something like this:

   ```powershell
   PS C:\> wsl --update
   Checking for updates...
   No updates are available.
   Kernel version: 5.10.60.1
   PS C:\> wsl --shutdown
   PS C:\>
   ```

   if you get only the wsl help presented after `wsl --update` you will have installed wsl v1. To upgrade to wsl v2 please execute `wsl --install`

1. Restart the system

### Install Rancher Desktop

To install Rancher Desktop, which is a separate solution from Rancher team and _not the classic kubernetes management interface_ from Rancher.com, perform the following steps, after prerequirements are setup:

1. Download and install [Rancher Desktop](https://rancherdesktop.io/).
1. Restart system, if requried
1. Start Rancher Desktop
1. Set your favorit configuration. If you have used Docker Desktop in the past the docker(moby) configuration would be a good choice
1. Open PowerShell / Terminal / PowerShell core and enter `docker version` to check docker for linux is up an running.

### Install Docker daemon for Windows containers

The install method will download the given verion of Docker CLI from gitHub and install it to you local user applications folder. Afterwards it will register and start up the agent.

1. [Prepare your PowerShell](#import-powershell-support-methods)
1. Execute `Install-DockerDeamon`

> **👍** Take care
>
> If there is a warning regarding environment variable DOCKER_HOST is overruling context you should unset the variable to enable usage of docker-win context. To do so execute `$env:DOCER_HOST = $null` in your PowerShell instance.

### Install Docker Compose plugin

Docker compose can be installed with or without installing the Docker daemon for Windows containers. To use it everywhere it should be installed for Docker CLI in Windows and WSL separate.

1. [Prepare your PowerShell](#import-powershell-support-methods) For this case no elevated permissions are required. It can run in PowerShell or PowerShell Core
1. Execute `Install-DockerComposeWin`
1. Check availability with `docker compose version`
1. Switch to "Rancher-Desktop" WSL distribution by enter `wsl -d Rancher-Desktop`
1. Execute `./docker-compose_WSL.sh` > if you are facing issues "Could not resolve host: github.com" please check [Troubleshoot WSL DNS](#Troubleshoot-WSL-DNS)
1. Check availability with `docker compose version`
1. Exit WSL `exit`
1. Exit PowerShell

All done! You should now be able to use docker compose on Windows and Linux containers.

## Troubleshoots and known issues

This section contains known issues and errors you can face while setting up your environment.

### Troubleshoot WSL DNS

In some versions of WSL the DNS is not setup properly. If so, you can add your local networks DNS IP to forward requests. To check if you are in trouble with DNS setup check your internet connection in WSL with `traceroute 1.1.1.1`. You should see the following entries:

```bash
traceroute to 1.1.1.1 (1.1.1.1), 30 hops max, 46 byte packets
 1  host.rancher-desktop.internal (192.168.240.1)  2.131 ms  0.326 ms  0.614 ms
 2  192.168.0.1 (192.168.0.1)  5.748 ms  5.017 ms  5.280 ms
 3  *  *  *
 4  92.79.244.82 (92.79.244.82)  9.306 ms  92.79.244.84 (92.79.244.84)  7.451 ms  8.496 ms
```

The line starting with 1 represents the internal gateway in WSL. Line starting "2" is showing the IP of your local network gateway the (W)LAN you are connected with line "4" we are in the internet ...

Now try to do the same with a domain address. Enter `traceroute github.com` and check the result. If it shows an error _traceroute: bad address 'github.com'_ your WSL is not able to resolve the IP by DNS.

To solve this you can just add your local rancher host DNS to the network configuration in WSL by editing _/etc/resolv.conf_ file. To do so perform the folowing steps:

1. vi /etc/resolv.conf
1. :i
1. Go to end of line press [Enter] and add your local rancher host IP e.g. `nameserver 192.168.240.1` (alternative: Add your local network gateway e.g. `nameserver 192.168.0.1`)
1. Press escape to exit insert mode
1. Enter `:wq` followed by [Enter]
1. Ping google.com or github.com

Now the internet address should be reachable.

### Troubleshoot Kubernetes config issues

If you’re already using Kubernetes contexts in your WSL, you will have to make some changes to you existing ~/kube/config:

1. Backup your existing ~/.kube/config file 😊
1. Backup any existing config files under /mnt/c/Users/**[your-user-id]**/.kube/
1. copy existing ~/.kube/config to /mnt/c/Users/**[your-user-id]**/.kube/:
   `cp ~/.kube/config /mnt/c/Users/**[your-user-id]**/.kube/`
1. “Reset Kubernetes” in Rancher Desktop /Kubernetes Settings. This will create the context for Rancher Desktop in your /mnt/c/Users/**[your-user-id]**/.kube/config
1. Create a symlink of your new, central .kube/config in WSL:
   `ln -s /mnt/c/Users/**[your-user-id]**/.kube/config ~/.kube/config`
1. Now you’re ready to change context to Rancher Desktop even in WSL

<!-- ## Cleanup the mess

You are facing issues due to previous install tryouts or old setup stuff on your disk from other tools? Then it is time to clean up!

1. Unregister Docker Service from  -->
