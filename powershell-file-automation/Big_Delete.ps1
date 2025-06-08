<#
.SYNOPSIS
    Deletes files listed in an input text file and logs results.

.DESCRIPTION
    Reads a list of file paths, deletes each, and logs both successful deletions and failures.
    Supports handling long paths by mapping temporary drive letters when needed.

.PARAMETER inputFile
    Path to text file containing file paths to delete (one per line).
    If no full path is provided, assumes the file is in the script directory.

.PARAMETER logPath
    Optional. Path where the log file will be saved. Defaults to script directory.

.PARAMETER characterCount
    Optional. Length threshold to trigger long path mapping. Default is 250 characters.

.EXAMPLE
    Delete-Files -inputFile "FileList.txt"

.EXAMPLE
    Delete-Files -inputFile "C:\data\to_delete.txt" -logPath "C:\logs" -characterCount 200

.NOTES
    Author: Dan Lourenco
    Updated: 2024-06-02
#>

function Delete-Files {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$inputFile,

        [string]$logPath,

        [int]$characterCount = 250
    )

    $scriptRoot = $PSScriptRoot
    $logFile = "Big-Delete.$(Get-Date -Format 'yyyyMMdd_HHmm').log"

    # Default log location if not supplied
    $logFilePath = if ($logPath) {
        if (-not (Test-Path $logPath)) {
            Write-Error "Log path does not exist: $logPath"
            return
        }
        Join-Path $logPath $logFile
    } else {
        Join-Path $scriptRoot $logFile
    }

    # Resolve relative input path if needed
    if (-not (Split-Path $inputFile -Parent)) {
        $inputFile = Join-Path $scriptRoot $inputFile
    }

    if (-not (Test-Path $inputFile)) {
        Write-Error "Input file not found: $inputFile"
        return
    }

    # Logging helper
    function Log-Message {
        param ([string]$message)
        Add-Content -Path $logFilePath -Value $message
    }

    # Header
    $startTime = Get-Date
    Log-Message "==================================="
    Log-Message "Start Time - $startTime"
    Log-Message "===================================`n"

    $deletedFiles = New-Object System.Collections.Generic.List[string]
    $errorEntries = New-Object System.Collections.Generic.List[string]

    $allFiles = Get-Content $inputFile | ForEach-Object { $_.Trim() } | Where-Object { $_ }

    $usedDrive = $null

    foreach ($file in $allFiles) {
        $originalPath = $file
        $mapped = $false

        if ($file.Length -ge $characterCount) {
            $available = ([char[]](69..90)) | Where-Object { -not (Get-PSDrive -Name $_ -ErrorAction SilentlyContinue) } | Select-Object -First 1

            if (-not $available) {
                Log-Message "No available drive letter to map long path: $file"
                continue
            }

            $driveLetter = "$available:"
            $parent = Split-Path $file -Parent
            $leaf = Split-Path $file -Leaf

            net use $driveLetter $parent 1>$null 2>$null
            $file = Join-Path $driveLetter $leaf
            $mapped = $true
            $usedDrive = $driveLetter
        }

        try {
            Remove-Item -Path $file -Force -ErrorAction Stop
            if ($mapped) {
                $deletedFiles.Add("Deleted (mapped) - $originalPath")
            } else {
                $deletedFiles.Add("Deleted - $file")
            }
        } catch {
            $errorEntries.Add("Error deleting $originalPath :: $($_.Exception.Message)")
        }
    }

    if ($usedDrive) {
        net use $usedDrive /delete /y 1>$null 2>$null
    }

    if ($deletedFiles.Count -gt 0) {
        Log-Message "`n---------------------------"
        Log-Message "Successfully Deleted Files:"
        Log-Message "---------------------------"
        $deletedFiles | ForEach-Object { Log-Message $_ }
    }

    if ($errorEntries.Count -gt 0) {
        Log-Message "`n-----------------------"
        Log-Message "Failed to Delete Files:"
        Log-Message "-----------------------"
        $errorEntries | ForEach-Object { Log-Message $_ }
    }

    $endTime = Get-Date
    Log-Message "`n==================================="
    Log-Message "End Time - $endTime"
    Log-Message "==================================="
}
