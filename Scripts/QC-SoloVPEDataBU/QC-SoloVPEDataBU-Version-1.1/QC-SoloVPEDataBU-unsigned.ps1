# QC-SoloVPEDataBU.ps1
<#
.SYNOPSIS
   QC Script to copy SoloVPE equipment database and registry entries to network.     
   
   Requirements as follows:
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
   QC Script to copy SoloVPE equipment database and registry entries to network.   

   [See SYNOPSIS for script requirements]
  
   [INSTALLATION - see QC-SoloVPEDataBU-installation_Instructions.docx]

   
.PARAMETER ParamName
         Optional
         Defaults to QC-SoloVPEDataBU.param.
         Param file is assumed to reside in the same directory as this script.    The Local directory cannot be overwritten.

.EXAMPLE
    # Using the QC-SoloVPEDataBU.param as the default parameter file.
    Powershell -file QC-SoloVPEDataBU-signed.ps1

.EXAMPLE
    # Choosing to use another parameter file other than the default.  (Must still be located in the same directory as the running script.)
    Powershell -file QC-SoloVPEDataBU.ps1 -ParamName "Bobs-Special-parameter-file.param"



.NOTES
   Version Author:      Ron Gines
   Version Number:      1.0
   Version Date:        October 10, 2022
   Version Comments:    Initial version

   Version Author:      Ron Gines
   Version NUmber:      1.1
   Version Date:        October 18, 2022
   Version Comments:    fix Log write Error
                        Changed to only write out one set of backups.  Multiple copies determined not to be needed since the NAS is backed up.
                        Cleaned up the param file.
                        Created separate installation instructions in a spearate Word Document.

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
#$MyTargetBU         = "$TargetShare\$TargetDirectory\$SystemName\$UniqueDate"  # Determined no need for multiple backups by MRoeder after DI discussions. 10/14/2022.
$MyTargetBU         = "$TargetShare\$TargetDirectory\$SystemName"

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
Out-File -FilePath $MyLogFile -Append -InputObject "End of QC-SoloVPEDataBU.ps1 log"
Out-File -FilePath $MyLogFile -Append -InputObject "========================================"
Out-File -FilePath $MyLogFile -Append -InputObject "End of Log - $UniqueDate"
Out-File -FilePath $MyLogFile -Append -InputObject "========================================"


exit