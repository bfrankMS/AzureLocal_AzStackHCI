# https://learn.microsoft.com/en-us/azure-stack/hci/manage/configure-proxy-settings-23h2
$proxyServer = "192.168.1.254:3128" #e.g. proxy.contoso.com:8080

$BypassList = "localhost,127.0.0.1,*.svc,01-HCI-1,01-HCI-2,hci01nested,192.168.1.2,192.168.1.3,*.HCI01.org,192.168.1.11"    # 192.168.1.* can use * for IP range of the HCI cluster.
# ip each node, netbios node & cluster, ARB IP
# IP address of each cluster member server.
# Netbios name of each server.
# Netbios cluster name.
# *.contoso.com.
# Second IP address of the infrastructure pool. (ARB IP) -> 192.168.1.11  (e.g. when specifying 192.168.1.10 - 192.168.1.30) -> .10 (= cluster), .11 (= ARB IP)

#region Proxy settings
    #WinInet
    Set-WinInetProxy -ProxySettingsPerUser 0 -ProxyServer $proxyServer -ProxyBypass $BypassList     #  use '*' for domains and whole subnets

    #Environment variables
    [Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://$proxyServer", "Machine")  #must be http! (no 's' !!!)
    $env:HTTPS_PROXY = [System.Environment]::GetEnvironmentVariable("HTTPS_PROXY", "Machine")

    [Environment]::SetEnvironmentVariable("HTTP_PROXY", "http://$proxyServer", "Machine")   
    $env:HTTP_PROXY = [System.Environment]::GetEnvironmentVariable("HTTP_PROXY", "Machine")

    $no_proxy_bypassList = "localhost,127.0.0.1,.svc,192.168.1.0/24,.HCI01.org,01-HCI-1,01-HCI-2,hci01nested"  # no * for domains and use CIDR for subnets
    [Environment]::SetEnvironmentVariable("NO_PROXY", $no_proxy_bypassList, "Machine")
    $env:NO_PROXY = [System.Environment]::GetEnvironmentVariable("NO_PROXY", "Machine")

    #WinHTTP
    netsh winhttp set proxy $proxyServer bypass-list=$BypassList        #  use '*' for domains and whole subnets
#endregion

#Test WebRequest
Invoke-WebRequest -Uri www.microsoft.com -UseBasicParsing

#Make sure you have a time server.
# Set Time Server in your geographical region
#w32tm /config /manualpeerlist:de.pool.ntp.org /syncfromflags:manual /reliable:yes /update
#w32tm /resync /force
#w32tm /query /status

#test if time server responds.
#w32tm /stripchart /computer:de.pool.ntp.org /samples:5 /dataonly

