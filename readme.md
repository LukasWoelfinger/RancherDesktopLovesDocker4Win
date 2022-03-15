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
1. Open _Windows_ PowerShell instance with elevated permissions and import the module again
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

## Install Rancher Desktop

Download and install [Rancher Desktop](https://rancherdesktop.io/). Afterwards open Rancher Desktop and set your favorit configuration. If you have used Docker Desktop in the past the docker(moby) configuration would be a good choice.
