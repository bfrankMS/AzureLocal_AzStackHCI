Set-Variable -Name 'ConfirmPreference' -Value 'None' -Scope Global
Write-Output "Installing PackageManagement"
Install-Package -Name PackageManagement -MinimumVersion 1.4.8 -Force -Confirm:$false -Source PSGallery
Write-Output "Installing PowershellGet"
Install-Package -Name PowershellGet -Force -Verbose

Register-PSRepository -Default -InstallationPolicy Trusted

#Install required PowerShell modules in your node for registration
Install-Module Az.Accounts -RequiredVersion 2.13.2 
Install-Module Az.Resources -RequiredVersion 6.12.0 
Install-Module Az.ConnectedMachine -RequiredVersion 0.5.2 

#Install Arc registration script from PSGallery 
Install-Module AzSHCI.ARCInstaller # -RequiredVersion 0.2.2616.70  ## only when using the nested deployment

$verbosePreference = "Continue"
$subscription = "a2ba.........7e6f"
$tenantID = "47f4........5aab0"
$rg = "rg-mynested"    # an existing an configured RG.
$region = "westeurope"  #or eastus???

Connect-AzAccount -TenantId $tenantID -Subscription $subscription -UseDeviceAuthentication
$armAccessToken = (Get-AzAccessToken).Token
$id = (Get-AzContext).Account.Id
Start-Sleep -Seconds 3
Invoke-AzStackHciArcInitialization -subscription $subscription -ResourceGroup $rg -TenantID $tenantID -Region $region -Cloud 'AzureCloud' -ArmAccessToken $armAccessToken -AccountID $id -Verbose -Proxy 'http://192.168.1.254:3128'
