
<#
   This Script to get the trackfile list from JWP video key and update the title/label of the trackfiles
   Last updated: 2018-12-27
#>

# Log function to logs the details messages for tracking perpose 
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity = 'Information',
        $currentPath = (Get-Location | Select-Object -ExpandProperty Path)
    )

    [pscustomobject]@{
        Time     = (Get-Date -f g)
        Message  = $Message.Trim()
        Severity = $Severity
    } | Export-Csv -Path "$currentPath\TrackUpdateLog $(get-date -f MM-dd-yyyy) $timeStampForlog.csv"  -Append -NoTypeInformation
}

Function Get-OpenFile($initialDirectory) { 
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "Text files (*.csv)|*.csv"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
    $OpenFileDialog.ShowHelp = $true
	
}

# This function used to add the specific business rules/condition for track file name modification
Function Update-Trackname { 
    Param ([string] $strTrackName)

    if ( $strTrackName -match 'english' ) {
        $strTrackName = 'English'
    }
    if ( $strTrackName -match 'spanish' ) {
        $strTrackName = 'Spanish'
    }
    return $strTrackName
}

# This section is the start point of the execution for JWP track file update utility
$timeStampForlog = $(get-date -f HH-mm-ss-tt)
$currentPath = (Get-Location | Select-Object -ExpandProperty Path)
$jWPObjs = $null
$InputFile = Get-OpenFile $currentPath
$csv = Import-Csv $InputFile
$csv | ForEach-Object {	

    $videoKey = $_.Videokey
    Write-Log -Message "`n*** Started Getting Track Details for Video key : $videoKey *** "  -Severity Information
    If (($videoKey -ne $null) -and ($videoKey.length -ne 0)) {

        # get the track file list JWP API Call "/videos/tracks/list"
        $listVideoResponse = $(clack call /videos/tracks/list "{'video_key' : '$videokey','kinds_filter' : 'subtitles','result_limit' : 1000 }")
        $listTrackJsonResponse = $listVideoResponse | ConvertFrom-Json
      
        Write-Log -Message "`n*** Extracted the List of Track Key  *** "  -Severity Information
        for ($i = 0; $i -lt $listTrackJsonResponse.tracks.count; $i++) {
            $trackName = $listTrackJsonResponse.tracks[$i].label
            $trackKey = $listTrackJsonResponse.tracks[$i].key
            Write-Log -Message "`n*** Video Key : $videoKey , Track Key : $trackKey ,  TrackName  before Update :  $trackName  *** "  -Severity Information

            If (($trackKey -ne $null) -and ($trackKey.length -ne 0)) {
                
                # call function to modify the trackname according to the business rules
                $trackNameUpdated = Update-Trackname $trackName
                #update the track file name using JWP API Call "/videos/tracks/update"
                $updateTrackResponse = $(clack call /videos/tracks/update "{'track_key' : '$trackKey','label' : '$trackNameUpdated' }")	
                $updateTrackJsonResponse = $updateTrackResponse | ConvertFrom-Json
                Write-Log -Message "`n*** Video Key : $videoKey , Track Key : $trackKey , TrackName  After Update :  $trackNameUpdated  , Status : $updateTrackJsonResponse.status *** "  -Severity Information
                $toAdd = @"
		[
			{"JWPObjects":{"MediaId" : "$videoKey"," Before trackName" : "$trackName","TrackKey" : "$trackKey" ," After trackName" : "$trackNameUpdated" }}
		]
"@
                $jWPObjs += ConvertFrom-Json -InputObject $toAdd
            }
        }
    }
}
$pathToOutputFile = "OutPutListtrack" + "_trackids.csv"
if ($jWPObjs.JWPObjects -ne $null) {
    $jWPObjs.JWPObjects | export-csv $pathToOutputFile -NoTypeInformation
    Write-Host ("`n***  Total Track file is: {0} *** " -f $jWPObjs.Length)
    Read-Host 'Press Enter to exit...' | Out-Null
}