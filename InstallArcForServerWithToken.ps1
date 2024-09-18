param(
      [Parameter(Mandatory)] # Don't add Mandatory if it's false. Cause this the default
      [string]$principalId 
     ) 

$global:scriptPath = $myinvocation.mycommand.definition

function Get-MachineDetails {
    param(
          [Parameter(Mandatory)] # Don't add Mandatory if it's false. Cause this the default
          [string]$principalId 
    ) 

    # get token
    $content=Invoke-WebRequest -Method Get -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&object_id=$princiPalId&resource=https://management.azure.com/" -Headers @{Metadata="true"}
    $access_token = ($content.Content|ConvertFrom-Json).access_token

    # machine details
    $content=Invoke-WebRequest -Method Get -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01" -Headers @{Metadata="true"} 
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

    $machine_info = Get-MachineDetails -principalId $principalId

    $env:ACCESS_TOKEN = $machine_info.access_token;
    $env:SUBSCRIPTION_ID = $machine_info.subscriptionID;
    $env:RESOURCE_GROUP = $machine_info.resourceGroupName;
    $env:TENANT_ID = "72f988bf-86f1-41af-91ab-2d7cd011db47";
    $env:LOCATION = $machine_info.resourceLocation;
    $env:AUTH_TYPE = "principal";
    $env:CORRELATION_ID = "c0a82881-305f-4243-b9e3-96861a595b7e";
    $env:CLOUD = "AzureCloud";
    

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072;

    # Download the installation package
    Invoke-WebRequest -UseBasicParsing -Uri "https://aka.ms/azcmagent-windows" -TimeoutSec 30 -OutFile "$env:TEMP\install_windows_azcmagent.ps1";

    # Install the hybrid agent
    & "$env:TEMP\install_windows_azcmagent.ps1";
    if ($LASTEXITCODE -ne 0) { exit 1; }

    # Run connect command
   & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect  --resource-group "$env:RESOURCE_GROUP" --tenant-id "$env:TENANT_ID" --location "$env:LOCATION" --subscription-id "$env:SUBSCRIPTION_ID" --cloud "$env:CLOUD" --correlation-id "$env:CORRELATION_ID" --access-token "$env:ACCESS_TOKEN";
}
catch {
    $logBody = @{subscriptionId="$env:SUBSCRIPTION_ID";resourceGroup="$env:RESOURCE_GROUP";tenantId="$env:TENANT_ID";location="$env:LOCATION";correlationId="$env:CORRELATION_ID";authType="$env:AUTH_TYPE";operation="onboarding";messageType=$_.FullyQualifiedErrorId;message="$_";};
    Invoke-WebRequest -UseBasicParsing -Uri "https://gbl.his.arc.azure.com/log" -Method "PUT" -Body ($logBody | ConvertTo-Json) | out-null;
    Write-Host  -ForegroundColor red $_.Exception;
}
