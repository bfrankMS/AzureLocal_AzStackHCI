# https://docs.microsoft.com/en-us/azure/virtual-desktop/shortpath
# https://learn.microsoft.com/en-us/azure/virtual-desktop/administrative-template?tabs=group-policy-domain
# you then need to do add the GPO to your AD see:
# https://docs.microsoft.com/en-us/azure/virtual-desktop/shortpath#configure-rdp-shortpath-for-managed-networks


#region Download RDP Shortpath GPO Profile 
$OUSuffix = "OU=AVDHosts,OU=HCI"  #the part after the "...,DC=powerkurs,DC=local" so e.g. "OU=HostPool1,OU=AVD"
$tmpDir = "c:\temp"
Write-Output "downloading avdgpo"
    
$tempPath = "$tmpDir\avdgpo"
if (!(Test-Path $tempPath)) {
    "downloading avdgpo"
    Invoke-WebRequest -Uri "https://aka.ms/avdgpo" -OutFile "$tmpDir\avdgpo.cab" -Verbose
    expand "$tmpDir\avdgpo.cab" "$tmpDir\avdgpo.zip"
    Expand-Archive "$tmpDir\avdgpo.zip" -DestinationPath $tempPath -Force -Verbose
}
#endregion
    
#region Copy the terminalserver-avd profile files to the right subfolder.

$fqdn = (Get-WmiObject Win32_ComputerSystem).Domain
$policyDestination = "Microsoft.PowerShell.Core\FileSystem::\\$fqdn\SYSVOL\$fqdn\policies\PolicyDefinitions\"
    
mkdir $policyDestination -Force
mkdir "$policyDestination\en-us" -Force
Copy-Item "Microsoft.PowerShell.Core\FileSystem::$tempPath\*" -Filter "*.admx" -Destination "Microsoft.PowerShell.Core\FileSystem::\\$fqdn\SYSVOL\$fqdn\policies\PolicyDefinitions" -Force -Verbose
Copy-Item "Microsoft.PowerShell.Core\FileSystem::$tempPath\en-us\terminalserver-avd.adml" -Filter "*.adml" -Destination "Microsoft.PowerShell.Core\FileSystem::\\$fqdn\SYSVOL\$fqdn\policies\PolicyDefinitions\en-us" -Force -Verbose
#endregion

#region Create & Modify GPO 
$gpoNamePrefix = "AVD RDP Shortpath GPO"
$gpoName = $gpoNamePrefix + " - {0}" -f [datetime]::Now.ToString('dd-MM-yy_HHmmss') 
New-GPO -Name $gpoName 

$RDPShortPathRegKeys = @{
    fUseUdpPortRedirector = 
    @{
        Type  = "DWord"
        Value = 1           #set to 1 to enable.
    }
    UdpRedirectorPort =
    @{
        Type  = "DWord"
        Value = 3390           #set to 1 to enable.
    }
}

foreach ($item in $RDPShortPathRegKeys.GetEnumerator()) {
    "{0}:{1}:{2}" -f $item.Name, $item.Value.Type, $item.Value.Value
    Set-GPRegistryValue -Name $gpoName -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ValueName $($item.Name) -Value $($item.Value.Value) -Type $($item.Value.Type)
}

$FWallRuleRegKeys = @{
    'RemoteDesktop-Shortpath-UDP-In' = 
    @{
        Type  = 'String'
        Value = 'v2.31|Action=Allow|Active=TRUE|Dir=In|Protocol=17|LPort=3390|App=%SystemRoot%\system32\svchost.exe|Name=Remote Desktop - Shortpath (UDP-In)|EmbedCtxt=@FirewallAPI.dll,-28752|'
    }
}
foreach ($item in $FWallRuleRegKeys.GetEnumerator()) {
    "{0}:{1}:{2}" -f $item.Name, $item.Value.Type, $item.Value.Value
    Set-GPRegistryValue -Name $gpoName -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\WindowsFirewall\FirewallRules" -ValueName $($item.Name) -Value $($item.Value.Value) -Type $($item.Value.Type)
}
#endregion

#region Link GPO to correct OU (and delete orphaned GPOs)
Import-Module ActiveDirectory
$DomainPath = $((Get-ADDomain).DistinguishedName) # e.g."DC=contoso,DC=azure"
    
$OUPath = $($($OUSuffix + "," + $DomainPath).Split(',').trim() | Where-Object { $_ -ne "" }) -join ','
Write-Output "creating avdgpo GPO to OU: $OUPath"


$existingGPOs = (Get-GPInheritance -Target $OUPath).GpoLinks | Where-Object DisplayName -Like "$gpoNamePrefix*"
    
if ($null -ne $existingGPOs) {
    Write-Output "removing conflicting GPOs"
    $existingGPOs | Remove-GPLink -Verbose
}
    
New-GPLink -Name $gpoName -Target $OUPath -LinkEnabled Yes -verbose

#cleanup existing but unlinked fslogix GPOs
$existingGPOs | % { [xml]$Report = Get-GPO -guid $_.GpoId | Get-GPOReport -ReportType XML; if (!($Report.GPO.LinksTo)) { Remove-GPO -Guid $_.GpoId -Verbose } }

#endregion 

