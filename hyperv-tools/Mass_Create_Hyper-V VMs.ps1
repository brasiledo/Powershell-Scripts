<#
.SYNOPSIS
    Automates bulk Hyper-V VM creation using a configuration Excel file.

.DESCRIPTION
    - Converts the provided Excel file to CSV
    - Copies OS and Data VHDX files to target folders
    - Creates Hyper-V VMs on a specified host using the input data
    - Generates PowerShell setup scripts for network, renaming, and domain join
    - Produces a first-run setup script to enable guest services and copy config scripts

.NOTES
    Author: Dan L
    Version: 2.0
    Date: 2025-06-03
    Required: Hyper-V enabled host with credentials and PowerShell remoting enabled
    File: Hyper-V_Setup_Details.xlsx in the same folder as the script

.INPUT FILE
    Hyper-V_Setup_Details.xlsx with headers:
    Host, SourceOS, SourceData, VMNameHyperV, SwitchName, Memory, Generation,
    ProcessorCount, VLAN, VHDPath, TargetOS, TargetData, ServerName,
    CurrentNetworkAdapterName, NewNetworkAdapterName, IPAddress, Subnet,
    GatewayAddress, DNS, WINS, Domain, User
#>

# Remove old CSV
Remove-Item ".\Hyper-V_Setup_Details.csv" -ErrorAction SilentlyContinue

# Convert Excel to CSV
$excel = New-Object -ComObject Excel.Application
$excel.DisplayAlerts = $false
$workbook = $excel.Workbooks.Open(".\Hyper-V_Setup_Details.xlsx")
$workbook.Sheets.Item(1).SaveAs(".\Hyper-V_Setup_Details.csv", 6)
$workbook.Close($false)
$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
[GC]::Collect()

# Import configuration
$VMConfig = Import-Csv ".\Hyper-V_Setup_Details.csv" | Where-Object { $_.VMNameHyperV -and $_.Host }

# Get credentials for remote host
$cred = Get-Credential

# Remote steps for each host
foreach ($vm in $VMConfig) {
    Invoke-Command -ComputerName $vm.Host -Credential $cred -ScriptBlock {
        param($vm)

        $vmFolder = Join-Path $vm.VHDPath $vm.VMNameHyperV
        New-Item -ItemType Directory -Path $vmFolder -Force | Out-Null

        if ($vm.SourceOS) {
            Copy-Item -Path $vm.SourceOS -Destination (Join-Path $vmFolder $vm.TargetOS) -Force
        }
        if ($vm.SourceData) {
            Copy-Item -Path $vm.SourceData -Destination (Join-Path $vmFolder $vm.TargetData) -Force
        }

        # Create VM
        $vmObj = New-VM -Name $vm.VMNameHyperV -MemoryStartupBytes (Invoke-Expression $vm.Memory) -Generation $vm.Generation -VHDPath (Join-Path $vmFolder $vm.TargetOS) -SwitchName $vm.SwitchName
        Set-VMProcessor -VMName $vm.VMNameHyperV -Count $vm.ProcessorCount

        if ($vm.VLAN) {
            Set-VMNetworkAdapterVlan -VMName $vm.VMNameHyperV -Access -VlanId $vm.VLAN
        }

        if ($vm.TargetData) {
            Add-VMHardDiskDrive -VMName $vm.VMNameHyperV -Path (Join-Path $vmFolder $vm.TargetData) -ControllerType SCSI -ControllerNumber 0
        }
    } -ArgumentList $vm
}

# Create Host Setup Scripts
Invoke-Command -ComputerName $vm.Host -Credential $cred -ScriptBlock {
    if (Test-Path "C:\scripts\ServerSetupScripts") {
        Remove-Item "C:\scripts\ServerSetupScripts" -Recurse -Force
    }
    New-Item "C:\scripts\ServerSetupScripts" -ItemType Directory | Out-Null
}

# Generate VM Setup Scripts
foreach ($vm in $VMConfig) {
    $outputFile = "C:\scripts\ServerSetupScripts\$($vm.ServerName).ps1"

    $scriptContent = @()
    $scriptContent += "Set-ExecutionPolicy Bypass -Scope Process -Force"
    $scriptContent += "Rename-NetAdapter -Name '$($vm.CurrentNetworkAdapterName)' -NewName '$($vm.NewNetworkAdapterName)'"
    $scriptContent += "netsh interface ip set address '$($vm.NewNetworkAdapterName)' static $($vm.IPAddress) $($vm.Subnet) $($vm.GatewayAddress)"
    $scriptContent += "Set-DnsClientServerAddress -InterfaceAlias '$($vm.NewNetworkAdapterName)' -ServerAddresses $($vm.DNS)"

    if ($vm.WINS) {
        $scriptContent += "netsh interface ip set wins '$($vm.NewNetworkAdapterName)' static $($vm.WINS)"
    }

    $scriptContent += "Add-Computer -DomainName $($vm.Domain) -Credential (Get-Credential $($vm.User)) -NewName '$($vm.ServerName)' -Restart"

    Invoke-Command -ComputerName $vm.Host -Credential $cred -ScriptBlock {
        param($outputFile, $scriptContent)
        $scriptContent | Set-Content -Path $outputFile
    } -ArgumentList $outputFile, $scriptContent
}

# Create "Run First" Script
$firstRunScript = "C:\scripts\ServerSetupScripts\Run_First_Script_HyperV_GuestServices_CopySetupFiles.ps1"
Invoke-Command -ComputerName $vm.Host -Credential $cred -ScriptBlock {
    param($firstRunScript, $VMConfig)

    $lines = @()
    $lines += "# Enable Guest Services and Copy Scripts"
    foreach ($vm in $VMConfig) {
        $lines += "Enable-VMIntegrationService -VMName '$($vm.VMNameHyperV)' -Name 'Guest Service Interface'"
        $lines += "Copy-VMFile '$($vm.VMNameHyperV)' -SourcePath 'C:\Powershell\$($vm.ServerName).ps1' -DestinationPath 'C:\Powershell\$($vm.ServerName).ps1' -CreateFullPath -FileSource Host"
        $lines += "Disable-VMIntegrationService -VMName '$($vm.VMNameHyperV)' -Name 'Guest Service Interface'"
        $lines += ""
    }
    $lines | Set-Content -Path $firstRunScript
} -ArgumentList $firstRunScript, $VMConfig

Write-Host "All VMs configured and setup scripts created on host(s)."
