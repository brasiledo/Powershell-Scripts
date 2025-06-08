<#
.SYNOPSIS
PowerShell function to create Active Directory user accounts with required and optional attributes.

.DESCRIPTION
This function is designed to serve as the primary method for creating domain users. It performs the following:
- Automatically generates a unique username (SamAccountName) based on first initial + last name
- Ensures no duplicate usernames by appending an incrementing number if necessary
- Constructs a proper User Principal Name (UPN)
- Assigns the next available Employee Number by reading from an existing user DB CSV
- Exports basic user info to the user DB after account creation
- Supports optional AD attributes like Title, Department, Manager, etc.
- Allows bulk creation using pipeline input (e.g. from Import-Csv)

Accounts are created in a disabled state and require manual enablement or group-based provisioning.

.PARAMETER FirstName
The user's first name (mandatory)

.PARAMETER LastName
The user's last name (mandatory)

.PARAMETER Password
SecureString password to assign to the new account (mandatory)

.PARAMETER OU
The target OU where the user will be created (default is OU=Automation,DC=domain,DC=local)

.PARAMETER EmployeeDBPath
Path to the CSV used to track created users and employee numbers (default is .\userDB.csv)

.PARAMETER Email
Optional email address

.PARAMETER Description
Optional user description

.PARAMETER Organization
Optional organization value

.PARAMETER Department
Optional department

.PARAMETER Title
Optional job title

.PARAMETER OfficePhone
Optional phone number

.PARAMETER Manager
Optional manager (by username)

.EXAMPLE
# Create a single user
$securePW = Read-Host "Enter password" -AsSecureString
Create-NewUser -FirstName John -LastName Doe -Password $securePW

.EXAMPLE
# Bulk create from CSV
Import-Csv .\newusers.csv | ForEach-Object {
    $_ | Add-Member -NotePropertyName Password -NotePropertyValue $securePW
    Create-NewUser @_
}

.NOTES
Author: Brasiledo
Updated: [Insert today's date]
Version: 2.0
#>


function Create-NewUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$FirstName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$LastName,

        [Parameter(Mandatory)]
        [securestring]$Password,

        [Parameter()]
        [string]$OU = "OU=Automation,DC=domain,DC=local",

        [Parameter()]
        [string]$EmployeeDBPath = ".\userDB.csv",

        [string]$Email,
        [string]$Description,
        [string]$Organization,
        [string]$Department,
        [string]$Title,
        [int]$OfficePhone,
        
        [ValidateScript({ try { Get-ADUser $_ | Out-Null; $true } catch { throw "$_ not found in AD" } })]
        [string]$Manager
    )

    begin {
        # Import existing employee numbers
        $existingUsers = @()
        if (Test-Path $EmployeeDBPath) {
            $existingUsers = Import-Csv $EmployeeDBPath
        }

        # Determine next employee number
        $lastEmpNum = ($existingUsers | Select-Object -Last 1).EmployeeNumber
        [int]$NextEmployeeNumber = if ($lastEmpNum) { $lastEmpNum + 1 } else { 10000 }  # Default starting number
    }

    process {
        # Build base username (1st letter of first + last)
        $baseUsername = ($FirstName.Substring(0,1) + $LastName).ToLower()
        $username = $baseUsername
        $name = "$FirstName $LastName"

        # Deduplicate username
        $counter = 1
        while (Get-ADUser -Filter { SamAccountName -eq $username }) {
            $username = "$baseUsername$counter"
            $counter++
        }

        # Build final UPN
        $UPN = "$username@domain.local"

        # Build CN
        $CN = $name
        if ($counter -gt 1) { $CN = "$name_$($counter - 1)" }

        try {
            # Create the new AD user
            New-ADUser -Name $CN `
                       -DisplayName $name `
                       -GivenName $FirstName `
                       -Surname $LastName `
                       -SamAccountName $username `
                       -UserPrincipalName $UPN `
                       -AccountPassword $Password `
                       -ChangePasswordAtLogon $true `
                       -EmployeeNumber $NextEmployeeNumber `
                       -Path $OU `
                       -Enabled $false `
                       -PassThru |
            ForEach-Object {
                # Apply optional attributes
                $optionalParams = @{
                    EmailAddress = $Email
                    Description  = $Description
                    Organization = $Organization
                    Department   = $Department
                    Title        = $Title
                    OfficePhone  = $OfficePhone
                    Manager      = if ($Manager) { (Get-ADUser $Manager).DistinguishedName } else { $null }
                }

                foreach ($key in $optionalParams.Keys) {
                    if ($null -ne $optionalParams[$key] -and $optionalParams[$key] -ne '') {
                        Set-ADUser -Identity $_.SamAccountName -$key $optionalParams[$key]
                    }
                }

                # Export created user info to CSV
                $exportLine = [PSCustomObject]@{
                    FirstName      = $FirstName
                    LastName       = $LastName
                    Username       = $username
                    EmployeeNumber = $NextEmployeeNumber
                }
                $exportLine | Export-Csv -Path $EmployeeDBPath -Append -NoTypeInformation
            }

            Write-Host "User created: $username ($name)"
        }
        catch {
            Write-Warning "Failed to create user $FirstName $LastName: $_"
        }
    }
}
