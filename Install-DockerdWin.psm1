<#
 .Synopsis
  Install Docker daemon for Windows.

 .Description
  Install Docker daemon for Windows. Execute with Windows Powershell (not Core) as administrator. 
  Prerequirements: Installed Service Hyper-V, Compute

 .Parameter Start
  The first month to display.

 .Example
   # Show a default display of this month. TODO
   Show-Calendar

#>

# If error in Azure VM -> upscale to Dv3 edition 
# If error in config -> json cleanup
# if error: error during connect: Get "http://%2F%2F.%2Fpipe%2FdockerDesktopLinuxEngine/v1.24/containers/json": open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified. 
# --> update and shutdown WSL then reset cluster in RancherDesktop  

$ErrorActionPreference = "Stop"
function Check-PSEnvironment {
    if ($PSVersionTable.PSEdition -ne "Desktop") {
        Write-Error "Wrong PowerShell Environment. Please execute in PowerShell Desktop."
    }

    #check for admin priviledges and run as admin
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { 
        # Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit 
        Write-Error "Admin priviledges required. Please run PowerShell with elevated permissions."
    }
}

# Generate, Export and configure TLS Certificate
function GenerateCerts {
    param (
        [Parameter()]
        [String]
        $certPath
    )

    $ErrorActionPreference = "Stop"
    if ([int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"  -Name Release).Release -lt 393295) {
        throw "Your version of .NET framework is not supported for this script, needs at least 4.6+"
    }
    $splat = @{
        type              = "Custom" ;
        KeyExportPolicy   = "Exportable";
        Subject           = "CN=Docker Windows Daemon TLS Root";
        CertStoreLocation = "Cert:\CurrentUser\My";
        HashAlgorithm     = "sha256";
        KeyLength         = 4096;
        KeyUsage          = @("CertSign", "CRLSign");
        TextExtension     = @("2.5.29.19 ={critical} {text}ca=1")
    }
    $rootCert = New-SelfSignedCertificate @splat
    $splat = @{
        Path     = "$certPath\rootCA.cer";
        Value    = "-----BEGIN CERTIFICATE-----`n" + [System.Convert]::ToBase64String($rootCert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks) + "`n-----END CERTIFICATE-----";
        Encoding = "ASCII";
    }
    Set-Content @splat
    $splat = @{
        CertStoreLocation = "Cert:\CurrentUser\My";
        DnsName           = "swarmmanager1", "localhost", "containerhost1";
        Signer            = $rootCert ;
        KeyExportPolicy   = "Exportable";
        Provider          = "Microsoft Enhanced Cryptographic Provider v1.0";
        Type              = "SSLServerAuthentication";
        HashAlgorithm     = "sha256";
        TextExtension     = @("2.5.29.37= {text}1.3.6.1.5.5.7.3.1");
        KeyLength         = 4096;
    }
    $serverCert = New-SelfSignedCertificate @splat
    $splat = @{
        Path     = "$certPath\serverCert.cer";
        Value    = "-----BEGIN CERTIFICATE-----`n" + [System.Convert]::ToBase64String($serverCert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks) + "`n-----END CERTIFICATE-----";
        Encoding = "Ascii"
    }
    Set-Content @splat
 
    $privateKeyFromCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($serverCert)
    $splat = @{
        Path     = "$certPath\privateKey.cer";
        Value    = ("-----BEGIN RSA PRIVATE KEY-----`n" + [System.Convert]::ToBase64String($privateKeyFromCert.Key.Export([System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob), [System.Base64FormattingOptions]::InsertLineBreaks) + "`n-----END RSA PRIVATE KEY-----");
        Encoding = "Ascii";
    }
    Set-Content @splat
 
    $splat = @{
        CertStoreLocation = "Cert:\CurrentUser\My";
        Subject           = "CN=clientCert";
        Signer            = $rootCert ;
        KeyExportPolicy   = "Exportable";
        Provider          = "Microsoft Enhanced Cryptographic Provider v1.0";
        TextExtension     = @("2.5.29.37= {text}1.3.6.1.5.5.7.3.2") ;
        HashAlgorithm     = "sha256";
        KeyLength         = 4096;
    }
    $clientCert = New-SelfSignedCertificate  @splat
    $splat = @{
        Path     = "$certPath\clientPublicKey.cer" ;
        Value    = ("-----BEGIN CERTIFICATE-----`n" + [System.Convert]::ToBase64String($clientCert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks) + "`n-----END CERTIFICATE-----");
        Encoding = "Ascii";
    }
    Set-Content  @splat
    $clientprivateKeyFromCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($clientCert)
    $splat = @{
        Path     = "$certPath\clientPrivateKey.cer";
        Value    = ("-----BEGIN RSA PRIVATE KEY-----`n" + [System.Convert]::ToBase64String($clientprivateKeyFromCert.Key.Export([System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob), [System.Base64FormattingOptions]::InsertLineBreaks) + "`n-----END RSA PRIVATE KEY-----");
        Encoding = "Ascii";
    }
    Set-Content  @splat
}

function Install-DockerDeamon {
    param (
        [Parameter()]
        [String]
        $dockerCliVersion = "20.10.13",
        [int]
        $daemonPort = 2375,
        [string]
        $serviceName = "docker"
    )

    Check-PSEnvironment

    if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
        try {
            Stop-Service $serviceName
        }
        catch {}

        try {
            Remove-DockerDeamon -serviceName $serviceName
        }
        catch {}
    }

    # Try to start prerequired services
    try {
        # On Windows 10 start CmService
        # if([environment]::OSVersion.Version.Build -le 19043)  {
        #     Start-Service CmService 
        # }
        
        Start-Service vmcompute
        Start-Service vmms

        #     throw "CmService not installed or able to start."
        # }
        # if (-not (Start-Service vmcompute)) {
        #     throw "VmCompute not installed or able to start."
        # }
        # if (-not (Start-Service vmms)) {
        #     throw "VmmsService not installed or able to start."
        # }
    }
    catch {
        Write-Error "Prerequired services (containers and Hyper-V) not available or access denied! Please execute Install-DockerPrerequirements"
    }
    $installDir = "$($Env:TEMP)\dockerInstall-$($dockerCliVersion)"
    mkdir "$($installDir)" -Force
    iwr -UseBasicParsing -OutFile "$($installDir)/docker.zip" https://download.docker.com/win/static/stable/x86_64/docker-$dockerCliVersion.zip 
    mkdir $env:LOCALAPPDATA\Docker -Force
    Expand-Archive "$($installDir)\docker.zip" -DestinationPath $env:LOCALAPPDATA -Force
    [Environment]::SetEnvironmentVariable("Path", "$($env:path);$($env:LOCALAPPDATA)\docker", [System.EnvironmentVariableTarget]::Machine)
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

    GenerateCerts -certPath "$($env:LOCALAPPDATA)\docker"

    Add-DockerDeamon -enableTLS $false -daemonPort $daemonPort
    
    docker run hello-world
    Remove-Item "$($installDir)/docker.zip"
    rmdir "$($installDir)"

    #[System.IO.Directory]::GetAccessControl("\\.\pipe\docker_engine") | Format-Table
    #[System.IO.Directory]::SetAccessControl("\\.\pipe\docker_engine", (Get-WMIObject -ClassName Win32_ComputerSystem).Username, [System.Security.AccessControl.FileSystemRights]::FullControl, [System.Security.AccessControl.AccessControlType]::Allow)
    #
    # dockerd  --debug --host tcp://0.0.0.0:3757
    # docker context create docker-win --docker "host=tcp://0.0.0.0:3757"
    #  docker context use docker-win

}
Export-ModuleMember -Function Install-DockerDeamon

function Remove-DockerDeamon {
    param (
        [Parameter()]
        [string]
        $contextName = "docker-win",
        [string]
        $serviceName = "docker"
    )

    Stop-Service $serviceName

    & "$($env:LOCALAPPDATA)\docker\dockerd.exe" --unregister-service `
        --service-name $serviceName

    # [Environment]::SetEnvironmentVariable("DOCKER_HOST", $null, [System.EnvironmentVariableTarget]::User)
    # $env:DOCKER_HOST = $null

    docker context use default
    docker context rm $contextName

}
Export-ModuleMember -Function Remove-DockerDeamon

function Add-DockerDeamon {
    param (
        [Parameter()]
        [bool]
        $enableTLS = $false,
        [int]
        $daemonPort = 2375,
        [string]
        $contextName = "docker-win",
        [string]
        $serviceName = "docker"
    )

    if ($enableTLS) {
        & "$($env:LOCALAPPDATA)\docker\dockerd.exe" --register-service --host tcp://localhost:$daemonPort `
            --service-name $serviceName `
            --tlsverify `
            --tlscacert=$($env:LOCALAPPDATA)\docker\rootca.cer `
            --tlscert=$($env:LOCALAPPDATA)\docker\clientPublicKey.cer `
            --tlskey=$($env:LOCALAPPDATA)\docker\clientPrivateKey.cer
    }
    else {
        & "$($env:LOCALAPPDATA)\docker\dockerd.exe" --register-service --host tcp://localhost:$daemonPort `
            --service-name $serviceName
    }

    # [Environment]::SetEnvironmentVariable("DOCKER_HOST", "tcp://0.0.0.0:$daemonPort", [System.EnvironmentVariableTarget]::User)
    # $env:DOCKER_HOST = [System.Environment]::GetEnvironmentVariable("DOCKER_HOST", "User")

    Start-Service $serviceName

    if ($enableTLS) {
        docker context create docker-win --docker "host=tcp://0.0.0.0:$daemonPort,ca=$($env:LOCALAPPDATA)\docker\rootca.cer,cert=$($env:LOCALAPPDATA)\docker\clientPublicKey.cer,key=$($env:LOCALAPPDATA)\docker\clientPrivateKey.cer"
    }
    else {
        docker context create docker-win --docker "host=tcp://0.0.0.0:$daemonPort"
    }

    docker context use $contextName 
}
Export-ModuleMember -Function Add-DockerDeamon

function Install-DockerPrerequirements {
    Check-PSEnvironment

    Enable-WindowsOptionalFeature -Online -FeatureName "Containers" -All -NoRestart
    Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V" -All

    Write-Warning "Please ensure WSL installed and up to date! (Run wsl --update in elevated shell, and wsl --shutdown in regular one)"
}
Export-ModuleMember -Function Install-DockerPrerequirements

function Uninstall-DockerPrerequirements {
    Check-PSEnvironment

    Disable-WindowsOptionalFeature -Online -FeatureName "Containers" -NoRestart
    Disable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V"
}
Export-ModuleMember -Function Uninstall-DockerPrerequirements

function Start-DockerBackend {
    param (
        [Parameter()]
        [string]
        $serviceName = "docker"
    )

    # Start-Service CmService 
    Start-Service vmcompute 
    Start-Service vmms 
    Start-Service $serviceName
}
Export-ModuleMember -Function Start-DockerBackend

function Stop-DockerBackend {
    param (
        [Parameter()]
        [string]
        $serviceName = "docker"
    )

    Stop-Service $serviceName
    # Stop-Service CmService 
    Stop-Service vmcompute 
    Stop-Service vmms 
}
Export-ModuleMember -Function Stop-DockerBackend


function Install-DockerComposeWin {
    param (
        [Parameter()]
        [String]
        $dcVersion = "v2.3.3"
    )
    $ErrorActionPreference = "Stop"
    
    $dcInstallDir = "$($Env:TEMP)/dockerComsose-$dcVersion" 
    mkdir $dcInstallDir -Force
    Invoke-WebRequest -UseBasicParsing -OutFile "$($dcInstallDir)/docker-compose.exe" https://github.com/docker/compose/releases/download/$dcVersion/docker-compose-windows-x86_64.exe 
    mkdir $ENV:HOMEPATH/.docker/cli-plugins -Force
    Move-Item "$($dcInstallDir)/docker-compose.exe" $ENV:HOMEPATH/.docker/cli-plugins/ -Force
    Remove-Item $dcInstallDir
}
Export-ModuleMember -Function Install-DockerComposeWin