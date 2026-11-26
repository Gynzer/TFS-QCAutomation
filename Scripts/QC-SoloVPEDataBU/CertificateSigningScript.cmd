
cd "C:\program Files\signserver\bin"

signclient-RLG.cmd signdocument -workername tfsG1GeneralMSAuthCodeSigner -host sign1.pki.thermofisher.com -port 443 -truststore "C:\RLGInfo\CodeSign\ManagementCA.cacert.jks" -truststorepwd trustme -keystore "C:\RLGInfo\CodeSign\ron.gines.dev.jks" -keyalias "ron.gines.dev" -infile "C:\Users\ron.gines\OneDrive - Thermo Fisher Scientific\Documents\GitHub\QCAutomation\Scripts\QC-SoloVPEDataBU\QC-SoloVPEDataBU-unsigned.ps1" -outfile "C:\Users\ron.gines\OneDrive - Thermo Fisher Scientific\Documents\GitHub\QCAutomation\Scripts\QC-SoloVPEDataBU\QC-SoloVPEDataBU-signed.ps1"
