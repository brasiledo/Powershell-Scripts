# Define input and output paths
$inputPath = Join-Path $PSScriptRoot 'ADUsers.txt'
$logFile   = Join-Path $PSScriptRoot 'UserOutput.csv'

# Check if input file exists
if (-not (Test-Path $inputPath)) {
    Write-Host "Input file not found: $inputPath" -ForegroundColor Red
    return
}

# Read user list and clean entries
$ADAccounts = Get-Content $inputPath | ForEach-Object { $_.Trim() } | Where-Object { $_ }

# Exit if list is empty
if (-not $ADAccounts) {
    Write-Host "No valid usernames found in file." -ForegroundColor Yellow
    return
}

# Delete old log file if it exists
if (Test-Path $logFile) {
    Remove-Item $logFile -Force
}

# Process each username
$Results = foreach ($username in $ADAccounts) {
    $user = Get-ADUser -Filter { SamAccountName -eq $username } `
                       -Properties Name, DisplayName, 'wfc-EmplStatus', SamAccountName, EmailAddress, HomeDirectory, Country, Enabled `
                       -ErrorAction SilentlyContinue

    if ($user) {
        [PSCustomObject]@{
            Username      = $user.SamAccountName
            Name          = $user.Name
            DisplayName   = $user.DisplayName
            HomeDirectory = $user.HomeDirectory
            'Email Address' = $user.EmailAddress
            Enabled       = $user.Enabled
            EmpStatus     = $user.'wfc-EmplStatus'
            Country       = $user.Country
        }
    } else {
        [PSCustomObject]@{
            Username      = $username
            Name          = "N/A"
            DisplayName   = "N/A"
            HomeDirectory = "N/A"
            'Email Address' = "N/A"
            Enabled       = "Doesn't Exist"
            EmpStatus     = "N/A"
            Country       = "N/A"
        }
    }
}

# Export and open log
$Results | Sort-Object -Property Enabled | Export-Csv $logFile -NoTypeInformation
Start-Process $logFile
