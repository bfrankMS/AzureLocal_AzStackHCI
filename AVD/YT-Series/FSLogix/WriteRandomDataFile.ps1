<#

    Using Powershell to write Random Data to Storage => $numOfOutputFiles X $totalOutputFileSizeInBytes
    Notes:
    This script will write random data to a file to test storage performance.
    1 GB onto SSD with moderate CPU will take approx 40sec 
    e.g. 7Zip will give 0% compression ratio, i.e. output is as large as original file.

    alternative C:\ClusterStorage\UserStorage_1\rubbish> fsutil file createNew test5.txt $size
#>

$outputFileSizeInBytes = 100MB       
$numOfOutputFiles = 10
$outputPath = "$env:HOMEPATH\documents\random.data" #"c:\temp\random.data"

Write-Host -ForegroundColor Green "Writing $numOfOutputFiles * $($outputFileSizeInBytes/1MB) (MB) = $(($numOfOutputFiles*$outputFileSizeInBytes)/1GB) (GB)"


$starttime = Get-Date
"Starting at {0:dd-MM-yyyy HH:mm:ss}" -f $(Get-Date)

for ($i = 1; $i -le $numOfOutputFiles; $i++)
{ 
    #create an area of random data.
    $data = New-Object 'byte[]' $outputFileSizeInBytes
    $rnd =  [System.Random]::new()
    $rnd.NextBytes($data)
    
    #create Path if not exists
    $parentPath = Split-Path $outputPath -Parent
    if (!(Test-Path -Path $parentPath ))
    {
        mkdir $parentPath
    }
    
    #write out random data
    (split-path $outputPath -Leaf) -match "(.*)\.(.*)"   #append $i to filename e.g. "random.1.data"
    $path = (split-path $outputPath) + "\" + $Matches[1] + ".$i." + $Matches[2] 
    [System.IO.File]::WriteAllBytes($path,$data)
}

"Finished at {0:dd-MM-yyyy HH:mm:ss}" -f $(Get-Date)
"Elapsed time: {0:dd'dy:'hh'hr:'mm'min:'ss'sec'}" -f $((Get-Date) - $starttime)
