
#region RDP Shortpath FW rule in Desktop (part1)
# https://docs.microsoft.com/en-us/azure/virtual-desktop/shortpath
#New-NetFirewallRule -DisplayName 'Remote Desktop - Shortpath (UDP-In)'  -Action Allow -Description 'Inbound rule for the Remote Desktop service to allow RDP traffic. [UDP 3390]' -Group '@FirewallAPI.dll,-28752' -Name 'RemoteDesktop-UserMode-In-Shortpath-UDP'  -PolicyStore PersistentStore -Profile Domain, Private, Public -Service TermService -Protocol udp -LocalPort 3390 -Program '%SystemRoot%\system32\svchost.exe' -Enabled:True

# https://learn.microsoft.com/en-us/azure/virtual-desktop/administrative-template?tabs=group-policy-domain
# you then need to do add the GPO to your AD see:
# https://docs.microsoft.com/en-us/azure/virtual-desktop/shortpath#configure-rdp-shortpath-for-managed-networks

   
$OUSuffix = "OU=HCIMX,OU=AVD"  #the part after the "...,DC=powerkurs,DC=local" so e.g. "OU=HostPool1,OU=AVD"
$tmpDir = "c:\temp"
Write-Output "downloading avdgpo"
    
$tempPath = "$tmpDir\avdgpo"
if (!(Test-Path $destinationPath)) {
    "downloading avdgpo"
    Invoke-WebRequest -Uri "https://aka.ms/avdgpo" -OutFile "$tmpDir\avdgpo.cab" -Verbose
    expand "$tmpDir\avdgpo.cab" "$tmpDir\avdgpo.zip"
    Expand-Archive "$tmpDir\avdgpo.zip" -DestinationPath $tempPath -Force -Verbose
}
    

#terminalserver-avd.admx
#Then copy the terminalserver-avd.adml file to the en-us subfolder.

$fqdn = (Get-WmiObject Win32_ComputerSystem).Domain
$policyDestination = "Microsoft.PowerShell.Core\FileSystem::\\$fqdn\SYSVOL\$fqdn\policies\PolicyDefinitions\"
    
mkdir $policyDestination -Force
mkdir "$policyDestination\en-us" -Force
Copy-Item "Microsoft.PowerShell.Core\FileSystem::$tempPath\*" -Filter "*.admx" -Destination "Microsoft.PowerShell.Core\FileSystem::\\$fqdn\SYSVOL\$fqdn\policies\PolicyDefinitions" -Force -Verbose
Copy-Item "Microsoft.PowerShell.Core\FileSystem::$tempPath\en-us\terminalserver-avd.adml" -Filter "*.adml" -Destination "Microsoft.PowerShell.Core\FileSystem::\\$fqdn\SYSVOL\$fqdn\policies\PolicyDefinitions\en-us" -Force -Verbose
   
$gpoName = "avdRdpShortPathGpo{0}" -f [datetime]::Now.ToString('dd-MM-yy_HHmmss') 
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

Import-Module ActiveDirectory
$DomainPath = $((Get-ADDomain).DistinguishedName) # e.g."DC=contoso,DC=azure"
    
$OUPath = $($($OUSuffix + "," + $DomainPath).Split(',').trim() | Where-Object { $_ -ne "" }) -join ','
Write-Output "creating avdgpo GPO to OU: $OUPath"


$existingGPOs = (Get-GPInheritance -Target $OUPath).GpoLinks | Where-Object DisplayName -Like "avdRdpShortPathGpo*"
    
if ($null -ne $existingGPOs) {
    Write-Output "removing conflicting GPOs"
    $existingGPOs | Remove-GPLink -Verbose
}
    
    
New-GPLink -Name $gpoName -Target $OUPath -LinkEnabled Yes -verbose


#endregion 