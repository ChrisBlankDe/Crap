clear

$ErrorActionPreference = "Stop"
$null = mkdir "c:\install" -ErrorAction SilentlyContinue
Start-Transcript -Path "c:\install\pstranscript.txt" -Append
$ScriptBlock = {
    function Write-ToLog {
        param($message)
        Write-Host $message
        $logPath = "c:\install\log.txt"
        $message | Out-File -FilePath $logPath -Append
    }
    function Install-ChocoPackage {
        param($PackageName)
        if ($packageName -notin (choco list -l -r | % { ($_.split('|'))[0] })) {
            Write-ToLog "Install $PackageName from Chocolatey"
            choco install $packageName
        }
        else {
            #Write-ToLog "$PackageName from Chocolatey is aready installed"
        }
    }
}
$ScriptBlock | Out-File "C:\install\HelperFunctions.ps1"
. "C:\install\HelperFunctions.ps1"

if (!(Test-Path "$($env:ProgramData)\chocolatey\choco.exe")) {
    Write-ToLog "Install Choco"
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

Write-ToLog "Set AllowGlobalConfirmation"
choco feature enable -n allowGlobalConfirmation

Install-ChocoPackage -PackageName "git.install"
Install-ChocoPackage -PackageName "git-credential-manager-for-windows"
Install-ChocoPackage -PackageName "notepadplusplus"
Install-ChocoPackage -PackageName "7zip.install"
Install-ChocoPackage -PackageName "nuget.commandline"
Install-ChocoPackage -PackageName "azure-cli"
Install-ChocoPackage -PackageName "azcopy"
#Install-ChocoPackage -PackageName ""

<#
if (!(Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Ignore)) {
    Write-ToLog "Installing NuGet Package Provider"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force -WarningAction Ignore | Out-Null
}

if (-not(Get-InstalledModule -Name DockerMsftProvider -ErrorAction Ignore)) {
    Write-ToLog "Install DockerMsftProvider Module"
    Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
}

if (-Not(Get-Package -Name docker -ProviderName DockerMsftProvider -ErrorAction Ignore)) {
    Write-ToLog "Install docker Package"
    Install-Package -Name docker -ProviderName DockerMsftProvider -Force
}

if (-not(Get-PSRepository -Name PSGallery | ? { $_.InstallationPolicy -eq "Trusted" })) {
    write-ToLog "Set PSGallery as Trusted"
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}
if (-not(Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V | ? { $_.State -eq "Enabled" })) {
    write-ToLog "Enable Microsoft-Hyper-V"
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
}
if (-not(Get-WindowsOptionalFeature -Online -FeatureName Containers | ? { $_.State -eq "Enabled" })) {
    write-ToLog "Enable Containers"
    Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
}
#>

if (-not(Get-InstalledModule -Name bccontainerhelper -ErrorAction Ignore)) {
    Write-ToLog "Install bccontainerhelper"
    Install-Module bccontainerhelper
}

$ScriptBlock = {
    Start-Transcript -Path "c:\install\pstranscript.txt" -Append
    . "C:\install\HelperFunctions.ps1"
    Write-ToLog "Pull Generic Image"
    $BestGenericImage = Get-BestGenericImageName
    docker pull $BestGenericImage
    Stop-Transcript
}
$ScriptBlock | Out-File "C:\install\reboot.ps1"

if (-not(Get-ScheduledTask -TaskName PoShScriptRunner -ErrorAction Ignore)) {
    Write-ToLog "Schedule Task"
    $TaskTrigger = (New-ScheduledTaskTrigger -atstartup)
    $TaskAction = New-ScheduledTaskAction -Execute Powershell.exe -argument "-ExecutionPolicy Bypass -File C:\install\reboot.ps1"
    $TaskUserID = New-ScheduledTaskPrincipal -UserId System -RunLevel Highest -LogonType ServiceAccount
    Register-ScheduledTask -Force -TaskName PoShScriptRunner -Action $TaskAction -Principal $TaskUserID -Trigger $TaskTrigger
}

Write-ToLog "Restart Computer"
Restart-Computer -Delay 60 -Force

Stop-Transcript
