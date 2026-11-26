# QC-SoloVPEDataBU.ps1
<#
.SYNOPSIS
   QC Script to copy SoloVPE equipment data.     Requirements as follows:
   - Databases
      SVDatastore: C:\ProgramData\CTech\SecureVPE\SVDatastore.db
               Note that the ProgramData folder is generally hidden and needs to be unhidden.
      Solo3: C:\ProgramData\CTech\SoloVPE\Solo3.db 
   - DB Registry Keys
      SecureVPE DBKey: Open the Registry Editor application and then navigate to the following path 
               HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\CTECH\SecureVPE
      SoloVPE DBKey: 
               HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\CTECH\SoloVPE
   - To be backed up to a Network NAS location.
   - Will be run via Scheduled Task under a service account dedicated to each specific system.
   - Parameters to be read from a parameter file: QC-SoloVPEDataBU.param
   - Scripts and parameter file to be stored in C:\QCAutomation\Scripts\QC-SoloVPEDataBU
   - Log Files to be written to C:\QCAutomation\Logs

.DESCRIPTION
   MSE Script to copy SoloVPE equipment data.   

   [See SYNOPSIS for script requirements]
  
   [INSTALLATION]

   1) To install this script copy the *.ps1 and *.param files to C:\QCAutomation\Scripts\QC-SoloVPEDataBU. (Directories may need to be created)
  
   2) Service Account: Make sure that a service account has been created in the AMER domain and located in the GxP OU.
  
   3) The service account should be added to the local system Adminsitrators group.
  
   4) The service account should be granted Full access to the target NAS file resource so that it can save files and create directories.

   5) Edit the QC-Solo-VPEDataBU file.   Explanation follows.

      A)  SystemName  =     
         {This is a descriptive name that will be used in the naming for directories and files.    recommended length 2 - 16 characters}
         [Example:   SoloVPERoom1159]

      B)  TargetNAS   =
         {This is the URL of the target resource.    It will include the Server Name, the resource name.   The script will create a directory 
         below that to store all of its backed up files.   NOTE: the \\ and \ characters are important.    Do not include a trailing \.}
         [Example:  \\USSLO-QC-NAS01\EquipBackups]

      There are additional variables.   These are not to be changed unless under direction of the MSE Automation team.
		
   6) We need to check that the local system is allowed to run powershell scripts.   To test this, use the following steps.

      a) Open a CMd prompt as an Administrator (there are many ways to do this, use your favortie)

      b) Execute the following command:

            powershell get-executionpolicy

      c) Acceptible values (in order of preference) are 
            RemoteSigned, 
            AllSigned, 
            Unrestricted, 
            ByPass (will work, but NOT recommended)

      d) If the ExecutionPolicy is set to something other than what is listed above (restricted for example), use the following command to change the execution policy

            powershell set-executionpolicy remoteSigned -scope LocalMachine

   7) This script is designed to be run from within the task scheduler.   To do so use the following information in fields as you create a new task.
            Name:              "QC-SoloVPEDataBackUp"
            Description:       (Whatever makes sense to you.)
            Program/Script:    powershell.exe
            Arguments:         -file "C:\QCAutomation\Scripts\QC-SoloVPEDataBU.ps1"
            Security:          Run as following account:  [use the domain service account defined for this system]
                               "Run whether user is logged on or not" - Check this option.
            Trigger:           Would suggest not running more than once a day.  But can be set to any time/frequency.

            [NOTE:   If you find that the process is not ending, you can configure the settings to stop the process after an hour.   It should take less than a few minutes to run."

.PARAMETER ParamName
         Optional
         Defaults to QC-SoloVPEDataBU.param.
         Param file is assumed to reside in the same directory as this script.    This cannot be overwritten.

.EXAMPLE
    # Using the QC-SoloVPEDataBU.param as the default parameter file.
    Powershell .\QC-SoloVPEDataBU.ps1

.EXAMPLE
    # Choosing to use another parameter file other than the default.  (Must still be located in the same directory as the running script.)
    Powershell .\QC-SoloVPEDataBU.ps1 -ParamName "Bobs-Special-parameter-file.param"



.NOTES
   Version Author:      Ron Gines
   Version:             1.0
   Version Date:        October 10, 2022
   Version Comments:    Initial version

===========================================================================
#>

Param (
    [Parameter(Mandatory=$false,Position=0)]$ParamName = "QC-SoloVPEDataBU.param"
)

### Get a Unique Timestamp
function Get-UniqueDate {
   $CurrentDate                = Get-Date -format g
   $DateSplit                  = $CurrentDate -split "/"
   $xMo                        = $DateSplit[0]
   if ($xMo.length -eq 1){$xMo = "0$xMo"}
   $xDa                        = $DateSplit[1]
   if ($xDa.length -eq 1){$xDa = "0$xDa"}
   $DateSplit2                 = $DateSplit[2] -split " "
   $xYe                        = $DateSplit2[0]
   $AMPM                       = $DateSplit2[2]
   $DateSplit3                 = $DateSplit2[1] -split ":"
   $UniqueDate                 = $xYe+$xMo+$xDa+"-"+$DateSplit3[0]+$DateSplit3[1]+$AMPM

   return $UniqueDate
}

##############################################
### DO NOT MAKE CHANGES BELOW THIS LINE !! ###
##############################################

# Reading Variables from QC-SoloVPEDatabu.param
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Get-Content $ScriptDir\$ParamName | Foreach-Object {
	If (($_.length -gt 0) -and (!$_.StartsWith("#"))) {
		$Var = $_.Split('=')
        $MyVar = $($var[0]).trim()
        $MyVal = $($var[1]).trim()
		If ($($Var).length -ne 0) {
            If (test-path variable:$MyVar){
                Set-Variable -Name $MyVar -value $MyVal
            }
            else
            {
                New-Variable -Name $MyVar -value $MyVal
            }
        }
		write-output "$MyVar   --  $MyVal"
	}
}


### Local Variables ###

$MyHostname         = HOSTNAME

$UniqueDate         = Get-UniqueDate
$MyLogFile          = "$LogFileDir\QC-SoloVPEDataBU-$UniqueDate.log"

$MyTargetRoot       = "$TargetShare\$TargetDirectory"
$MyTarget           = "$TargetShare\$TargetDirectory\$SystemName"
$MyTargetBU         = "$TargetShare\$TargetDirectory\$SystemName\$UniqueDate"

### Start Log File ###
Out-File -FilePath $MyLogFile -InputObject "Beginning of QC-SoloVPEDataBU.ps1 logs"
Out-File -FilePath $MyLogFile -Append -InputObject "========================================"
Out-File -FilePath $MyLogFile -Append -InputObject "Start of Log - $UniqueDate"
Out-File -FilePath $MyLogFile -Append -InputObject "========================================"


Out-File -FilePath $MyLogFile -Append -InputObject "========================================"
Out-File -FilePath $MyLogFile -Append -InputObject "Checking Target Directories"
Out-File -FilePath $MyLogFile -Append -InputObject "========================================"
### Make sure target location is in order ###
Out-File -FilePath $MyLogFile -Append -InputObject "$(Get-UniqueDate) -- Testing Access to $($MyTargetRoot)"
If (Test-Path $MyTargetRoot) {
    Out-File -FilePath $MyLogFile -Append -InputObject "                 -- Testing Succeeded"
    Out-File -FilePath $MyLogFile -Append -InputObject "$(Get-UniqueDate) -- Testing if exists: $($MyTarget)"
    If (Test-Path $MyTarget) {
        Out-File -FilePath $MyLogFile -Append -InputObject "                 -- Directory Exists."
    }
    else
    {
        Out-File -FilePath $MyLogFile -Append -InputObject "                 -- Directory does not exist.   Creating it now."
        mkdir $MyTarget -erroraction SilentlyContinue | Out-Null
        if (Test-Path $MyTarget) {
            Out-File -FilePath $MyLogFile -Append -InputObject "$(Get-UniqueDate) -- $MyTarget Created Successfully."
            Out-File -FilePath $MyLogFile -Append -InputObject "$(Get-UniqueDate) -- Testing Access to $($MyTargetBU)"
        }
        else
        {
            Out-File -FilePath $MyLogFile -Append -InputObject "                  -- Directory was not created successfully.   Now existing."
            exit
        }
   
    }
    If (Test-Path $MyTargetBU) {
        Out-File -FilePath $MyLogFile -Append -InputObject "                 -- Testing Succeeded for $($MyTargetBU)"
    }
    else
    {
        Out-File -FilePath $MyLogFile -Append -InputObject "$(Get-UniqueDate) -- Creating $($MyTargetBU)"
        mkdir $MyTargetBU -erroraction SilentlyContinue | Out-Null
        if (Test-Path $MyTarget) {
            Out-File -FilePath $MyLogFile -Append -InputObject "                  -- $MyTarget Created Successfully."
        }
        else
        {
            Out-File -FilePath $MyLogFile -Append -InputObject "                  -- $MyTargetBU was not created.    Now Exiting."
            exit                
        }
    }
}
else
{
    Out-File -FilePath $MyLogFile -Append -InputObject "                 -- Testing Failed for $MyTargetRoot - we will be exiting now."
    exit
}

### Copying svdataStore ###
If (Test-Path $SVDataStore) {
    Out-File -FilePath $MyLogFile -Append -InputObject "$(Get-UniqueDate) -- SVDataStore was found at $($SVDataStore).   Copying ..."
    Copy-Item -Path $SVDataStore -Destination $MyTargetBU    
    If (Test-Path "$($MyTargetBU)\$(Split-Path $SVDataStore -leaf)") {
        Out-File -FilePath $MyLogFile -Append -InputObject "                 -- SVDataStore was copied successfully."
    }
    else
    {
        Out-File -FilePath $MyLogFile -Append -InputObject "                 -- ERROR:   SVDataStore was NOT copied successfully."
    }
}
else 
{
    Out-File -FilePath $MyLogFile -Append -InputObject "ERROR            -- ERROR:   SVDataStore was NOT found at $($SVDataStore) therefore NOT copied successfully."
    Out-File -FilePath $MyLogFile -Append -InputObject "ERROR            -- ERROR:     and therefore NOT copied successfully."
}

### Copying Solo3 ###
If (Test-Path $Solo3) {
    Out-File -FilePath $MyLogFile -Append -InputObject "$(Get-UniqueDate) -- Solo3 was found at $($Solo3).   Copying ..."
    Copy-Item -Path $Solo3 -Destination $MyTargetBU    
    If (Test-Path "$($MyTargetBU)\$(Split-Path $Solo3 -leaf)") {
        Out-File -FilePath $MyLogFile -Append -InputObject "                 -- Solo3 was copied successfully."
    }
    else
    {
        Out-File -FilePath $MyLogFile -Append -InputObject "ERROR            -- ERROR:   Solo3 was NOT copied successfully."
    }
}
else 
{
    Out-File -FilePath $MyLogFile -Append -InputObject "ERROR            -- ERROR:   Solo3 was NOT found at $($Solo3) therefore NOT copied successfully."
    Out-File -FilePath $MyLogFile -Append -InputObject "ERROR            -- ERROR:     and therefore NOT copied successfully."
}

### Exporting SoloVPEDBKey ###
Out-File -FilePath $MyLogFile -Append -InputObject "$(Get-UniqueDate) -- Exporting SoloVPEDBKey.   Exporting...."
& reg export $SoloVPEDBKey "$($MyTargetBU)\SoloVPEDBKey.reg"
If (Test-Path "$($MyTargetBU)\SoloVPEDBKey.reg") {
    Out-File -FilePath $MyLogFile -Append -InputObject "                  -- SoloVPEDBKey exported."
}
else
{
    Out-File -FilePath $MyLogFile -Append -InputObject "ERROR             -- ERROR: SoloVPEDBKey was NOT exported."
}


### Exporting SecureVPEDBKey ###
Out-File -FilePath $MyLogFile -Append -InputObject "$(Get-UniqueDate) -- Exporting SecureVPEDBKey.   Exporting...."
& reg export $SecureVPEDBKey "$($MyTargetBU)\SecureVPEDBKey.reg"
If (Test-Path "$($MyTargetBU)\SoloVPEDBKey.reg") {
    Out-File -FilePath $MyLogFile -Append -InputObject "                  -- SecureVPEDBKey exported."
}
else
{
    Out-File -FilePath $MyLogFile -Append -InputObject "ERROR             -- ERROR: SecureVPEDBKey was NOT exported."
}

### End Log File ###
Out-File -FilePath $MyLogFile -InputObject "End of QC-SoloVPEDataBU.ps1 logs"
Out-File -FilePath $MyLogFile -Append -InputObject "========================================"
Out-File -FilePath $MyLogFile -Append -InputObject "End of Log - $UniqueDate"
Out-File -FilePath $MyLogFile -Append -InputObject "========================================"


exit