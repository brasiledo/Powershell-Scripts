<# Tests for open ports on computer objects
.Syntax 
Test-Port -Host (Computername) -Port (Port Number)
#>

####### Test For Open Port ######
Function Test-Port {
Param(
    [Parameter(Mandatory)] 
    [int]$Port,
    [Parameter(Mandatory)] 
    [string[]]$Servers
)
Foreach ($Comp in $Servers){
    $porttest = test-netconnection $Comp -port $port
    if ($porttest.TcpTestSucceeded -eq $True){
        write-host "Port Open on $Comp`n" -fore cyan;
        
}else{$_.Exception.Message};write-host ''
 }
}
