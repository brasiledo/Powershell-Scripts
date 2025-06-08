<#

.SYNOPSIS
Script Version Check Module - compares current script version to master version and optionally updates it.


.DESCRIPTION
This function searches for version string (e.g. '$Version' = "1.2.3") inside the master copy of the script.
It compares that to the current script's version, and if outdated, it can auto-copy the newer version either interactively or silently.

.PARAMETER scriptPath
Path to the master repo where the source script resides

.PARAMETER package
Name of the script file to check

.PARAMETER currentVersion
The name of the variable in the current script that holds the version value. Defaults to 'Version'. You can override it by specifying a different variable name (e.g., -currentVersion 'Build').

.PARAMETER ReferenceVersion
The name of the version variable used in the remote master script. Defaults to 'Version', but can be overridden if the remote script uses a different variable name.

.PARAMETER UpdateIfOutdated
Switch to auto-copy the master script if the local version is outdated without interactive prompt

.PARAMETER log
Optional log switch to include an exported log file with results of each update

.PARAMETER LogPath
If you choose to log the output, and want to specify the log path use this parameter.
Otherwise, this will auto select LocalAppData to store the logs.


.EXAMPLE
Add into your script:

# Import the module:
    Import-Module "Path\VersionCheck.psm1"

Then, after declaring your $version variable:

# Basic use
$status = Compare-Version -scriptPath "\\server\scripts" -package "myscript.ps1"

# Silent auto-update
$status = Compare-Version -scriptPath "\\server\scripts" -package "myscript.ps1" -UpdateIfOutdated

# Logging to default local path
$status = Compare-Version -scriptPath "\\server\scripts" -package "myscript.ps1" -Log

# Logging to custom path
$status = Compare-Version -scriptPath "\\server\scripts" -package "myscript.ps1" -Log -LogPath "C:\Temp"


.OUTPUTS
[String] - One of: "Current", "Update Needed", "Ahead"

.NOTES
Author: Daniel Lourenco
Date: 5/16/25

#>
function Write-VersionLog {
    param (
        [string]$Package,
        [string]$LocalVersion,
        [string]$MasterVersion,
        [string]$Status,
        [string]$LogPath
    )

    $currentDate = Get-Date -Format "yyyy-MM-dd"
    $timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logDir      = Join-Path $LogPath "ScriptToolKit_Logs"

    if (!(Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    $logFile = Join-Path $logDir "VersionCheck_$currentDate.log"
    Add-Content -Path $logFile -Value "[$timestamp] `"$Package`" version check: Local: $LocalVersion, Master: $MasterVersion, Status: $Status"
    Add-Content -Path $logFile -Value ""
    return $logFile
} #End Function

function Compare-Version {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$scriptPath,                 # Path to MASTER repo

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$package,                    # Filename of the script to check

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$currentVersion = 'version', # Version of the local script

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$ReferenceVersion = 'version', # Version of the remote script

        [Parameter(Mandatory = $false)]
        [switch]$UpdateIfOutdated,           # Auto-copy if outdated

        [Parameter(Mandatory = $false)]
        [switch]$log,                        # Enable logging

        [Parameter(Mandatory = $false)]
        [string]$LogPath = $env:LOCALAPPDATA # Log path (defaults to LocalAppData)
    )

    # Validate parameters
    if (-not $currentVersion) {
        Write-Host ""
        Write-Warning "No script version detected. Please declare `$version in your script or pass -currentVersion explicitly."
        Read-Host "Press Enter to continue"
        return
    }

    if (-not $LogPath -or -not (Test-Path $LogPath)) {
        Write-Host ""
        Write-Warning "Invalid or empty LogPath. Defaulting to `$env:LOCALAPPDATA"
        $LogPath = $env:LOCALAPPDATA
        Read-Host "Press Enter to continue"
   }

   if (-not ($package.ToLower().EndsWith(".ps1") -or $package.ToLower().EndsWith(".psm1"))){
    Write-Warning "The package name should be a .ps1 or .psm1 script file."
    Read-Host "Press Enter to continue"
    return
  }

    # Set variables
    $sourcePath      = Join-Path $scriptPath $package                               # Full path to master copy
    $callerPath      = Split-Path -Parent $($MyInvocation.PSCommandPath)           # Get the path of the calling script

    if (-not (Test-Path $sourcePath -PathType Leaf)) {
        Write-Host ""
        Write-Warning "Master script not found at '$sourcePath'. Please correct the path and re-run the script"
        Read-Host "Press Enter to continue"
        return
    }

    # Extract version number from master script
    $pattern = $pattern = [regex]::Escape("`$$ReferenceVersion") + '\s*=\s*["'']?([\d\.]+)'
    $versionLine = Get-Content $sourcePath | Select-String -Pattern $pattern -AllMatches

    if ($versionLine -and $versionLine.Matches.Count -gt 0) {
        $versionMatch = $versionLine.Matches[0].Groups[1].Value
        [version]$MasterVersion = $versionMatch
    } else {
        $status = "Version Not Found"

    if ($PSBoundParameters.ContainsKey('log')) {
        $logFilePath = Write-VersionLog -Package $package -LocalVersion "N/A" -MasterVersion "N/A" -Status $status -LogPath $LogPath
        Write-Verbose "Log saved to: $logFilePath"
    }
         Write-Warning "Version Not Found.  Reference Version: $ReferenceVersion"
        Read-Host "Press enter to continue"
        return
        }

        # Resolve the variable dynamically by name
        try {
            [version]$currentVersionValue = (Get-Variable -Name $currentVersion -ErrorAction Stop).Value
        } catch {
            Write-Warning "Could not resolve the variable named '$currentVersion'. Ensure it is declared inside the local script before calling the function."
            return
        }


# Master version higher than current version
if ($MasterVersion -gt $currentVersionValue) {
    $status = "Update Needed"
    Write-Host "`nYou are running an older version of $package." -ForegroundColor Yellow
    Write-Host "Latest version: $MasterVersion" -ForegroundColor Green
    Write-Host "Your version: $currentVersionValue" -ForegroundColor Red

    $stagingFolder = Join-Path $callerPath "Staging"
    if (-not (Test-Path $stagingFolder)) {
        New-Item -Path $stagingFolder -ItemType Directory -Force | Out-Null
    }

    $stagingPath = Join-Path $stagingFolder $package

    if ($UpdateIfOutdated) {
        try {
            Copy-Item -Path "$sourcePath" -Destination "$stagingPath" -Force
            Write-Host "`nUpdated script saved to staging folder:" -ForegroundColor Yellow -NoNewline
            Write-Host " $stagingPath" -ForegroundColor Cyan
            Write-Host "`nPlease run the updated script located in the staging folder." -ForegroundColor Green
            Read-Host "Press Enter to continue"

            if ($PSBoundParameters.ContainsKey('log')) {
                $logFilePath = Write-VersionLog -Package $package -LocalVersion $currentVersionValue -MasterVersion $MasterVersion -Status $status -LogPath $LogPath
                Write-Verbose "Log saved to: $logFilePath"
            }     
            return $status      

        } catch {
            Write-Host ""
            Write-Warning "Update Failed: $_"
            Read-Host "Press Enter to continue"
        }

    } else {
        $response = Read-Host "Update Available. Copy new version now? (Y/N)"
        if ($response -match '^[Yy]$') {
            try {
                Copy-Item -Path "$sourcePath" -Destination "$stagingPath" -Force
                Write-Host "`nUpdated script saved to staging folder:" -ForegroundColor Yellow -NoNewline
                Write-Host " $stagingPath" -ForegroundColor Cyan
                Write-Host "`nPlease run the updated script from:`n $stagingPath" -ForegroundColor Green
                Read-Host "Press Enter to continue"

                if ($PSBoundParameters.ContainsKey('log'))  {
                   $logFilePath =  Write-VersionLog -Package $package -LocalVersion $currentVersionValue -MasterVersion $MasterVersion -Status $status -LogPath $LogPath
                    Write-Verbose "Log saved to: $logFilePath" 
                }    
                return $status
                

            } catch {
                Write-Host ""
                Write-Warning "Update Failed: $_"
                Write-Host "Skipping update. Continuing with current version"
                Read-Host "Press Enter to continue"
            }
        } else {
            Write-Host "Skipping update. Continuing with current version..." -ForegroundColor DarkGray
            Start-Sleep -Seconds 2
        }
    }
      
    # Master version and current version are the same
    } elseif ($MasterVersion -eq $currentVersionValue) {
        $status = "Current"
        Write-Host "`nYou are running the current version of $package - version: $MasterVersion" -ForegroundColor Green
        Write-Host "Continuing..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 2

        if ($PSBoundParameters.ContainsKey('log'))  {
            $logFilePath = Write-VersionLog -Package $package -LocalVersion $currentVersionValue -MasterVersion $MasterVersion -Status $status -LogPath $LogPath
            Write-Verbose "Log saved to: $logFilePath" 
        }
        return $status
        

    # Current version is higher than master version
    } else {
        $status = "Ahead"
        Write-Host "`nYou are running a higher version than master!" -ForegroundColor Cyan
        Write-Host "Continuing..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 2

        if ($PSBoundParameters.ContainsKey('log'))  {
            $logFilePath = Write-VersionLog -Package $package -LocalVersion $currentVersionValue -MasterVersion $MasterVersion -Status $status -LogPath $LogPath
            Write-Verbose "Log saved to: $logFilePath" 
        }
        return $status
        
    }

} # End Function
