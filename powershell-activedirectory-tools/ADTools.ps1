<#
.SYNOPSIS
    Active Directory Toolkit - Query, unlock, and enable AD user accounts

.DESCRIPTION
    A set of interactive PowerShell functions for common Active Directory user management tasks:
    - Search by first/last name or username
    - Check account lockout, enablement, and password expiration
    - Unlock locked out users
    - Enable disabled users

.NOTES
    Author: Dan Lourenco
    Last Updated: 2025-06-02
#>

function Debug-User {
    Clear-Host
    $first = Read-Host 'Enter first name'
    $last = Read-Host 'Enter last name'

    $users = Get-ADUser -Filter { givenName -like $first -and surname -like $last } -Properties *
    
    if ($users.Count -eq 1) {
        Show-UserStatus -User $users
    } elseif ($users.Count -gt 1) {
        $users | Select-Object @{n='Index'; e={$global:i=0}},{n='Name';e={$_.Name}},SamAccountName | Format-Table -AutoSize
        $choice = Read-Host "Select account index"
        $selected = $users[$choice]
        Show-UserStatus -User $selected
    } else {
        Write-Warning "No matching users found."
    }
    Pause
    Select-ADFunction
}

function Username {
    Clear-Host
    $username = Read-Host 'Enter username'
    $user = Get-ADUser $username -Properties * -ErrorAction SilentlyContinue
    if ($user) {
        Show-UserStatus -User $user
    } else {
        Write-Warning "User not found."
    }
    Pause
    Select-ADFunction
}

function Show-UserStatus {
    param ([Parameter(Mandatory)]$User)
    $passExpiry = [datetime]::FromFileTime($User.'msDS-UserPasswordExpiryTimeComputed')

    [pscustomobject]@{
        'Name' = "$($User.GivenName) $($User.Surname)"
        'UPN' = $User.UserPrincipalName
        'SamAccountName' = $User.SamAccountName
        'Enabled' = $User.Enabled
        'Locked Out' = $User.LockedOut
        'Password Expires' = $passExpiry.ToString("MM-dd-yyyy")
        'Password Never Expires' = $User.PasswordNeverExpires
        'Account Expires' = $User.AccountExpirationDate
    } | Format-List
}

function Unlock-ADUserAccount {
    Clear-Host
    $username = Read-Host 'Enter username to unlock'
    $user = Get-ADUser $username -Properties LockedOut -ErrorAction SilentlyContinue
    if ($user) {
        if ($user.LockedOut) {
            try {
                Unlock-ADAccount -Identity $user.SamAccountName -Confirm:$false
                Write-Host "$($user.SamAccountName) has been unlocked."
            } catch {
                Write-Warning $_.Exception.Message
            }
        } else {
            Write-Host "$($user.SamAccountName) is not locked out."
        }
    } else {
        Write-Warning "User not found."
    }
    Pause
    Select-ADFunction
}

function Enable-ADUserAccount {
    Clear-Host
    $username = Read-Host 'Enter username to enable'
    $user = Get-ADUser $username -Properties Enabled -ErrorAction SilentlyContinue
    if ($user) {
        if (-not $user.Enabled) {
            try {
                Enable-ADAccount -Identity $user.SamAccountName -Confirm:$false
                Write-Host "$($user.SamAccountName) has been enabled."
            } catch {
                Write-Warning $_.Exception.Message
            }
        } else {
            Write-Host "$($user.SamAccountName) is already enabled."
        }
    } else {
        Write-Warning "User not found."
    }
    Pause
    Select-ADFunction
}

function Select-ADFunction {
    Clear-Host
    Write-Host '============= Active Directory User Tool ============='
    Write-Host '1. Debug by First/Last Name'
    Write-Host '2. Debug by Username'
    Write-Host '3. Unlock User'
    Write-Host '4. Enable User'
    Write-Host 'Q. Quit'
    Write-Host ''

    $choice = Read-Host 'Select an option'
    switch ($choice.ToUpper()) {
        '1' { Debug-User }
        '2' { Username }
        '3' { Unlock-ADUserAccount }
        '4' { Enable-ADUserAccount }
        'Q' { return }
        default {
            Write-Warning 'Invalid selection.'
            Pause
            Select-ADFunction
        }
    }
}

Select-ADFunction
