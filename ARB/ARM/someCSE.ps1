param(
    [Parameter(Mandatory=$True,Position=1)]
    [string] $param1,

    [Parameter(Mandatory=$True,Position=2)]
    [string] $param2
)

$tmpDir = "c:\temp\" 

#create folder if it doesn't exist
if (!(Test-Path $tmpDir)) { mkdir $tmpDir -force}

Start-Transcript "$tmpDir\CSE.log"

"I was run at {0} called with param1: {1} and param2: {2}" -f (get-date), $param1, $param2

stop-Transcript