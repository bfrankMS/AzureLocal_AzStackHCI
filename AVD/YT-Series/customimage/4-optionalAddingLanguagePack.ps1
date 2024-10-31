param(
    [Parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true,
               Position=0)]
    [string] $targetLanguage    # e.g. "de-DE"
)

$tmpDir = "c:\temp\" 

# Ref: Add languages to a Windows 11 Enterprise image
# https://learn.microsoft.com/en-us/azure/virtual-desktop/windows-11-language-packs

#create folder if it doesn't exist
if (!(Test-Path $tmpDir)) { mkdir $tmpDir -Force }
        
#write a log file with the same name of the script
Start-Transcript "$tmpDir\step_InstallLanguagePack.log" -Append
"================"
"Starting Language Pack ($targetLanguage) installation $(Get-Date)"

$ErrorActionPreference = "Continue"

#region Start Language Pack download
$ProgressPreference = 'SilentlyContinue'
$myjobs = @() 

#https://learn.microsoft.com/en-us/azure/virtual-desktop/windows-11-language-packs
$LPdownloads = @{
    'LanguagePack' = "https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26100.1.240331-1435.ge_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso" #24h2
    #"https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66749/22621.1.220506-1250.ni_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso"# Win11 22H2, 23H2
    'InboxApps'    = "https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26100.1742.240904-1906.ge_release_svc_prod1_amd64fre_InboxApps.iso"  #24h2
    #"https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/22621.2501.231009-1937.ni_release_svc_prod3_amd64fre_InboxApps.iso" # Win11 22H2 , 23H2
    'ODT'          = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_18129-20030.exe"
    #"https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17531-20046.exe" #Office Deployment Tool->  https://www.microsoft.com/en-us/download/details.aspx?id=49117
    
}

Write-Output "Starting download jobs $(Get-Date)"
foreach ($download in $LPdownloads.GetEnumerator()) {
    $downloadPath = $tmpDir + "\$(Split-Path $($download.Value) -Leaf)"
    if (!(Test-Path $downloadPath )) {
        #download if not there
        $myjobs += Start-Job -ArgumentList $($download.Value), $downloadPath -Name "download" -ScriptBlock {
            param([string] $downloadURI,
                [string]$downloadPath
            )
            #Invoke-WebRequest -Uri $download -OutFile $downloadPath # is 10 slower than the webclient
            $wc = New-Object net.webclient
            $wc.Downloadfile( $downloadURI, $downloadPath)
        } 
    }
}

do {
    Start-Sleep 15
    $running = @($myjobs | Where-Object { ($_.State -eq 'Running') })
    $myjobs | Group-Object State | Select-Object count, name
    Write-Output "-----------------"
}
while ($running.count -gt 0)

Write-Output "Finished downloads $(Get-Date)"
#endregion

#region Time Zone Redirection
$Name = "fEnableTimeZoneRedirection"
$value = "1"
# Add Registry value
try {
    New-ItemProperty -ErrorAction Stop -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name $name -Value $value -PropertyType DWORD -Force
    if ((Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services").PSObject.Properties.Name -contains $name) {
        Write-Output "Added time zone redirection registry key"
    }
    else {
        Write-Output "Error locating the Timezone registry key"
    }
}
catch {
    $ErrorMessage = $_.Exception.message
    Write-Output "Error adding Timezone registry KEY: $ErrorMessage"
}
#endregion

#see https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/languages-overview?view=windows-11#build-a-custom-fod-and-language-pack-repository

#region Language pack installation
Write-Output "Entering Language Pack installation $(Get-Date)"

#region isomounting helper function
function MountIso ($ISOPath) {
    $global:before = (Get-Volume | Where-Object Driveletter -NE $null ).DriveLetter
    Set-Variable -Name mountVolume -Scope Script -Value (Mount-DiskImage -ImagePath $ISOPath -StorageType ISO -PassThru)
    Start-Sleep -Seconds 1
    $global:after = (Get-Volume | Where-Object Driveletter -NE $null ).DriveLetter  
    Set-Variable -Name driveLetter -Scope Script -Value (Compare-Object  $global:before $global:after -PassThru)
    return @{
        'driveletter' = $driveLetter
        'mountvolume' = $mountVolume
    }
}
#endregion

########################################################
## Add Languages to running Windows Image for Capture##
########################################################
##Disable Language Pack Cleanup##
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup"
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\MUI\" -TaskName "LPRemove"
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\LanguageComponentsInstaller" -TaskName "Uninstallation"
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Control Panel\International" /v "BlockCleanupOfUnusedPreinstalledLangPacks" /t REG_DWORD /d 1 /f

##Set Language Pack Content Stores##
$LanguagePack = $tmpDir + '\' + $(Split-Path $LPdownloads['LanguagePack'] -Leaf)
#mount 
Write-Output "Mounting ISO Image: $LanguagePack"
$iso = MountIso $LanguagePack
$LanguagePackContent = "$($iso['driveletter'])" + ':\LanguagesAndOptionalFeatures\'


##List of additional features to be installed##
$additionalFODList = @(
    "$LanguagePackContent\Microsoft-Windows-NetFx3-OnDemand-Package~31bf3856ad364e35~amd64~~.cab",
    "$LanguagePackContent\Microsoft-Windows-InternetExplorer-Optional-Package~31bf3856ad364e35~amd64~$targetLanguage~.cab",
    "$LanguagePackContent\Microsoft-Windows-MSPaint-FoD-Package~31bf3856ad364e35~amd64~$targetLanguage~.cab",
    "$LanguagePackContent\Microsoft-Windows-Notepad-FoD-Package~31bf3856ad364e35~amd64~$targetLanguage~.cab",
    "$LanguagePackContent\Microsoft-Windows-Notepad-System-FoD-Package~31bf3856ad364e35~amd64~$targetLanguage~.cab",
    "$LanguagePackContent\Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~amd64~$targetLanguage~.cab",
    "$LanguagePackContent\Microsoft-Windows-Printing-PMCPPC-FoD-Package~31bf3856ad364e35~amd64~$targetLanguage~.cab",
    "$LanguagePackContent\Microsoft-Windows-Printing-WFS-FoD-Package~31bf3856ad364e35~amd64~$targetLanguage~.cab",
    "$LanguagePackContent\Microsoft-Windows-SnippingTool-FoD-Package~31bf3856ad364e35~amd64~$targetLanguage~.cab",
    "$LanguagePackContent\Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~amd64~$targetLanguage~.cab",
    "$LanguagePackContent\Microsoft-Windows-MediaPlayer-Package~31bf3856ad364e35~wow64~$targetLanguage~.cab"
    #"$LanguagePackContent\Microsoft-Windows-WordPad-FoD-Package~31bf3856ad364e35~amd64~$targetLanguage~.cab" #no longer in 24h2
)

$additionalCapabilityList = @(
    "Language.Basic~~~$targetLanguage~0.0.1.0",
    "Language.Handwriting~~~$targetLanguage~0.0.1.0",
    "Language.OCR~~~$targetLanguage~0.0.1.0",
    "Language.Speech~~~$targetLanguage~0.0.1.0",
    "Language.TextToSpeech~~~$targetLanguage~0.0.1.0"
)

##Install all FODs or fonts from the CSV file###
$LP = "$LanguagePackContent\Microsoft-Windows-Client-Language-Pack_x64_$targetLanguage.cab"
"adding...$LP"
Dism /Online /Add-Package /PackagePath:$LP

foreach ($capability in $additionalCapabilityList) {
    "adding...$capability"
    Dism /Online /Add-Capability /CapabilityName:$capability /Source:$LanguagePackContent
}

foreach ($feature in $additionalFODList) {
    "adding...$feature"
    Dism /Online /Add-Package /PackagePath:$feature
}

Write-Output "Dismounting ISO Image."
Dismount-DiskImage -InputObject $iso['mountvolume']

##Add installed language to language list##
$LanguageList = Get-WinUserLanguageList
$LanguageList.Add($targetLanguage)
Set-WinUserLanguageList $LanguageList -Force
Set-SystemPreferredUILanguage -Language $targetLanguage

Write-Output "Finished Language Pack installation $(Get-Date)"
#endregion

#region Update Inbox Apps for Multi Language
$InboxApps = $tmpDir + '\' + $(Split-Path $LPdownloads['InboxApps'] -Leaf)
#mount 
Write-Output "Mounting ISO Image: $InboxApps"
$iso = MountIso $InboxApps
[string] $AppsContent = "$($iso['driveletter'])`:\packages\" 
##Update installed Inbox Store Apps##
foreach ($App in (Get-AppxProvisionedPackage -Online)) {
    $AppPath = $AppsContent + $App.DisplayName + '_' + $App.PublisherId
    Write-Host "Handling: $($App.DisplayName) --> $AppPath"
    $licFile = Get-Item $AppPath*.xml
    if ($licFile.Count) {
        $lic = $true
        $licFilePath = $licFile.FullName
    }
    else {
        $lic = $false
    }
    $appxFile = Get-Item $AppPath*.appx*
    if ($appxFile.Count) {
        $appxFilePath = $appxFile.FullName
        if ($lic) {
            Add-AppxProvisionedPackage -Online -PackagePath $appxFilePath -LicensePath $licFilePath -Verbose 
        }
        else {
            Add-AppxProvisionedPackage -Online -PackagePath $appxFilePath -SkipLicense -Verbose
        }
    }
}
Write-Output "Dismounting ISO Image."
Dismount-DiskImage -InputObject $iso['mountvolume']
#endregion

#region Office Language Pack installation
#https://www.microsoft.com/en-us/download/details.aspx?id=49117
#downloaded Office Deployment Tool -> created a config file (https://config.office.com/) to add $targetLanguage as language -> execute OCT tool to download & install LP
Write-Output "Installing Office Language Pack $(Get-Date)"

$ODTConfig = @"
<Configuration ID="6ed8046a-e8ac-46ce-8d33-824b0bfc1e54">
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="de-de" />
      <ExcludeApp ID="Groove" />
    </Product>
    <Product ID="LanguagePack">
      <Language ID="de-de" />
    </Product>
    <Product ID="ProofingTools">
      <Language ID="de-de" />
    </Product>
  </Add>
  <Property Name="SharedComputerLicensing" Value="0" />
  <Property Name="SCLCacheOverride" Value="0" />
  <Property Name="AUTOACTIVATE" Value="0" />
  <Property Name="FORCEAPPSHUTDOWN" Value="FALSE" />
  <Property Name="DeviceBasedLicensing" Value="0" />
  <Updates Enabled="TRUE" />
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
"@

$ODTConfig

Out-File -FilePath "$tmpDir\ODTConfig.xml" -InputObject $ODTConfig

Start-Process -filepath "$tmpDir\officedeploymenttool*.exe" -ArgumentList "/extract:$tmpDir\ODT /quiet" -wait
start-sleep 3

try {
    Write-Output "Executing Office Deployment Tool...this will take a while... $(Get-Date)"
    Start-Process -FilePath "$tmpDir\ODT\setup.exe" -Wait -ErrorAction Stop -ArgumentList "/configure $tmpDir\ODTConfig.xml" -NoNewWindow
}
catch {
    $ErrorMessage = $_.Exception.message
    Write-Output "Error installing Office Language Pack $ErrorMessage"
}
Write-Output "End Office Language Pack $(Get-Date)"
#endregion
