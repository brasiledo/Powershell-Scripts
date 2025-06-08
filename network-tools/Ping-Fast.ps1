# Takes input from clipboard and pings all IPs/Hostnames and outputs IPv4 address, hostname, online (True/False).  Results outputs to console

##### Ping-Fast ########

function ping-fast {
param
(
$TimeoutMillisec = 1000,
$computername = (Get-Clipboard)
)
# hash table with error code to text translation
$StatusCode_ReturnValue = 
@{
0='Success'
11001='Buffer Too Small'
11002='Destination Net Unreachable'
11003='Destination Host Unreachable'
11004='Destination Protocol Unreachable'
11005='Destination Port Unreachable'
11006='No Resources'
11007='Bad Option'
11008='Hardware Error'
11009='Packet Too Big'
11010='Request Timed Out'
11011='Bad Request'
11012='Bad Route'
11013='TimeToLive Expired Transit'
11014='TimeToLive Expired Reassembly'
11015='Parameter Problem'
11016='Source Quench'
11017='Option Too Big'
11018='Bad Destination'
11032='Negotiating IPSEC'
11050='General Failure'
}
# hash table with calculated property that translates
# numeric return value into friendly text

$statusFriendlyText = @{
# name of column
Name = '  Status  '
# code to calculate content of column
Expression = { 
# take status code and use it as index into the hash table with friendly names
# make sure the key is of same data type (int)
$StatusCode_ReturnValue[([int]$_.StatusCode)]
};align="center"
}

# calculated property that returns $true when status -eq 0
$IsOnline = @{
Name = 'Online'
Expression = { $_.StatusCode -eq 0 };align="center"
}

$IPv4= @{
Name = 'IPv4 Address'
Expression = {
if ($_.StatusCode -eq 0 -and $_.Address -notlike '*.*.*.*')
{ $_.IPV4ADDRESS }
else{"     --    "}
}
}
$Address = @{
Name = 'Host Address'
Expression = { $_.address };align="left"
} 

$DNSName = @{
Name = ' DNSName '
Expression = { 
if ($_.StatusCode -eq 0 -and $_.Address -like '*.*.*.*')
{ [Net.DNS]::GetHostByAddress($_.Address).HostName }
else{"   --    "}
}
}
# convert list of computers into a WMI query string
$query = $ComputerName -join "' or Address='"

$ErrorActionPreference="silentlycontinue"

Get-CimInstance -ClassName Win32_PingStatus -Filter "(Address='$Query') and timeout=$TimeoutMillisec" | Sort-Object -Descending statuscode | FT -Property $Address, $statusFriendlyText, $IPv4, $DNSName  -ErrorAction Silentlycontinue

}
