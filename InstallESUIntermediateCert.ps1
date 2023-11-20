
function Install-ESUIntermediateCert 
{
    [CmdletBinding()]
    param ()

    # run this script on elevated powershell.exe 
    $esuTempFolder = "$env:windir\esuTemp"
    $esutempDirectoryExisted = $false
    if( -not (Test-Path $esuTempFolder)) {
        New-Item -Path $esuTempFolder -ItemType Directory -Force
        $esutempDirectoryExisted = $true
     }

    Push-Location $esuTempFolder 
 
    Invoke-WebRequest -Uri "https://www.microsoft.com/pkiops/certs/Microsoft%20Azure%20TLS%20Issuing%20CA%2001%20-%20xsign.crt" -OutFile ./matlsissuingca01.crt
    certutil -addstore CA ./matlsissuingca01.crt
 
    Pop-Location

    #Remove the temp directory
    if( -not $esutempDirectoryExisted){
        Remove-Item -Recurse -Path $esuTempFolder -force -verbose
    }
}

Install-ESUIntermediateCert  -verBose
##Reboot the machine if machine needs a reboot before installing the updates.
