#   Function App to get Azure SQL Data Sync Logs and write them to output

To view logs make sure application insights is setup and set an alert for the following query

    traces
    | where message contains "ResourceGroupName" 
    | where message contains "Error"     # optional to filter on errors
    | project message 
    | limit 5

## logs appear like
    {
    "TimeStamp": "2020-03-17T03:59:53.0133333Z",
    "LogLevel": "Success",
    "Details": "Sync completed successfully in 83.05 seconds. \r\n\tUpload:   0 changes applied\r\n\tDownload: 0 changes applied",
    "Source": "example.database.windows.net/exampleDB1"
    }


![image](https://user-images.githubusercontent.com/662868/76823422-2921af80-684f-11ea-93d9-e28051d62c97.png)
