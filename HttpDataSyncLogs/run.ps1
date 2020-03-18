#
#   Function App to get Azure SQL Data Sync Logs and write them to console output
#
#   to view logs make sure application insights is setup and set an alert for the following query
#
#    traces
#    | where message contains "ResourceGroupName" 
#    | where message contains "Error"     # optional to filter on errors
#    | project message 
#    | limit 5
#
#    logs appear like
# #   {
#   "TimeStamp": "2020-03-17T03:59:53.0133333Z",
#   "LogLevel": "Success",
#   "Details": "Sync completed successfully in 83.05 seconds. \r\n\tUpload:   0 changes applied\r\n\tDownload: 0 changes applied",
#   "Source": "example.database.windows.net/exampleDB1"
# }
#
#
#
# https://github.com/chrismckelt/data-sync-log-grabber
# #
using namespace System.Net
using namespace Microsoft.Azure.Commands.Sql.DataSync.Model
using namespace System.Collections.Generic

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
# Write-Host "HttpDataSyncLogs HTTP trigger started."

# variables - fetch from env var / slot setting
$environment =  [Environment]::GetEnvironmentVariable('environment', "User")
$subscriptionid =  [Environment]::GetEnvironmentVariable('subscriptionid', "User")
$tenantid =  [Environment]::GetEnvironmentVariable('tenantid', "User")
$spn_clientid =  [Environment]::GetEnvironmentVariable('spn_clientid', "User")
$spn_secret =  [Environment]::GetEnvironmentVariable('spn_secret', "User")
$customerId = [Environment]::GetEnvironmentVariable('customerId', "User")
$sharedKey =  [Environment]::GetEnvironmentVariable('sharedKey', "User")
$resourcegroup1 =  [Environment]::GetEnvironmentVariable('resourcegroup1', "User")
$sqlserver1 =  [Environment]::GetEnvironmentVariable('sqlserver1', "User")
$sqldatabase1 =  [Environment]::GetEnvironmentVariable('sqldatabase1', "User")
$syncGroupName =  [Environment]::GetEnvironmentVariable('syncGroupName', "User")

$syncLogList = $null
$syncLogStartTime = Get-Date

#Write-host "subscriptionid = $subscriptionid"
#Write-host "tenantid = $tenantid"

# login
$password = ConvertTo-SecureString $spn_secret -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential -ArgumentList ($spn_clientid, $password)
Connect-AzAccount -Credential $psCred -Tenant $tenantid -ServicePrincipal

try {
    $syncLogList = Get-AzSqlSyncGroupLog  -ResourceGroupName $resourcegroup1 `
        -ServerName $sqlserver1 `
        -DatabaseName $sqldatabase1 `
        -syncGroupName $syncGroupName `
        -StartTime $syncLogStartTime.AddMinutes(-5).ToUniversalTime() `
        -EndTime $syncLogStartTime.ToUniversalTime()

    if ($synclogList.Length -gt 0) {
        foreach ($syncLog in $syncLogList) {
            Write-Host $syncLog.TimeStamp : $syncLog.Details
        }
    }else{
        Write-Warning "No logs"
    }
}
catch {
    $ErrorMessage = $_.Exception.Message
    Write-Error $ErrorMessage 
    Break;
}

foreach ($log in $syncLogList)
{
    $log | Add-Member -Name "SubscriptionId" -Value $SubscriptionId -MemberType NoteProperty
    $log | Add-Member -Name "ResourceGroupName" -Value $resourcegroup1 -MemberType NoteProperty
    $log | Add-Member -Name "ServerName" -Value $sqlserver1 -MemberType NoteProperty
    $log | Add-Member -Name "HubDatabaseName" -Value $sqldatabase1 -MemberType NoteProperty
    $log | Add-Member -Name "SyncGroupName" -Value $syncGroupName -MemberType NoteProperty 

    #Filter out Successes to Reduce Data Volume to OMS
    #Include the 5 commented out line below to enable the filter
    #For($i=0; $i -lt $Log.Length; $i++ ) {
    #    if($Log[$i].LogLevel -eq "Success") {
    #      $Log[$i] =""      
    #    }
    # }
}


# write to console so logs are captured by application insights
$json = ConvertTo-JSON $syncLogList

Write-Host $json

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $syncLogList
    })



# Optionally if you want to post to log analytics - see code below


# $result = PostOMSData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType
# if ($result -eq 200) 
# {
#     Write-Host "Success"
# }
# if ($result -ne 200) 
# {   
#     Write-Error $result
#     throw 
# @"
#     Posting to OMS Failed                         
#     Runbook Name: DataSyncOMSIntegration                         
# "@
# }
    


# #  functions - code to post to log analytics - put just write to console and use app insights with a scope 
# ### Create the function to create the authorization signature
# Function BuildSignature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
# {
#     $xHeaders = "x-ms-date:" + $date
#     $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

#     $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
#     $keyBytes = [Convert]::FromBase64String($sharedKey)

#     $sha256 = New-Object System.Security.Cryptography.HMACSHA256
#     $sha256.Key = $keyBytes
#     $calculatedHash = $sha256.ComputeHash($bytesToHash)
#     $encodedHash = [Convert]::ToBase64String($calculatedHash)
#     $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
#     return $authorization
# }
# Function PostOMSData($customerId, $sharedKey, $body, $logType)
# {
#     $method = "POST"
#     $contentType = "application/json"
#     $resource = "/api/logs"
#     $rfc1123date = [DateTime]::UtcNow.ToString("r")
#     $contentLength = $body.Length
#     $signature = BuildSignature `
#         -customerId $customerId `
#         -sharedKey $sharedKey `
#         -date $rfc1123date `
#         -contentLength $contentLength `
#         -fileName $fileName `
#         -method $method `
#         -contentType $contentType `
#         -resource $resource
#     $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

#     $headers = @{
#         "Authorization" = $signature;
#         "Log-Type" = $logType;
#         "x-ms-date" = $rfc1123date;
#         "time-generated-field" = $TimeStampField;
#     }

#     $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
#     return $response.StatusCode

# }