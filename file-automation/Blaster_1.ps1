<#
.SYNOPSIS
    Robocopy tool for CPS/EUC file migrations.

.DESCRIPTION
    Reads tab-delimited source/destination paths from an input file and runs Robocopy jobs.
    Supports concurrent jobs, multithreading, UNC substitution, and additional switches.

.PARAMETER File
    Input file path with tab-delimited source and destination paths (and optional robocopy options).

.PARAMETER LocalPath
    Optional: Replaces the UNC root with this local drive path for pre-stage testing.

.PARAMETER Add
    Optional: Additional robocopy switches (e.g., '/XD','Temp','Logs').

.PARAMETER Jobs
    Optional: Max number of concurrent jobs. Use 0 for unlimited. Default: 8.

.PARAMETER MT
    Optional: Multithreading count for robocopy (/MT). Default: 12.

.EXAMPLE
    .\Blaster_1.ps1 -File data.txt -Jobs 5 -MT 32 -Add '/XD','Temp' -LocalPath 'E:\'

.NOTES
    Author: Dan Lourenco
    Revised: 2024-06-02
#>

param (
    [Parameter(Mandatory)]
    [string]$File,

    [string]$LocalPath,
    [string[]]$Add,
    [int]$Jobs = 8,
    [int]$MT = 12
)

function Start-RobocopyJob {
    param (
        [string]$Source,
        [string]$Destination,
        [string[]]$BaseOptions,
        [string[]]$ExtraOptions,
        [int]$MT,
        [string]$LogFile
    )

    $args = @($BaseOptions + $ExtraOptions + "/MT:$MT", "/LOG:$LogFile")

    Start-Job -ScriptBlock {
        param ($src, $dst, $args)
        robocopy $src $dst @args
        return @{ Source = $src; Destination = $dst }
    } -ArgumentList $Source, $Destination, $args
}

# --- Initialize ---

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InputPath = Join-Path $ScriptDir $File
if (-not (Test-Path $InputPath)) {
    Write-Host "Input file not found: $InputPath" -ForegroundColor Red
    return
}

$LogTimestamp = Get-Date -Format "MMdd-HHmmss"
$RunLogDir = Join-Path $ScriptDir "Logs_$LogTimestamp"
$MainLog = Join-Path $ScriptDir "Blaster.RunLog.$LogTimestamp.log"
New-Item -ItemType Directory -Path $RunLogDir -Force | Out-Null

$BaseOptions = @('/MIR','/FFT','/COPY:DAT','/R:0','/NP','/XO','/XD','~snapshot','.snapshot','$Recycle.bin','/XF','*.onetoc2')
$ExtraOptions = if ($Add) { $Add } else { @() }

# --- Process Input File ---
$Lines = Get-Content $InputPath | Where-Object { $_ -match '\S' }

$ErrorLines = @()
$JobQueue = @()
$executionDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

Add-Content $MainLog "`n=== Robocopy Session Started: $executionDate ==="
Add-Content $MainLog "Concurrent Jobs Limit: $Jobs"
Add-Content $MainLog "Base Options: $($BaseOptions -join ' ')"
if ($ExtraOptions) { Add-Content $MainLog "Extra Options: $($ExtraOptions -join ' ')" }
Add-Content $MainLog "Multithreaded /MT:$MT"

foreach ($line in $Lines) {
    $parts = $line -split "`t"
    if ($parts.Count -lt 2) {
        $ErrorLines += $line
        continue
    }

    $source = $parts[0].Trim()
    $dest   = $parts[1].Trim()

    if ($LocalPath) {
        $source = $source -replace '^\\\\.*?\\', "$LocalPath\"
    }

    foreach ($domain in @('.ent.wfb.bank.corp', '.wellsfargo.com', '.wellsfargo.net')) {
        $source = $source -replace $domain, ''
        $dest   = $dest   -replace $domain, ''
    }

    if ([string]::IsNullOrWhiteSpace($source) -or [string]::IsNullOrWhiteSpace($dest)) {
        $ErrorLines += $line
        continue
    }

    $logFileName = $dest.Replace('\\','').Replace('\','.').Replace(':','') + ".log"
    $logPath = Join-Path $RunLogDir $logFileName

    $job = Start-RobocopyJob -Source $source -Destination $dest -BaseOptions $BaseOptions -ExtraOptions $ExtraOptions -MT $MT -LogFile $logPath
    $JobQueue += $job

    # If job limit is reached, wait
    if ($Jobs -gt 0) {
        while ((Get-Job -State 'Running').Count -ge $Jobs) {
            Start-Sleep -Milliseconds 500
        }
    }

    Add-Content $MainLog "Started Job: $source => $dest"
}

# Wait for all jobs to finish
Get-Job | Wait-Job
foreach ($job in Get-Job) {
    try {
        $result = Receive-Job $job
        Write-Host "Completed: $($result.Source) → $($result.Destination)"
        Add-Content $MainLog "Completed: $($result.Source) → $($result.Destination)"
    } catch {
        Write-Warning "Error receiving job ID $($job.Id): $_"
        Add-Content $MainLog "ERROR: Job ID $($job.Id) failed: $_"
    } finally {
        Remove-Job $job -Force
    }
}

if ($ErrorLines.Count -gt 0) {
    Add-Content $MainLog "`nInvalid Input Lines:"
    $ErrorLines | ForEach-Object { Add-Content $MainLog $_ }
    Write-Host "`nOne or more input lines were invalid. See log for details." -ForegroundColor Yellow
}

Add-Content $MainLog "`n=== Copy session complete ==="
Write-Host "`nRobocopy operations completed. Log: $MainLog"
