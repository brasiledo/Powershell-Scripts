<#
.SYNOPSIS
Blaster Robocopy Job Launcher (Synchronous Mode)

.DESCRIPTION
Automates a series of Robocopy jobs using a tab-delimited input file containing source and destination paths.
Runs jobs sequentially (one at a time) for real-time progress tracking and console output.

Displays:
- Live `Write-Progress` for job tracking
- Job status messages: "Copying", "Completed"
- Job number out of total
- Robocopy exit code for each operation

.PARAMETER File
Path to the tab-delimited input file. Each line must contain:
    Source<TAB>Destination<TAB>OptionalSwitches (optional)

.PARAMETER DomainsToRemove
Array of domain strings (e.g., `.wtb.bank.corp`) to strip from source and destination paths.

.EXAMPLE
Blaster_1_SyncOnly.ps1 -File ".\copyjobs.txt"

.EXAMPLE
Blaster_1_SyncOnly.ps1 -File ".\copyjobs.txt" -DomainsToRemove ".example.corp",".legacy.net"

.INPUT FILE FORMAT
Each line in the input file should look like this:
\\server1\share\folder<TAB>D:\Backups\folder<TAB>/MIR

.NOTES
Author: Dan Lourenco
Version: 1.7
Date: 9.29.23
#>


param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$File,

    [string[]]$DomainsToRemove = @('.wtb.bank.corp', '.exampledomain.com')

)

$maxThreads = 8

# === MAIN ===

$scriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Path
$executionDate = Get-Date -Format "MM-dd-yyyy_HHmm"
$mylogs = Join-Path -Path $scriptDirectory -ChildPath "logs_$executionDate"

if (!(Test-Path $mylogs)) {
    New-Item -ItemType Directory -Path $mylogs | Out-Null
}

cls
Write-Host @"
=============================
 Blaster Copy Job Launcher
=============================
Input file format (tab-delimited):
SourcePath<TAB>DestinationPath<TAB>OptionalSwitches

Example:
\\server01\share1\folder   D:\Backup\folder   /MIR

Logs will be stored in: $mylogs
Threads per Robocopy: $maxThreads

------------------------------------------------------

"@ -ForegroundColor Cyan

function Blaster-Copy {
    param (
        [string]$scriptDirectory,
        [string]$mylogs,
        [string]$source,
        [string]$destination,
        [string[]]$extraOptions,
        [string]$logFileName,
        [int]$jobNumber,
        [int]$totalJobs
    )

    if (!(Test-Path $source)) {
        Write-Host "`n[SKIPPED] Invalid source path: $source" -ForegroundColor Red
        return
    }

    Write-Host "`n[$jobNumber of $totalJobs] Copying:" -ForegroundColor Yellow
    Write-Host "From: $source"
    Write-Host "To:   $destination"

    $robocopyOptions = @("/E", "/FFT", "/R:1", "/W:1", "/Z", "/NFL", "/NDL", "/NP", "/TEE", "/LOG:$mylogs\$logFileName", "/MT:$maxThreads") +
        "/XD", "snapshot", ".snapshot", "$Recycle.Bin" +
        "/XF", "*.onetoc2"

    if ($extraOptions) {
        $robocopyOptions += $extraOptions
    }

    robocopy $source $destination $robocopyOptions
    $exitCode = $LASTEXITCODE
    Write-Host "Robocopy exit code: $exitCode"
    Write-Host "`n[$jobNumber of $totalJobs] Completed: $source => $destination" -ForegroundColor Green
}

$contentPath = Join-Path -Path $scriptDirectory -ChildPath $File
if (!(Test-Path $contentPath)) {
    Write-Host "Input file not found: $contentPath" -ForegroundColor Red
    return
}

$fileData = Get-Content $contentPath | Where-Object { $_ -match '\S' } | ForEach-Object { $_.TrimEnd() }
$total = $fileData.Count
$index = 0

$errorMessages = New-Object System.Collections.Generic.List[string]

foreach ($line in $fileData) {
    $index++

    Write-Progress -Activity "Processing Robocopy Jobs" `
                   -Status "Running job $index of $total" `
                   -PercentComplete (($index / $total) * 100)

    $content = @($line -split "`t")
    if ($content.Count -lt 2) {
        $errorMessages.Add("Malformed line: $line")
        continue
    }

    $source = $content[0]
    $destination = $content[1]
    $extraOptions = if ($content.Count -ge 3) { @($content[2]) } else { @() }

    foreach ($domain in $DomainsToRemove) {
        $source = $source -replace [regex]::Escape($domain), ''
        $destination = $destination -replace [regex]::Escape($domain), ''
    }

    $logFileName = ($destination -replace '[\\/:*?"<>|]', '_') + ".log"

    # Run synchronously
    Blaster-Copy -scriptDirectory $scriptDirectory `
                 -mylogs $mylogs `
                 -source $source `
                 -destination $destination `
                 -extraOptions $extraOptions `
                 -logFileName $logFileName `
                 -jobNumber $index `
                 -totalJobs $total
}

Write-Progress -Activity "Processing Robocopy Jobs" -Completed

if ($errorMessages.Count -gt 0) {
    Write-Host "`nErrors encountered:" -ForegroundColor Red
    $errorMessages | ForEach-Object { Write-Host $_ -ForegroundColor Red }
}

Write-Host "`nAll jobs complete." -ForegroundColor Cyan
