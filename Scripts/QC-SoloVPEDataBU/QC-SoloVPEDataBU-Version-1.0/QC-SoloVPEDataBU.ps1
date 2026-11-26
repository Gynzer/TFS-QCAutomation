<# QC-SoloVPEDataBU.ps1

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

.PARAMETER
   - ParamName        
         Optional
         Defaults to QC-SoloVPEDataBU.param.
         Param file is assumed to reside in the same directory as this script.    This cannot be overwritten.

.EXAMPLE
    # Using the QC-SoloVPEDataBU.param as the default parameter file.
    Powershell .\QC-SoloVPEDataBU.cmd

    # Choosing to use another parameter file other than the default.  (Must still be located in the same directory as the running script.)
    Powershell .\QC-SoloVPEDataBU.cmd -ParamName "Bobs-Special-parameter-file.param"



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
# SIG # Begin signature block
# MIIYugYJKoZIhvcNAQcCoIIYqzCCGKcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDhBS71ieq7QzP1
# fed38aZhgrpuqNHzR4HuOq+YFYbub6CCEqwwggVNMIIDNaADAgECAhRL0s7OuCZf
# WdFVmG+gHdHi8/Fz/DANBgkqhkiG9w0BAQsFADCBvTELMAkGA1UEBhMCVVMxFjAU
# BgNVBAgMDU1hc3NhY2h1c2V0dHMxEDAOBgNVBAcMB1dhbHRoYW0xITAfBgNVBAoM
# GFRoZXJtbyBGaXNoZXIgU2NpZW50aWZpYzEuMCwGA1UECwwlQ29ycG9yYXRlIElu
# ZnJhc3RydWN0dXJlIGFuZCBTZWN1cml0eTExMC8GA1UEAwwoVGhlcm1vIEZpc2hl
# ciBTY2llbnRpZmljIElzc3VpbmcgQ0EgLSBHMTAeFw0yMTA0MDExNTM0NDdaFw0y
# NjAzMzExNTM0NDdaMIGLMQswCQYDVQQGEwJVUzEWMBQGA1UECAwNTWFzc2FjaHVz
# ZXR0czEQMA4GA1UEBwwHV2FsdGhhbTEhMB8GA1UECgwYVGhlcm1vIEZpc2hlciBT
# Y2llbnRpZmljMQwwCgYDVQQLDANDSVMxITAfBgNVBAMMGFRoZXJtbyBGaXNoZXIg
# U2NpZW50aWZpYzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAM/NOADR
# 3mTWpeFh1sk9njh6XKBIbaG6gSy84cyp0hL+CJ7ja7G4tNlZilDfwWB4LMw4VeAR
# hWicJ9t2ZkpblzsVKCX7Nn+cKTIOP0OMPlrUqJwOZJd/Fvb/pmo6yN6l8In2SXf5
# bHVrUatluT5QbJHSpCAzco/MzHRCqL3MuRu5GebLF6Tk/2lZ7vEEn+gxcn+cy278
# hSR7x6jMF+SgPrwAn4w/AoZaKGoqC2ezIGVE68/l3K9udOyzlj7tjmvHS2vPA7rZ
# uieOdpUaEIzxFsFsUhi6cwICJD4GYcCSudkrhv4fSnYKtPqHj0JAG5SP7lqGwa7D
# X/1Qo8dxcHcZRzcCAwEAAaN1MHMwDAYDVR0TAQH/BAIwADAfBgNVHSMEGDAWgBQQ
# zOma0YOpf9IUhkUssxqtuHtjuTATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4E
# FgQUZXIgpR87JYQ1CiGI0g0lgG7mpv8wDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3
# DQEBCwUAA4ICAQA+pNqNOYWTu1u3UFNkP3D0PWPwGQwQlnSpb3UrMnei7LOooG5F
# 2SOQsdcgnPbJbqN6GuXvPzZLv20650QguFz+5mcnEBSzjE+d/3cCtn1MZu1ZsgnI
# e3TOwrO1xK1yz0wDpjg+tut3BISly7ocg+2pwVjdKUXXQ2waCzy3D+A5Y9p4gZj/
# Zm3arUwdYat1zWnJhSpL4ncwCT/G3/GuMyapTTy4U3D4IaLu7/dl/9Xny2A+rcaz
# 47zPByfsu2u349Y0inxLCorH33KiO6Xp+TayvgMJK3RhXZDCg7aUIKCWiDjaO244
# sGx/vIgWIWrExgNo6HFpB1ZvB169hhOyOR8YgMxFZGTCwpxIMYpLOLjrZXjzc/6J
# N96v4VwVyJgbjLolHpXdPgWjbOLJug3FjmUXYOxuGT9XJBzzhaQ30SR57rYgkWMR
# 6P2h0+vcb6LvJzhCenEHn+KBpU1ERMNQPSgo7LMBq4hHlQ/0775REnavlQTLX07l
# +5iIKkqqxyneqKlWMCE49ChMKV3pWuFj3jkl2EdXshw7EhaXKdTcnhu/VLRDNgmC
# VdqWPJ+k4EFfqww3aMRoGyXbv46Scgy8yggwjj9RFgpBPBvFTwIxnuhau3dl1isi
# 9evKp5eo197T2fyE2HqQ6wy4phaZl2+Kq1brch6tpIphvGet+0sNisaLkTCCBVkw
# ggNBoAMCAQICFCk5Ff+STIZ5/aoDSeCqvtkNDbaFMA0GCSqGSIb3DQEBCwUAMIG9
# MQswCQYDVQQGEwJVUzEWMBQGA1UECAwNTWFzc2FjaHVzZXR0czEQMA4GA1UEBwwH
# V2FsdGhhbTEhMB8GA1UECgwYVGhlcm1vIEZpc2hlciBTY2llbnRpZmljMS4wLAYD
# VQQLDCVDb3Jwb3JhdGUgSW5mcmFzdHJ1Y3R1cmUgYW5kIFNlY3VyaXR5MTEwLwYD
# VQQDDChUaGVybW8gRmlzaGVyIFNjaWVudGlmaWMgSXNzdWluZyBDQSAtIEcxMB4X
# DTIyMDQwNTEwMDMwOFoXDTIzMDQwNTEwMDMwOFowgZQxCzAJBgNVBAYTAlVTMRYw
# FAYDVQQIDA1NYXNzYWNodXNldHRzMRAwDgYDVQQHDAdXYWx0aGFtMSEwHwYDVQQK
# DBhUaGVybW8gRmlzaGVyIFNjaWVudGlmaWMxDDAKBgNVBAsMA0NJUzEqMCgGA1UE
# AwwhVGhlcm1vIEZpc2hlciBTY2llbnRpZmljIFRTQSAtIEcxMIIBIjANBgkqhkiG
# 9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzA8+0u8m/7c4ihv1E9KQEwIuC0E9HczNmBhK
# 1eE6BeyDr1wDlHqHTRX0PpeAbGs07FNB83MwbvmkGLhhYrtA0SQR8zIo/DZOauT/
# Cd4lwdEg6gql41kvxWica7oZcSblJ/rKO3PqXlLqyP9BO8RhKUzk+EPE5JxkKTjh
# DVEOCw5c1AVVzT5aH2D9/w7zS69vxe9x9KuOajADMxuS0Xx1gVisE2ERP09SBXJx
# CVZCIYsCOUuQFzQ0WhRn/OLCuD3jyrulZg4EqzkmH0/N0sZSTAmMOAaxGzinNqZO
# MJR8zzdLonKrCckZPtCumwKKTH1eNG4HhnXEB1n7ochZLPM3QwIDAQABo3gwdjAM
# BgNVHRMBAf8EAjAAMB8GA1UdIwQYMBaAFBDM6ZrRg6l/0hSGRSyzGq24e2O5MBYG
# A1UdJQEB/wQMMAoGCCsGAQUFBwMIMB0GA1UdDgQWBBRAzi+5dmuoXD6A92SnOD+3
# cZLXEDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAF7zZO5APrJ4
# JfcETQ/qGK8MYDtFZtTD1LRs9gkkb7MCk7kVJZYlOFR8YvgaDPbnj3QJu+2VUeAF
# Dy6bTn/Aj9/0fMWJJrdHWL2f+EHRHL6ycsMT3qJhK1+yyLG+/WAPmDljaR/RUmsO
# MpFh9W4qu+Rqq+RX7BGKYIoZPy9pHGOWbGyY0uEvZCWxNMhcRzyv29lMfgHvQL71
# NuwPrxBgwWGPou892SKw2GSroUMmWCOFfyrB1hNzr3ptNNqatfwRjHQvO55xw1MV
# nD8dtUnqyET0rD77gCW8zyWe//zga5e72U/UuFSJDyjHJt0NbXwwqEdHI7KZzmJZ
# 9Ne/ZawQyibr7wbkcjCJn61yzBMPnF9fsn0bXDQ0/4C1xnU+7qiUEAG+AVnEyZKl
# yA6b/gs5f0r1BCNqrZreUAfWZPQFByDyzgbZb0NZeM36I9gYxgxvUkaADneJeSQJ
# ZotTWhYLV2BAQZDP+n6e4JMzfe50qvQsdksM0jGlX+mq5rYcW/d75QxfuxAhdF6X
# Uex7x+9aV9fvDNCCKYR2+9LrPfEmEwvIxlAQfrDvP+2GTdLvhsHZTJNoVZsqPrhb
# ZDE8dPh8pXTZmVzfH6dBhh9if2pXi/DiNoXvTB1PlwFM0Ax10s1vofwJ9z8r2xab
# RLJQdJvji9stT2v6+a3/++jdsJorWa7gMIIH+jCCBeKgAwIBAgIUdh1Uc7UzYgKm
# mfghv/rpfiO7qaEwDQYJKoZIhvcNAQELBQAwgboxCzAJBgNVBAYTAlVTMRYwFAYD
# VQQIDA1NYXNzYWNodXNldHRzMRAwDgYDVQQHDAdXYWx0aGFtMSEwHwYDVQQKDBhU
# aGVybW8gRmlzaGVyIFNjaWVudGlmaWMxLjAsBgNVBAsMJUNvcnBvcmF0ZSBJbmZy
# YXN0cnVjdHVyZSBhbmQgU2VjdXJpdHkxLjAsBgNVBAMMJVRoZXJtbyBGaXNoZXIg
# U2NpZW50aWZpYyBSb290IENBIC0gRzEwHhcNMjAwNzAxMTQ0MzI1WhcNMzAwNjI5
# MTQ0MzI1WjCBvTELMAkGA1UEBhMCVVMxFjAUBgNVBAgMDU1hc3NhY2h1c2V0dHMx
# EDAOBgNVBAcMB1dhbHRoYW0xITAfBgNVBAoMGFRoZXJtbyBGaXNoZXIgU2NpZW50
# aWZpYzEuMCwGA1UECwwlQ29ycG9yYXRlIEluZnJhc3RydWN0dXJlIGFuZCBTZWN1
# cml0eTExMC8GA1UEAwwoVGhlcm1vIEZpc2hlciBTY2llbnRpZmljIElzc3Vpbmcg
# Q0EgLSBHMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMMpv2z2juIZ
# 78X/5afDQez3aAzLLa6qhiYijHt5vxdlY5hwpmegp5Gh7VwJ75NckOs9bAXistkM
# sejYx+LO15vWNOdyOzviyz3QAIwAKD0lrQ5dkpdRYZGovcxGICe3xwabfgcPCPUx
# Jjes4pFtUyCKgjaKJXCYentIytdXNIq2SbOJEbER/RK935UlL+dN+84dDeWSBkfH
# OYuSVYfrSkiMkVAUXhOcKJYSAIOT+j/47FQbSq66Vi5cXH29tzunsXPLG6YUjpnj
# EBJnVkLf9S0UdAbVI30KWJDWWwkAYQW7+dKqiy8aa7rjhOqW4uIzvdox150FnhgB
# BhCkeT7qInE3dENFCia3NVusAZakdNfmgwSQ8ZqkafHJWbr1+wcQxspthWtWvYmg
# pgm+FEi1+BamT4IJ3p7cDeejkoEMeZNpBFYiWADZjLNV+AEG774sHJwIKVa+fwmD
# pGoB+fcb2UNyo8+fFy327VPu3jT0lU98RfJ4ammbeoJjNSfBU5GkY1cuTMWLseof
# 0afueaoACdfxcxB7SK37dYsk9/DaFpTEfUwtDSseqR832XlUdRHS8zgU/hR033Qe
# 7Q21lFRTzEnNR4d0sRgPTEM0+Aghd3ANVpBrZKA7Kksc3f6EEIIewWyYBsQj6viO
# EDdZGXXWZY9fcDPxo20a+WOkxFfucxRdAgMBAAGjggHxMIIB7TASBgNVHRMBAf8E
# CDAGAQH/AgEAMB8GA1UdIwQYMBaAFBORNK/kM2wrX5wCwtyDx7TzgKo7MIIBMAYD
# VR0gBIIBJzCCASMwEAYOKwYBBAGCknUBAQEDAQEwgdMGCCsGAQUFBwICMIHGMIHD
# BggrBgEFBQcCAjCBtgyBs1JlbGlhbmNlIG9uIHRoaXMgY2VydGlmaWNhdGUgYnkg
# YW55IHBhcnR5IGFzc3VtZXMgYWNjZXB0YW5jZSBvZiB0aGUgdGhlbiBhcHBsaWNh
# YmxlIHN0YW5kYXJkIHRlcm1zIGFuZCBjb25kaXRpb25zIG9mIHVzZSwgY2VydGlm
# aWNhdGUgcG9saWN5IGFuZCBjZXJ0aWZpY2F0aW9uIHByYWN0aWNlIHN0YXRlbWVu
# dHMuMDkGCCsGAQUFBwIBMC0wKwYIKwYBBQUHAgEWH2h0dHBzOi8vdHJ1c3QudGhl
# cm1vZmlzaGVyLmNvbS8wUwYDVR0fBEwwSjBIoEagRIZCaHR0cDovL3BraS50aGVy
# bW9maXNoZXIuY29tL2NybC9UaGVybW9GaXNoZXJTY2llbnRpZmljUm9vdENBRzEu
# Y3JsMB0GA1UdDgQWBBQQzOma0YOpf9IUhkUssxqtuHtjuTAOBgNVHQ8BAf8EBAMC
# AYYwDQYJKoZIhvcNAQELBQADggIBAAucOHJhwnjCsooCkTp4YrxuNnjE6ve5RbGA
# EZSZUhgasiKRJF1LMXqBPNaTJX9DDvU0IYeeCyCGzBfMEcIcMD5o3CRXdFq7p/dc
# ujehaUXUmnC0LfsWSTrpvVXsfN3B5WDVWFhGuX8tUiVqRR6gJu0mevRwCdoGzIv4
# m1i3pmR0pEFtII2qIkCe4mGk1rZA1eNrjzQT1q4EAFshVkXkwdS/XHINykcm1k6r
# akUB7FEP0hvH6VTKgK1SCFTKCdaLMimwLItHVoMcJwpJZQVTZ1ZxMeOlbLalLQ9t
# km+Fgcx1t4keSzEOq52YN3v/tuVKyqjTcHHOeHgqoIlCauQpyq1teQb21rdwwl/5
# 0o5a87V5gugOqdMRDxC6vRcEyvh+VkazaDdCAbDdEg0y6OjStKUriu8VTzL1IFNw
# oRycLy0O/J0cyLAlGFvf15vC2MkySZUmntDctpEs088uUSSP/TwczYhkYzvBJNTU
# NOqM6j7yZuzzkirBcqCFViXiVAJ7zpEfv6yjZPskTlHtrHlV7LivUBeTT1107u+V
# sn6S5T0ooysShhiBVDIsy5QLJTomegn4jWujXt1+YmnqYqiWlfWTCRsw/OTQTTWD
# /bJxaV2oPh558PBnPkzJV6GWp7miwjrYKdoPopw/AYjPKTFRMEDq9B0pnZ8sBUF6
# jEGixkVZMYIFZDCCBWACAQEwgdYwgb0xCzAJBgNVBAYTAlVTMRYwFAYDVQQIDA1N
# YXNzYWNodXNldHRzMRAwDgYDVQQHDAdXYWx0aGFtMSEwHwYDVQQKDBhUaGVybW8g
# RmlzaGVyIFNjaWVudGlmaWMxLjAsBgNVBAsMJUNvcnBvcmF0ZSBJbmZyYXN0cnVj
# dHVyZSBhbmQgU2VjdXJpdHkxMTAvBgNVBAMMKFRoZXJtbyBGaXNoZXIgU2NpZW50
# aWZpYyBJc3N1aW5nIENBIC0gRzECFEvSzs64Jl9Z0VWYb6Ad0eLz8XP8MA0GCWCG
# SAFlAwQCAQUAoIGrMBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEMBgor
# BgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC0GCSqGSIb3
# DQEJNDEgMB4wDQYJYIZIAWUDBAIBBQChDQYJKoZIhvcNAQELBQAwLwYJKoZIhvcN
# AQkEMSIEIMg3iR2yWTag8w70DOUl+Q8KvyadZj85D0EGq9EmAMsOMA0GCSqGSIb3
# DQEBCwUABIIBAGpclmevyntz98jeU7JGbkbWLaqvgAPwDRow/bRa/B5lDbb3gYnk
# Pi18UVsijlujJQc8wXi/5Kf9hVZtguLa97z4rHLmHSWSxs8mZG365I+2AgrOe+0m
# A60scRWvn2H+HqGc5vyamNW4rHc1O753fgVO+fdZKqXfHFuCEV5tED98koyWRhYN
# kPVhvjKHSCBI/5xIKK7yzWhePsmNkX8GTMVvkdcbHCVElZ/8Al2GzNxPKAVerPUy
# BMeoCLhBBDBHeCMuyKJy1cxuxFyCdP2unCc2mZdDEUC5D3YKxJGqfRPZgAY55QQ5
# GoYLDG3JJnoLFjP9v+wK/JikXTOuQ0QBdBKhggKwMIICrAYJKoZIhvcNAQkGMYIC
# nTCCApkCAQEwgdYwgb0xCzAJBgNVBAYTAlVTMRYwFAYDVQQIDA1NYXNzYWNodXNl
# dHRzMRAwDgYDVQQHDAdXYWx0aGFtMSEwHwYDVQQKDBhUaGVybW8gRmlzaGVyIFNj
# aWVudGlmaWMxLjAsBgNVBAsMJUNvcnBvcmF0ZSBJbmZyYXN0cnVjdHVyZSBhbmQg
# U2VjdXJpdHkxMTAvBgNVBAMMKFRoZXJtbyBGaXNoZXIgU2NpZW50aWZpYyBJc3N1
# aW5nIENBIC0gRzECFCk5Ff+STIZ5/aoDSeCqvtkNDbaFMA0GCWCGSAFlAwQCAQUA
# oIGYMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIy
# MTAxMjIyNTgwOVowLQYJKoZIhvcNAQk0MSAwHjANBglghkgBZQMEAgEFAKENBgkq
# hkiG9w0BAQsFADAvBgkqhkiG9w0BCQQxIgQgZ6NqFbICv9PBtV/e9u0YDQZ5nmUT
# 4+w4p3xt9oJxMTwwDQYJKoZIhvcNAQELBQAEggEAlcKcEgqEZ9q7yTnLqJDG0/Rg
# 2qJ1b6W3g5xgqAJPIqlVfzIUar0rMCAq656EUxKe7Xl//Dn1Rvuzsvta9LkCd7tX
# PvEWtrHfADI+rNO730xwoD5fs4VYZ/fzIWX6/5AulrY6cgazNS/OgEDLfCPPV/rH
# texH+tn3zbisEAB/Ze2Q7VvpdvS+Cxrutj7f8f0vDsQbGUrhJYyErXXqJjR1kjaZ
# aO9DVFrQqOrNbvFWfq4ZS3C+yP2EVPYkdhrAcThVBA3qC65slgd5KXmwcr4Yzg1g
# q1px3qEJDNi1YZvrVAdlS8pgl8eu68zx2tGmoOdHUOZSVnC0U0apP8grAyph5w==
# SIG # End signature block
