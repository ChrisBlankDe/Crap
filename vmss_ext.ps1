Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco feature enable -n allowGlobalConfirmation

choco install git.install
choco install git-credential-manager-for-windows
choco install notepadplusplus
choco install 7zip.install

choco install nuget.commandline

choco install docker-cli

choco install azure-cli
choco install azcopy
