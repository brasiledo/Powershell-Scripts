param (
    [string]$ServiceAccount, # "SERVICE-ACCOUNT-NAME",
    [string]$RecipientsPath, # "C:\Scripts\PasswordExpiryAlert\Alert_Emails.txt",
    [int]$PasswordMaxAgeDays # expire days
)

function Send-ExpiryAlertEmail {
    param (
        [string]$Account,
        [datetime]$ExpireDate,
        [int]$DaysLeft,
        [string[]]$Recipients
    )

    $Subject = "Expiration Notice: $Account Expires in $DaysLeft Day(s)"
    $Body = @"
Hi Team,

This is a reminder that the password for the service account '$Account' is set to expire on $($ExpireDate.ToString("dddd, MMMM dd, yyyy")).

Please plan accordingly to update the password before it expires.

Thanks,  
IT Operations
"@

    Send-MailMessage -SmtpServer "smtp.domain.com" `
                     -Port 587 `
                     -From "it-support@domain.com" `
                     -To "it-support@domain.com" `  # Placeholder To
                     -Bcc $Recipients `
                     -Subject $Subject `
                     -Body $Body `
                     -BodyAsHtml:$false
}

function Send-ExpiryCalendarInvite {
    param (
        [string]$Account,
        [datetime]$PasswordChangedDate,
        [string[]]$Recipients
    )

    $Outlook = New-Object -ComObject Outlook.Application
    $Namespace = $Outlook.GetNamespace("MAPI")

    foreach ($Recipient in $Recipients) {
        $Appt = $Outlook.CreateItem(1)
        $Appt.Subject = "Password Auto-Rotation: $Account"
        $Appt.Start = $PasswordChangedDate.Date
        $Appt.AllDayEvent = $true
        $Appt.BusyStatus = 0           # Free
        $Appt.ReminderSet = $false     # No popup
        $Appt.MeetingStatus = 1        # olMeeting
        $Appt.Recipients.Add($Recipient)
        $Appt.Send()
    }
}

# ---------------------------
# Main Script Logic
# ---------------------------
$Today = Get-Date
$PasswordLastSet = (Get-ADUser -Identity $ServiceAccount -Properties PasswordLastSet).PasswordLastSet
$ExpireDate = $PasswordLastSet.AddDays($PasswordMaxAgeDays)
$DaysRemaining = ($ExpireDate - $Today).Days

$Recipients = Get-Content $RecipientsPath

# Send email alert
Send-ExpiryAlertEmail -Account $ServiceAccount -ExpireDate $ExpireDate -DaysLeft $DaysRemaining -Recipients $Recipients

# Send calendar invite on actual password rotation date
Send-ExpiryCalendarInvite -Account $ServiceAccount -PasswordChangedDate $PasswordLastSet -Recipients $Recipients
