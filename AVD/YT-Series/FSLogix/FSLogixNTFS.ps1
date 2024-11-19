<#
.SYNOPSIS
    This script is used to set the NTFS permissions on the FSLogix profile share.
    pls adjust variables to match your environment.
    use at your own risk.
#>

$DomainName = "myavd"   #pls enter your domain name.
$AVDUsers = "AVDUsers"

#1st remove all exiting permissions.
$acl = Get-Acl "\\Sofs\Profile1" # "\\Sofs\Profile2"

$acl.Access | % { $acl.RemoveAccessRule($_) }
$acl.SetAccessRuleProtection($true, $false)
$acl | Set-Acl
#add full control for 'the usual suspects'
$users = @("$DomainName\Domain Admins", "System", "Administrators", "Creator Owner" )
foreach ($user in $users) {
    $new = $user, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
    $accessRule = new-object System.Security.AccessControl.FileSystemAccessRule $new
    $acl.AddAccessRule($accessRule)
    $acl | Set-Acl 
}

#add read & write on parent folder ->required for FSLogix - no inheritence
$allowAVD = "$AVDUsers", "ReadData, AppendData, ExecuteFile, ReadAttributes, Synchronize", "None", "None", "Allow"
$accessRule = new-object System.Security.AccessControl.FileSystemAccessRule $allowAVD
$acl.AddAccessRule($accessRule)
$acl | Set-Acl 