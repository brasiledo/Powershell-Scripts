<#
.SYNOPSIS
Blaster Robocopy Job Launcher - Parallel version using Start-ThreadJob (PS 7+)

.DESCRIPTION
Reads a tab-delimited file and launches Robocopy jobs in parallel using ThreadJobs.
Displays real-time Write-Progress and console output. Optimized for controlled concurrency.

.NOTES
Author: Dan Lourenco
Version: 1.8.1
Date: 06.07.2025
Requires: PowerShell 7+ or ThreadJob module
#>

param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$File,

    [string]$LocalPath,

    [string[]]$DomainsToRemove = @('.wtb.bank.corp', '.exampledomain.com'),

    [int]$TimeoutMinutes = 20
)

$maxJobs = 5
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
===============================
 Blaster Copy Job Launcher
===============================
Input file format (tab-delimited):
SourcePath<TAB>DestinationPath<TAB>OptionalSwitches

Example:
\\server01\share1\folder   D:\Backup\folder   /MIR

Logs will be stored in: $mylogs
Max parallel jobs: $maxJobs
Max threads per Robocopy: $maxThreads
Timeout (minutes): $TimeoutMinutes
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
        [int]$maxThreads,
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
$jobs = @()

foreach ($line in $fileData) {
    $index++
    Write-Progress -Activity "Launching Robocopy Jobs" `
                   -Status "Launching job $index of $total" `
                   -PercentComplete (($index / $total) * 100)

    $content = @($line -split "`t")
    if ($content.Count -lt 2) {
        $errorMessages.Add("Malformed line: $line")
        continue
    }

    $source = $content[0].Trim()
    $destination = $content[1].Trim()
    $extraOptions = if ($content.Count -ge 3) { @($content[2]) } else { @() }

    foreach ($domain in $DomainsToRemove) {
        $source = $source -replace [regex]::Escape($domain), ''
        $destination = $destination -replace [regex]::Escape($domain), ''
    }

    $logFileName = ($destination -replace '[\\/:*?"<>|]', '_') + ".log"
    if ($LocalPath) {
        $source = $source -replace [regex]::Escape($LocalPath), ''
    }

    while (($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $maxJobs) {
        Start-Sleep -Seconds 5
    }

    $job = Start-ThreadJob -ScriptBlock {
        param (
            $scriptDirectory, $mylogs, $source, $destination, $extraOptions, $logFileName, $jobNumber, $totalJobs, $maxThreads
        )
        Import-Module ThreadJob -Force -ErrorAction SilentlyContinue
        Blaster-Copy -scriptDirectory $scriptDirectory -mylogs $mylogs `
            -source $source -destination $destination -extraOptions $extraOptions `
            -logFileName $logFileName -jobNumber $jobNumber -totalJobs $totalJobs -maxThreads $maxThreads
    } -ArgumentList $scriptDirectory, $mylogs, $source, $destination, $extraOptions, $logFileName, $index, $total, $maxThreads

    $jobs += $job
}

# Wait for jobs to finish
$startTime = Get-Date
while ($true) {
    $running = $jobs | Where-Object { $_.State -eq 'Running' }
    $completed = $jobs | Where-Object { $_.State -eq 'Completed' }

    Write-Progress -Activity "Waiting for jobs to complete" `
                   -Status "$($completed.Count) of $total completed" `
                   -PercentComplete (($completed.Count / $total) * 100)

    if ($running.Count -eq 0) { break }

   if (((Get-Date) - $startTime).TotalMinutes -gt $TimeoutMinutes) {
        Write-Host "`nTimeout reached. Stopping stuck jobs..." -ForegroundColor Red
        $running | Stop-ThreadJob -Force
        break
    }
    
    Start-Sleep -Seconds 5
}

Write-Progress -Activity "Waiting for jobs to complete" -Completed 

if ($errorMessages.Count -gt 0) {
    Write-Host "`nErrors encountered:" -ForegroundColor Red
    $errorMessages | ForEach-Object { Write-Host $_ -ForegroundColor Red }
}

Write-Host "`nAll jobs complete." -ForegroundColor Cyan
