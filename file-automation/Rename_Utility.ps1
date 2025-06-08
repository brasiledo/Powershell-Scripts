<#
Parameters you can change when executing the script:

Example:
.\Rename_Path_Remo.ps1 -ScriptRoot 'C:\path' -LogFileName 'Output.log' -ErrorLogFileName 'ErrorOutput.log' -SourceFile 'InputFileName.txt' -Prefix ZZ -Verbose

.PARAMETERS

ScriptRoot           The root directory where logs and input files are located. Defaults to the script's current directory.
LogFileName          The name of the log file for successful rename operations. Default: Rename_Success.log
ErrorLogFileName     The name of the log file for failed or error rename operations. Default: Rename_Errors.log
SourceFile           The name of the input file containing a list of paths to rename. Default: NasPaths.txt
Prefix               The prefix to add to each renamed item. Automatically appends a period (e.g., -Prefix ZZ → ZZ.share). Default: DM
Verbose              If specified, displays additional output to the screen during execution.
#>

# Set Initial Params
Param (
    [string]$ScriptRoot = (Split-Path -parent $MyInvocation.MyCommand.Definition),
    [string]$LogFileName = "Rename_Success.log",
    [string]$ErrorLogFileName = "Rename_Errors.log",
    [string]$SourceFile = 'NasPaths.txt',
    [string]$Prefix = 'DM',
    [switch]$Verbose
)

$ErrorLogPath = Join-Path $ScriptRoot $ErrorLogFileName
$LogPath = Join-Path $ScriptRoot $LogFileName

if ($Verbose) {
    Write-Host "Logging to: $LogPath" -ForegroundColor Cyan
    Write-Host "Error log: $ErrorLogPath" -ForegroundColor Cyan
}

$successCount = 0
$failCount = 0

# Logging function to record all events and errors with timestamps
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO","WARNING","ERROR")]
        [string]$LogLevel = "INFO"
    )
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logMessage = "$timestamp [$LogLevel] - $Message"
    if ($LogLevel -eq "ERROR") {
        Add-Content -Path $ErrorLogPath -Value $logMessage
    } else {
        Add-Content -Path $LogPath -Value $logMessage
    }
}

# Main
Write-Log "Script started."
$InputFile = Join-Path $ScriptRoot $SourceFile
if (!(Test-Path $InputFile)) {
    Write-Error "$InputFile Doesn't Exist"
    Write-Log "Input file '$InputFile' does not exist." -LogLevel "ERROR"
    return
}

$share_paths = Get-Content $InputFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

foreach ($path in $share_paths) {
    if (!(Test-Path $path)) {
        Write-Log "Path does not exist: $path" -LogLevel "ERROR"
        $failCount++
        continue
    }

    $leaf = Split-Path $path -leaf
    $newname = "$Prefix.$leaf"

    try {
        Rename-Item -Path $path -NewName $newname -ErrorAction Stop
        Write-Log "Successfully renamed '$path' to '$newname'"
        if ($Verbose) {
            Write-Host "`n$path renamed to $newname`n" -ForegroundColor Green
        }
        $successCount++
    } catch {
        if ($_.Exception.Message -like "*Access*") {
            Write-Log "Access Denied for path: $path" -LogLevel "ERROR"
        } else {
            Write-Log "Failed to rename '$path': $($_.Exception.Message)" -LogLevel "ERROR"
        }
        $failCount++
    }
}

Write-Log "Script completed."
Write-Log "Summary: Renamed: $successCount items, Failed: $failCount items"

if ($Verbose) {
    Write-Host "`nScript completed. Success: $successCount, Failed: $failCount`n" -ForegroundColor Yellow
}
