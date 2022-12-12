clear

$ErrorActionPreference = 'Stop'
$null = mkdir 'c:\install' -ErrorAction SilentlyContinue
Start-Transcript -Path 'c:\install\pstranscript.txt' -Append
$ScriptBlock = {
    function Write-ToLog {
        param($message)
        Write-Host $message
        $logPath = 'c:\install\log.txt'
        $message | Out-File -FilePath $logPath -Append
    }
    function Install-ChocoPackage {
        param($PackageName)
        if ($packageName -notin (choco list -l -r | % { ($_.split('|'))[0] })) {
            Write-ToLog "Install $PackageName from Chocolatey"
            choco install $packageName --no-progress
        }
    }
}
$ScriptBlock | Out-File 'C:\install\HelperFunctions.ps1'
. 'C:\install\HelperFunctions.ps1'

#Write-ToLog 'Disabling Server Manager Open At Logon'
#New-ItemProperty -Path 'HKCU:\Software\Microsoft\ServerManager' -Name 'DoNotOpenServerManagerAtLogon' -PropertyType 'DWORD' -Value '0x1' -Force | Out-Null

if (!(Test-Path "$($env:ProgramData)\chocolatey\choco.exe")) {
    Write-ToLog 'Install Choco'
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

Write-ToLog 'Set AllowGlobalConfirmation'
choco feature enable -n allowGlobalConfirmation

Install-ChocoPackage -PackageName '7zip.install'
Install-ChocoPackage -PackageName 'notepadplusplus'
Install-ChocoPackage -PackageName 'git.install'
Install-ChocoPackage -PackageName 'git-credential-manager-for-windows'
Install-ChocoPackage -PackageName 'nuget.commandline'
Install-ChocoPackage -PackageName 'azure-cli'
Install-ChocoPackage -PackageName 'azcopy'
Install-ChocoPackage -PackageName 'docker-engine'
Install-ChocoPackage -PackageName 'dotnet'
Install-ChocoPackage -PackageName 'dotnet-sdk'
#Install-ChocoPackage -PackageName ''

Write-ToLog 'Installing NuGet Credential Provider'
#https://github.com/microsoft/artifacts-credprovider#automatic-powershell-script
iex "& { $(irm https://aka.ms/install-artifacts-credprovider.ps1) }"

if (!(Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Ignore)) {
    Write-ToLog 'Installing NuGet Package Provider'
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force -WarningAction Ignore | Out-Null
}
if (-not(Get-PSRepository -Name PSGallery | ? { $_.InstallationPolicy -eq 'Trusted' })) {
    write-ToLog 'Set PSGallery as Trusted'
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}
$ModuleNames = @('bccontainerhelper','D365BcAppHelper','PnP.PowerShell','Microsoft.PowerShell.Archive','JiraPS','Az.Storage') 
foreach($ModuleName in $ModuleNames){
    if (-not(Get-InstalledModule -Name $ModuleName -ErrorAction Ignore)) {
        Write-ToLog "Install $ModuleName"
        Install-Module $ModuleName
    }
}

Write-ToLog 'Preload Artifacts'
Get-BCArtifactUrl -type OnPrem -country w1 | %{Download-Artifacts -artifactUrl $_ -includePlatform}
Get-BCArtifactUrl -type OnPrem -country de | %{Download-Artifacts -artifactUrl $_ -includePlatform}
Get-BCArtifactUrl -type Sandbox -country base -select Weekly | %{Download-Artifacts -artifactUrl $_ -includePlatform}
Get-BCArtifactUrl -type Sandbox -country de -select Weekly | %{Download-Artifacts -artifactUrl $_ -includePlatform}

Write-ToLog 'Pull Generic Image'
$BestGenericImage = Get-BestGenericImageName
docker pull $BestGenericImage

Write-ToLog 'Install AzureSignTool'
dotnet tool install --global AzureSignTool --version 3.0.0
$ASTDir ="c:\AzureSignTool"
mkdir $ASTDir  -ErrorAction SilentlyContinue
cd $ASTDir
copy-item -Path "$env:USERPROFILE\.dotnet\tools\*" -Destination $ASTDir -Recurse

Write-ToLog 'Register NavSip'
if(-not (Test-Path C:\Windows\System32\navsip.dll)){
    $LocalArtifacts= Get-BCArtifactUrl -country base -select Weekly -type Sandbox | %{Download-Artifacts -artifactUrl $_ -includePlatform}
    $TargetFile = "C:\Windows\System32\NavSip.dll"
    $LocalArtifacts[1] | gci -Filter $(split-path $TargetFile -Leaf) -Recurse| select -First 1 | Copy-Item -Destination $(split-path $TargetFile -Parent)
    RegSvr32 /s $TargetFile
}

$ScriptBlock = {
    Start-Transcript -Path 'c:\install\pstranscript.txt' -Append
    . 'C:\install\HelperFunctions.ps1'
    Write-ToLog 'Flush ContainerHelperCache'
    Flush-ContainerHelperCache -cache bcartifacts -keepDays 8
    Write-ToLog 'Pull Generic Image'
    $BestGenericImage = Get-BestGenericImageName
    docker pull $BestGenericImage
    
    Write-ToLog 'Prune Docker Images'
    docker image prune -f
    Stop-Transcript
}
$ScriptBlock | Out-File 'C:\install\reboot.ps1'

if (-not(Get-ScheduledTask -TaskName PoShScriptRunner -ErrorAction Ignore)) {
    Write-ToLog 'Schedule Task'
    $TaskTrigger = (New-ScheduledTaskTrigger -atstartup)
    $TaskAction = New-ScheduledTaskAction -Execute Powershell.exe -argument '-ExecutionPolicy Bypass -File C:\install\reboot.ps1'
    $TaskUserID = New-ScheduledTaskPrincipal -UserId System -RunLevel Highest -LogonType ServiceAccount
    $null = Register-ScheduledTask -Force -TaskName PoShScriptRunner -Action $TaskAction -Principal $TaskUserID -Trigger $TaskTrigger
}

Write-ToLog 'Restart Computer'

#Restart-Computer -Force
#Shutdown -r -t 60

Stop-Transcript
