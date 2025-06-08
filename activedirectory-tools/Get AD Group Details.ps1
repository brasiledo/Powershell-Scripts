Function Get-GroupDetails {
    [CmdletBinding()]
    Param()

    $ErrorActionPreference = 'Stop'
    Clear-Host

    # Prompt for group name
    $GroupName = Read-Host "Enter AD Group Name"
    if (-not $GroupName) {
        Write-Warning "No group name entered. Exiting."
        return
    }

    # Try to get the group
    try {
        $Group = Get-ADGroup -Identity $GroupName -Properties DistinguishedName
    } catch {
        Write-Warning "Group '$GroupName' does not exist."
        return
    }

    # Get members
    $Members = Get-ADObject -Filter "MemberOf -eq '$($Group.DistinguishedName)'" -Properties ObjectClass

    $UserMembers        = $Members | Where-Object { $_.ObjectClass -eq 'user' }
    $ServiceAccounts    = $UserMembers | Where-Object { $_.Name -like 'svc*' }
    $NormalUsers        = $UserMembers | Where-Object { $_.Name -notlike 'svc*' }
    $NonUserMembers     = $Members   | Where-Object { $_.ObjectClass -ne 'user' }

    $UserInfo = $NormalUsers | ForEach-Object {
        Get-ADUser $_ -Properties uidNumber, unixHomeDirectory, gidNumber, loginShell, Enabled, MemberOf
    }

    $SvcInfo = $ServiceAccounts | ForEach-Object {
        Get-ADUser $_ -Properties Enabled, MemberOf
    }

    $UnixGroupDN = 'CN=UX-RG-UnixUsers,OU=Role,OU=Unix Groups,OU=Unix,DC=CORP,DC=CHARTERCOM,DC=com'

    # Prepare output block
    $Summary = [PSCustomObject]@{
        'Group Name'        = $Group.SamAccountName
        'Total Members'     = $Members.Count
        'Disabled Users'    = ($UserInfo | Where-Object { -not $_.Enabled }).Count
        'Group OU'          = ($Group.DistinguishedName -replace '^CN=.*?,', '')
    }

    # Display summary
    Write-Host "`n===== Group Summary =====" -ForegroundColor Cyan
    $Summary | Format-List

    # User Table
    if ($UserInfo) {
        Write-Host "`n===== User Members =====" -ForegroundColor Yellow
        $UserInfo | Sort-Object Enabled | Select-Object `
            @{Name='Name'; Expression={$_.Name}},
            SamAccountName,
            uidNumber,
            unixHomeDirectory,
            gidNumber,
            loginShell,
            @{Name='Enabled'; Expression={$_.Enabled}},
            @{Name='In UX Unix Group'; Expression={$_.MemberOf -contains $UnixGroupDN}} |
            Format-Table -AutoSize
    }

    # Service Account Table
    if ($SvcInfo) {
        Write-Host "`n===== Service Accounts =====" -ForegroundColor Yellow
        $SvcInfo | Sort-Object Enabled | Select-Object `
            @{Name='Name'; Expression={$_.Name}},
            @{Name='Enabled'; Expression={$_.Enabled}},
            @{Name='In UX Unix Group'; Expression={$_.MemberOf -contains $UnixGroupDN}} |
            Format-Table -AutoSize
    }

    # Non-user objects
    if ($NonUserMembers) {
        Write-Host "`n===== Non-User Members (Nested groups or other objects) =====" -ForegroundColor Yellow
        $NonUserMembers | Select-Object Name, ObjectClass | Format-Table -AutoSize
    }

    # Export log
    $LogPath = Join-Path -Path "$env:USERPROFILE\Desktop" -ChildPath "Group-Logs"
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }

    $DateStamp = Get-Date -Format "yyyy-MM-dd_HHmm"
    $LogFile = Join-Path $LogPath "$($Group.SamAccountName)_$DateStamp.log"

    # Capture just summary + basic user info in export
    $ExportData = @()
    $ExportData += $Summary
    $ExportData += $UserInfo | Select-Object Name, SamAccountName, Enabled, uidNumber, gidNumber

    $ExportData | Out-File -FilePath $LogFile -Encoding UTF8

    # Clean up old logs
    Get-ChildItem -Path $LogPath -Filter "*.log" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Force

    Write-Host "`nLog saved to $LogFile" -ForegroundColor Green
}
