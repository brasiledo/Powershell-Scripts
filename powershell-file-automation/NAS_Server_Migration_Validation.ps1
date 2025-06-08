       $ProjectLoc = Split-Path -parent $MyInvocation.MyCommand.Definition
       $NAS_Path = gc "C:\Users\k087890\OneDrive - Wells Fargo\Documents\Migration Validation Script\Nas_Path.txt"
       $userList = gc "C:\Users\k087890\OneDrive - Wells Fargo\Documents\Migration Validation Script\Userlist.txt"

      #set initial variable for all user folders
        $total=[System.Collections.Generic.list[object]]::new()
 
    $allfolders = Get-ChildItem -Path $NAS_Path -Directory | where-object {$_.name -like '*users*'}
    foreach ($userfolder in $allfolders){
        $dir = Get-ChildItem $userfolder.fullname
        $dir
        pause
        return
        }
    $Result=
            foreach ($subfolder in $dir) {
                 $matched = $false
 
                foreach ($user in $userList) {

                    if ($Subfolder.name -eq "$user") {
                        $matched = $true
                        break
                    } #if
            }
               if (-not $matched) {
                    $Subfolder.fullname
                    } #if
                } #for subfolder
                        
        #set exclude/include variables
        $exclude =  'ZZ.','DM.','LH.','ZY.','HCPA-PST.','UK.'
        $VolscanInclude='ZZ.','ZY.','UK.'      

        #set output variables store discrepancy folders and excludes 'ZZ.','DM.','LH.','ZY.','HCPA-PST.','UK.'
        $Output      = $Result | select-string -pattern $exclude -notmatch

        #set variable to store discrepancy folders and excludes 'LH.','DM','HCPA-PST'
        $volscan     = $allfolders | select-string -pattern $VolscanInclude -SimpleMatch | Foreach-Object { split-path $_ -leaf}
        $DM = $allfolders.name | select-string 'DM.'

         $comparetotal=$NULL     
         if ($result -ne $NULL){
        $comparetotal=(compare-object $NAS_Path -DifferenceObject $($Result.name) | where {$_.SideIndicator -eq "<="}).inputobject
        }
        $psobject = @(
        [pscustomobject]@{ 
            'Total User Folders'                                              = $allfolders.name.count
            'Folder Discrepancies(Excludes DM.ZZ.LH.ZY HCPA-PST + Migrations)'= $Output.count
            'Total Migrations Excluded'                                       = $result.count
            'Total DM Accounts'                                               = ($allfolders.name | select-string 'DM.').count
            'Total ZZ Accounts'                                               = ($allfolders.name | select-string 'ZZ.').count
            'Total UK Accounts'                                               = ($allfolders.name | select-string 'UK.').count
            'Total ZY Accounts'                                               = ($allfolders.name | select-string 'ZY.').count
            'Total LH Accounts'                                               = ($allfolders.name | select-string 'LH.').count
            'HCPA-PST Accounts'                                               = ($allfolders.name | select-string 'HCPA-PST').count
            'Folders on final run, not on server'                             = $($comparetotal).count
            } 
            )
         
     <#
        #sets arrays for output
        $AccessTimes = [System.collections.generic.list[object]]::new()

        #Last Access Time on home folders
          foreach ($item in $output) {
          $gci = Get-Childitem $item -Directory | sort-object lastwritetime -Descending | select -first 1  | select @{n='User';e={(split-path $_.Fullname -parent).split('\')[2]}},@{n='Folder Path';e={$_.Fullname}},@{n='Last Write Time';e={$_.LastWriteTime}}
          $AccessTimes.add($AccessTimes)
         } #for 
         #>
            ### Output ###
           
           $LogPath = "$env:userprofile\Folder_Discrepencies.csv"
           if (test-path $LogPath){
            remove-item $LogPath -force
            }
            $psobject | export-csv $LogPath -NoTypeInformation
            "`n" | add-content $LogPath

            # Matches total users only shows username for copying to part 2 script
            if ($result){
                'Folder Discrepancies: Usernames for part 2 script AD Query' | add-content $LogPath
                $result | Foreach-Object { split-path $_ -leaf} | add-content $LogPath
                "`n" | add-content $LogPath
 
             # Total user folders excludes migration move folders and DM.ZZ.LH.ZY HCPA-PST UK
             'Folder Discrepancies: Full Path for part 3 DM rename script ' | add-content $LogPath
        
            $Output | add-content $LogPath
            "`n" | add-content $LogPath
     
            }else{"No user Discrepancy Folders Found`n"| add-content $LogPath}

            #Shows HCPA-PST folders only - Full path
            if ($allfolders |  select-string -pattern 'HCPA-PST'){
               'HCPA-PST Users' | add-content $LogPat      
                $allfolders |  select-string -pattern 'HCPA-PST' | add-content $LogPath
                "`n" | add-content $LogPath
                }

            #Shows LH Folders only - Full path
            if ($allfolders |  select-string -pattern 'LH.'){
                'LH Users' | add-content $LogPath   
                $allfolders |  select-string -pattern 'LH.' | add-content $LogPath
                "`n" | add-content $LogPath
            }

            #Shows ZY Folders only - Full path
            if ($allfolders |  select-string -pattern 'ZY.'){
                'ZY Users' | add-content $LogPath  
                $allfolders |  select-string -pattern 'ZY.'
                "`n" 
            }
            #Shows UK Folders only - Full path
            if ($allfolders |  select-string -pattern 'UK.'){
                'UK Users' | add-content $LogPath
                $allfolders |  select-string -pattern 'UK.' | add-content $LogPath
                "`n" | add-content $LogPath
            }
            if ($AccessTimes){
             '              Recent Folder Activity for Discrepancies'| add-content $LogPath
           
            $AccessTimes | sort-object "Last Write Time" -Descending | out-string -width 300 | add-content $LogPath
             }
             if ($DM){
             ' DM folders' | add-content $LogPath
        
              $DM | add-content $LogPath
              "`n"  | add-content $LogPath
              ' Without DM'| add-content $LogPath 
              $DM | %{$_ -replace('DM.','') | add-content $LogPath}

               "`n"
              }
            #Show All discrepancy user folder names (Volscan)
            if ($volscan) {
            'Check below folders for Legal Hold (VolScan) - All ZZ ZY and UK Found' | add-content $LogPath 
            "`n" | add-content $LogPath
             'ZZ ZY and UK - Usernames Only' | add-content $LogPath
        
             $volscan | %{ $_.split('.')[1] } | add-content $LogPath
              "`n" | add-content $LogPath
             'ZZ ZY and UK - Folder Names with Prefix' | add-content $LogPath
             $volscan | add-content $LogPath
              "`n"   
             }  
        if ($comparetotal){           
             'Additional Information'| add-content $LogPath
             "`n" | add-content $LogPath  
            'User folder on final run but not on server' | add-content $LogPath
            $comparetotal | out-string -Width 300 | add-content $LogPath
            }else {'no migration folder missing' | add-content $LogPath}

            start-process $LogPath