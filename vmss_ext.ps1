Start-Transcript -Path "c:\install\pstranscript.txt" -Append
function Write-ToLog{
  param($message)
  Write-Host $message
  $logPath = "c:\install\log.txt"
  $null = mkdir (Split-Path $logPath) -ErrorAction SilentlyContinue
  $message | Out-File -FilePath $logPath -Append
}
Write-ToLog "Install Choco"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

Write-ToLog "Set AllowGlobalConfirmation"
choco feature enable -n allowGlobalConfirmation

Write-ToLog "Install Git"
choco install git.install

Write-ToLog "Install Git Cred Helper"
choco install git-credential-manager-for-windows

Write-ToLog "Install Notepad++"
choco install notepadplusplus

Write-ToLog "Install 7Zip"
choco install 7zip.install

Write-ToLog "Install Nuget"
choco install nuget.commandline

Write-ToLog "Install Azure CLI"
choco install azure-cli

Write-ToLog "Install AZCopy"
choco install azcopy

Write-ToLog "Install Docker"
Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
Install-Package -Name docker -ProviderName DockerMsftProvider

Write-ToLog "Install navcontainerhelper"
Install-Module navcontainerhelper

Write-ToLog "Pull Generic Image"
$BestGenericImage = Get-BestGenericImageName
docker pull $BestGenericImage

Stop-Transcript
