#Requires -Run As Adminisrator

# Add bloatware apps here 
        $applist = @(
            "*windowscommunicationsapps*"
            "*officehub*"
            "*windowscamera*"
            "*soundrecorder*"
            "*getstarted*"
            "**windowsphone*"
            "*bingnews*"
            "*bingweather*"
            "*bingfinance*"
            "*windowsmaps*"
            "*3dbuilder*"
            "*windowsalarms*"
            "*windowscommunicationsapps*"
            "*officehub*"
            "*skypeapp*"
            "*getstarted*"
            "*zunemusic*"
            "*windowsmaps*"
            "*solitairecollection*"
            "*xboxapp*"
            "*XboxGameOverlay*"  
            "*Microsoft3DViewer*"
            "*gethelp*"
            "*screensketch*"
            "*Microsoft.YourPhone*"
            "*Wallet*" 
            "*MicrosoftStickyNotes*"
            "*WindowsFeedbackHub*"
            "*StorePurchaseApp *"
            "*MixedReality.Portal*"
            
           )
          
          
    ForEach ($app in $applist) {
        $apppackage=get-appxpackage -allusers $app -ErrorAction SilentlyContinue
        if ($apppackage){

      # Extra step to confirm delete
       $remove=read-host "remove app $($apppackage.name)? (Y)"
          if ($remove -eq 'Y'){
          try {
            $apppackage |  Remove-AppxPackage -Erroraction stop
            }catch {$_.Exception.Message}
       

      # Completely remove app from all users
      get-appxprovisionedpackage -online | where-object {$_.displayname -like $app}  -ErrorAction SilentlyContinue | Remove-ProvisionedAppxPackage -online
             }
             } else { 
              Write-Host "Unable to find package:" $App
              }
             }
pause
