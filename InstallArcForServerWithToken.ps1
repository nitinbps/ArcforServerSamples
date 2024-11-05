param(
      [string]$cloudEnv = "AzureCloud",
      [Parameter(Mandatory)] # Don't add Mandatory if it's false. Cause this the default
      [string]$principalId 
     ) 

$global:scriptPath = $myinvocation.mycommand.definition

function Get-TenantId {
 
    [cmdletbinding()]
    param([Parameter(Mandatory=$true)][string]$token)
 
    #Validate as per https://tools.ietf.org/html/rfc7519
    #Access and ID tokens are fine, Refresh tokens will not work
    if (!$token.Contains(".") -or !$token.StartsWith("eyJ")) { Write-Error "Invalid token" -ErrorAction Stop }
 
    #Header
    $tokenheader = $token.Split(".")[0].Replace('-', '+').Replace('_', '/')
    #Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
    while ($tokenheader.Length % 4) { Write-Verbose "Invalid length for a Base-64 char array or string, adding ="; $tokenheader += "=" }
   
    #Convert from Base64 encoded string to PSObject all at once
    #[System.Text.Encoding]::ASCII.GetString([system.convert]::FromBase64String($tokenheader)) | ConvertFrom-Json  
    #Payload
    $tokenPayload = $token.Split(".")[1].Replace('-', '+').Replace('_', '/')
    #Fix padding as needed, keep adding "=" until string length modulus 4 reaches 0
    while ($tokenPayload.Length % 4) { Write-Verbose "Invalid length for a Base-64 char array or string, adding ="; $tokenPayload += "=" }

    #Convert to Byte array
    $tokenByteArray = [System.Convert]::FromBase64String($tokenPayload)
    #Convert to string array
    $tokenArray = [System.Text.Encoding]::ASCII.GetString($tokenByteArray)

    #Convert from JSON to PSObject
    $tokobj = $tokenArray | ConvertFrom-Json
    
    return $tokobj.tid
}

function Get-MachineDetails {
    param(
          [Parameter(Mandatory)] # Don't add Mandatory if it's false. Cause this the default
          [string]$principalId 
    ) 

    # get token
    $content=Invoke-WebRequest -UseBasicParsing -Method Get -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&object_id=$princiPalId&resource=$env:AZUREURI" -Headers @{Metadata="true"}
    $access_token = ($content.Content|ConvertFrom-Json).access_token
    $tenantID = Get-TenantId -token $access_token

    # machine details
    $content=Invoke-WebRequest -UseBasicParsing -Method Get -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01" -Headers @{Metadata="true"} 
    $resourceId = ($content.Content|ConvertFrom-Json).compute.resourceId
    $resourceLocation = ($content.Content|ConvertFrom-Json).compute.location
    $resourceId = $resourceId.split("/")
    $subscriptionID = $resourceId[2]
    $resourceGroupName = $resourceId[4]

    $obj = [PSCustomObject] @{
        'access_token' = $access_token
        'subscriptionID' = $subscriptionID
        'resourceGroupName' = $resourceGroupName
        'resourceLocation' = $resourceLocation
        'tenantID' = $tenantID

    }

    return $obj
}

function Restart-AsAdmin {
    $pwshCommand = "powershell"
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $pwshCommand = "pwsh"
    }

    try {
        Write-Host "This script requires administrator permissions to install the Azure Connected Machine Agent. Attempting to restart script with elevated permissions..."
        $arguments = "-NoExit -Command `"& '$scriptPath'`""
        Start-Process $pwshCommand -Verb runAs -ArgumentList $arguments
        exit 0
    } catch {
        throw "Failed to elevate permissions. Please run this script as Administrator."
    }
}

try {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        if ([System.Environment]::UserInteractive) {
            Restart-AsAdmin
        } else {
            throw "This script requires administrator permissions to install the Azure Connected Machine Agent. Please run this script as Administrator."
        }
    }

    [environment]::SetEnvironmentVariable("MSFT_ARC_TEST","true",[EnvironmentVariableTarget]::Machine)
    [environment]::SetEnvironmentVariable("MSFT_ARC_TEST","true",[EnvironmentVariableTarget]::Process)

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072;

    $retryCount = 5
    $sleepSeconds = 3

    if ($cloudEnv -eq "AzureCloud") {

        $env:TENANT_ID = "72f988bf-86f1-41af-91ab-2d7cd011db47";
        $env:AUTH_TYPE = "principal";
        $env:CORRELATION_ID = "c0a82881-305f-4243-b9e3-96861a595b7e";
        $env:CLOUD = "AzureCloud";
        $env:AZUREURI = "https://management.azure.com/"
        $env:HCRPURI = "https://aka.ms/azcmagent-windows"
    } elseif ($cloudEnv -eq "AzureUSGovernment") {
        $env:TENANT_ID = "63296244-ce2c-46d8-bc36-3e558792fbee"
        $env:AUTH_TYPE = "token"
        $env:CORRELATION_ID = "6893e6e5-fc02-4942-b533-73abf43f07ac"
        $env:CLOUD = "AzureUSGovernment"
        $env:AZUREURI = "https://management.usgovcloudapi.net/"
        $env:HCRPURI = "https://gbl.his.arc.azure.us/azcmagent-windows"
    } else {
        Write-Error "Unsupported cloudEnv: $cloudEnv"
		exit 1
    }

    while($retryCount-- -gt 0) {
	try {
	    $machine_info = Get-MachineDetails -principalId $principalId
 	    }
        catch {
	    Write-Host  -ForegroundColor red $_.Exception;
            sleep -Seconds $sleepSeconds
	    continue;
        }
	break
    }
    $env:ACCESS_TOKEN = $machine_info.access_token;
    $env:SUBSCRIPTION_ID = $machine_info.subscriptionID;
    $env:RESOURCE_GROUP = $machine_info.resourceGroupName;
    $env:LOCATION = $machine_info.resourceLocation;
    $env:TENANT_ID = $machine_info.tenantID;
    

    # Download the installation package
    $retryCount = 5
    $sleepSeconds = 3
    while($retryCount-- -gt 0) {
	try {
	        Invoke-WebRequest -UseBasicParsing -Uri "$env:HCRPURI" -TimeoutSec 30 -OutFile "$env:TEMP\install_windows_azcmagent.ps1" ;
 	    }
        catch {
	    Write-Host  -ForegroundColor red $_.Exception;
            sleep -Seconds $sleepSeconds
	    continue;
        }
	break
    }

    # Install the hybrid agent
    & "$env:TEMP\install_windows_azcmagent.ps1";
    if ($LASTEXITCODE -ne 0) { exit 1; }

    # Run connect command
    $retryCount = 3
    while($retryCount-- -gt 0) {
	   & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect  --resource-group "$env:RESOURCE_GROUP" --tenant-id "$env:TENANT_ID" --location "$env:LOCATION" --subscription-id "$env:SUBSCRIPTION_ID" --cloud "$env:CLOUD" --correlation-id "$env:CORRELATION_ID" --access-token "$env:ACCESS_TOKEN";
    }
}
catch {
    $logBody = @{subscriptionId="$env:SUBSCRIPTION_ID";resourceGroup="$env:RESOURCE_GROUP";tenantId="$env:TENANT_ID";location="$env:LOCATION";correlationId="$env:CORRELATION_ID";authType="$env:AUTH_TYPE";operation="onboarding";messageType=$_.FullyQualifiedErrorId;message="$_";};
    Invoke-WebRequest -UseBasicParsing -Uri "https://gbl.his.arc.azure.com/log" -Method "PUT" -Body ($logBody | ConvertTo-Json) | out-null;
    Write-Host  -ForegroundColor red $_.Exception;
}