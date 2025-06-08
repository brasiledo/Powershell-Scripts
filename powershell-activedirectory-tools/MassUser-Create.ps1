<#
.SYNOPSIS
Creates new AD user accounts from a CSV file.

.DESCRIPTION
- Requires ActiveDirectory module.
- Imports users from 'NewUsersFinal.csv', creates accounts if they don’t exist.
- Archives the original CSV with a timestamp.
- Logs skipped/duplicate users and any account creation errors.

.NOTES
- Input file: 'NewUsersFinal.csv' must exist in same folder as this script.
- Expected columns: Username, Firstname, Lastname, Initials, Email, Streetaddress, City, Zipcode, State, Country, Telephone, Jobtitle, Company, Department
#>

# --- Configurable Section ---
$Domain         = 'teknet.local'
$OU             = 'OU=Automation,DC=teknet,DC=local'
$InputCsv       = 'NewUsersFinal.csv'
$ErrorLog       = 'NewUser-CreationErrors.log'
$LogDir         = '.\Archive'

# --- Initialize ---
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory | Out-Null
}

# --- Check for input CSV file ---
if (-not (Test-Path ".\$InputCsv")) {
    Write-Warning "'$InputCsv' not found. Make sure it is in the same folder as this script."
    return
}

# --- Prompt for default password securely ---
$SecurePassword = Read-Host "Enter default password for all accounts" -AsSecureString

# --- Import CSV ---
$ADUsers = Import-Csv ".\$InputCsv"

# --- Process Each User ---
foreach ($User in $ADUsers) {
    try {
        $existing = Get-ADUser -Filter "SamAccountName -eq '$($User.username)'" -ErrorAction Stop
        if ($existing) {
            Add-Content -Path $ErrorLog -Value "[$(Get-Date)] $($User.username) already exists. Skipped."
            continue
        }
    } catch {
        # Proceed if user not found (error expected for non-existing users)
    }

    try {
        $UPN = "$($User.username)@$Domain"
        $FullName = "$($User.firstname) $($User.lastname)"
        $DisplayName = "$($User.lastname), $($User.firstname)"

        $userProps = @{
            SamAccountName         = $User.username
            UserPrincipalName      = $UPN
            Name                   = $FullName
            GivenName              = $User.firstname
            Surname                = $User.lastname
            Initials               = $User.initials
            Enabled                = $false
            DisplayName            = $DisplayName
            Path                   = $OU
            City                   = $User.city
            PostalCode             = $User.zipcode
            Country                = $User.country
            Company                = $User.company
            State                  = $User.state
            StreetAddress          = $User.streetaddress
            OfficePhone            = $User.telephone
            EmailAddress           = $User.email
            Title                  = $User.jobtitle
            Department             = $User.department
            AccountPassword        = $SecurePassword
            ChangePasswordAtLogon = $true
        }

        New-ADUser @userProps -PassThru | Out-Null
    }
    catch {
        Add-Content -Path $ErrorLog -Value "[$(Get-Date)] ERROR creating $($User.username): $($_.Exception.Message)"
        continue
    }
}

# --- Archive CSV ---
$timestamp = Get-Date -Format 'MM-dd-yyyy-HHmm'
$archivedName = "$($InputCsv -replace '\.csv$', "-Archive-$timestamp.csv")"
Rename-Item -Path ".\$InputCsv" -NewName $archivedName
Move-Item -Path ".\$archivedName" -Destination $LogDir -Force

# --- Completion ---
Write-Host "`nAD user creation complete."
Write-Host "Errors (if any) logged to: $ErrorLog"
Write-Host "CSV archived to: $LogDir"
Read-Host -Prompt "Press Enter to exit"
