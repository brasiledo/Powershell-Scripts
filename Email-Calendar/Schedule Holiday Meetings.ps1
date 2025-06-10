<#
New Year's Day
Martin Luterh King Jr. Day
President's Day
Memorial Day
Juneteenth
Independence Day
Labor Day
Indigenous Peoples' Day
Verteran's Day
Thanksgiving Day
Christmas Day

#>

# Define the holidays with their respective dates

$holidays = @(
    @{ Date = '01/01/2025'; Name = 'New Years Day' }
    @{ Date = '01/20/2025'; Name = 'Martin Luther King Jr. Day' },
    @{ Date = '02/17/2025'; Name = 'Presidents Day' },
    @{ Date = '05/26/2025'; Name = 'Memorial Day' },
    @{ Date = '06/19/2025'; Name = 'Juneteenth' },
    @{ Date = '07/01/2025'; Name = 'Independence Day' },
    @{ Date = '09/01/2025'; Name = 'Labor Day' },
    @{ Date = '10/13/2025'; Name = 'Indigenous Peoples Day' },
    @{ Date = '11/11/2025'; Name = 'Verterans Day' },
    @{ Date = '11/27/2025'; Name = 'Thanksgiving Day' },
    @{ Date = '12/25/2025'; Name = 'Christmas Day' }
 )


# Function to create a holiday in Microsoft Teams

function Create-MeetingHoliday {
    param (
    [string]$holidayName,
    [string]$holidayDate
    )

    try {
        # Create an Outlook Application COM object
        $Outlook = New-Object -ComObject Outlook.Application

        # Create a new meeting item
        $Meeting = $Outlook.CreateItem(1) # 1 corresponds to "olAppointmentItem"

        # Set meeting details
        $Meeting.Subject = $holidayName
        $Meeting.Start = [datetime]::Parse("$holidayDate 12:00 AM") # Set start time
        $Meeting.End = [datetime]::Parse("$holidayDate 11:00 PM")   # Set end time
        $Meeting.ReminderSet = $true                                # Enable reminders
        $Meeting.ReminderMinutesBeforeStart = 0                     # Reminder
        $Meeting.AllDayEvent = $true                                # Set as all day event
        $Meeting.BusyStatus = 2                                     # Set status as 'Busy' 0=Free, 1=Tentative, 2=Busy, 3=Out of Office


        # Save meeting
        $Meeting.Save()

        # Cleanup COM object
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Meeting) | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Outlook) | Out-Null

            Write-Host "Successfully created holiday '$holidayName' on $holidayDate."

        } catch {
            Write-Error "Failed to create holiday '$holidayName' on $holidayDate. Error: $_"
        }
      }

# Loop through each holiday and create it in Teams

foreach ($holiday in $holidays) {

    Create-MeetingHoliday -holidayName $($holiday.Name) -holidayDate $($holiday.Date)
   }

Write-Host "All holidays have been processed."  
