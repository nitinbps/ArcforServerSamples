# Get the Extended Security Update License contents.
function Get-ESUDocument {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ESUSignedDocument
    )
    $attestedDoc = (Get-Content $ESUSignedDocument | Out-String | ConvertFrom-Json); 
    $signature = [System.Convert]::FromBase64String($attestedDoc.signature); 
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]($signature); 
    $chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain; 
    $chain.Build($cert) | Out-Null; 
    $certificateChain = ''; 
    foreach($element in $chain.ChainElements) 
    { 
        $certificateChain = $certificateChain + $element.Certificate.Subject + ';'; 
    }
 
    Add-Type -AssemblyName System.Security; 
    $signedCms = New-Object -TypeName System.Security.Cryptography.Pkcs.SignedCms; 
    $signedCms.Decode($signature); 
    $content = [System.Text.Encoding]::UTF8.GetString($signedCms.ContentInfo.Content); 
    $json = $content | ConvertFrom-Json; 
    $json | add-member -Name 'schemaVersion' -value $attestedDoc.schemaVersion -MemberType NoteProperty; 
    $json | add-member -Name 'certificateChain' -value $certificateChain -MemberType NoteProperty; 
    return $json; 
}

# Get the Extended Security Update License contents.
function Get-ESUDocumentSignatureChain {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ESUSignedDocument
    )
    $attestedDoc = (Get-Content $ESUSignedDocument | Out-String | ConvertFrom-Json); 
    $signature = [System.Convert]::FromBase64String($attestedDoc.signature); 
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]($signature); 
    $chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain; 
    $chain.Build($cert) | Out-Null; 
    $certificateChain = ''; 
    foreach($element in $chain.ChainElements) 
    { 
        $certificateChain = $certificateChain + $element.Certificate.Subject + ';'; 
    }
 
    return $certificateChain; 
}

# Test the Extended Security Update enrollment.
function Test-ESUEnrollment {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param
    (
    )

    $esuSignedDocument = [System.Environment]::ExpandEnvironmentVariables("%programdata%\\AzureConnectedMachineAgent\\Certs\\License.json");
    if(-not (Test-Path $esuSignedDocument -PathType Leaf))
    {
        Write-Verbose 'Extended Security Update License does not exist.';
        return $false;
    }

    $esuDocument = Get-ESUDocument -ESUSignedDocument $esuSignedDocument;
    if(([Datetime]$esuDocument.timeStamp.expiresOn) -lt (Get-Date))
    {
        Write-Verbose 'Extended Security Update License is expired.';
        return $false;
    }

    if((Get-Date $esuDocument.timeStamp.createdOn) -gt (Get-Date))
    {
        Write-Verbose 'Extended Security Update License does not have a valid start date.';
        return $false;
    }
    
    $esuRegistryKey = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Azure Connected Machine Agent\ArcESU' -ErrorAction SilentlyContinue;
    if(($esuRegistryKey -eq $null) -or ($esuRegistryKey.'Enabled' -ne 1))
    {
        Write-Verbose 'Extended Security Update is not enabled.'; 
        return $false;
    }

    Write-Verbose 'Extended Security Update is enabled.';
    return $true;
}

Test-ESUEnrollment -Verbose
