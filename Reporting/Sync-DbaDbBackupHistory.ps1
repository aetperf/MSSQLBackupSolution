 <#
    .SYNOPSIS
        Take the CMS name as parameter and use it to retrieve the backup history from all servers in the CMS since the last sync timestamp
    .DESCRIPTION
        Objectives : 
        - Take the CMS name as parameter and use it to retrieve the backup history from all servers in the CMS since the last sync timestamp
        - Write the result into a table DbBackupHistory in the database
        - Update the last sync timestamp in the table DbBackupHistory
        
        The script will use the following tables:
        - DbBackupHistory : to store the backup history
        - DbBackupHistorySync : to store the last sync timestamp

    .PARAMETER CmsName
        The name of the CMS to use to retrieve the backup history
    .PARAMETER SqlLogInstance
        The name of the SQL Server instance to use to connect to the database that contains the history tables
    .PARAMETER SqlLogDatabase
        The name of the database that contains the history tables
    .PARAMETER Force
        If specified, the script will force the sync and ignore the last sync timestamp
    .PARAMETER FastTransferDirectory
        The directory to use for the fasttransfer.exe utility

    .EXAMPLE
        .\Sync-DbaDbBackupHistory.ps1 -CmsName "MyCms" -SqlLogInstance "MyInstance" -SqlLogDatabase "MyDatabase" -FastTransferDirectory "D:\Sources\FastTransfer\"
        Sync the backup history from all servers in the CMS MyCms since the last sync timestamp
#>

param (
    [string]$CmsName,
    [string]$SqlLogInstance,
    [string]$SqlLogDatabase,
    [switch]$Force,
    [string]$FastTransferDirectory
)

# Load the dbatools module
Import-Module dbatools

#Check if the Log database exists
if (-not (Test-DbaConnection -SqlInstance $SqlLogInstance -SkipPSRemoting)) {
    Write-Error "The connexion to ${SqlLogInstance} does not work"
    exit
}

# Check if the History tables exist

Try {
    $DbBackupHistorySyncSchema = Get-DbaDbTable -SqlInstance $SqlLogInstance -Database $SqlLogDatabase -Table DbBackupHistorySync -Schema "dbo"
    $DbBackupHistorySchema = Get-DbaDbTable -SqlInstance $SqlLogInstance -Database $SqlLogDatabase -Table DbBackupHistory -Schema "dbo"
}
Catch {
    Write-Error "The tables DbBackupHistorySync and DbBackupHistory do not exist in the database $SqlLogDatabase"
    exit
}

#generate a uuid for the runid
$RunId = [guid]::NewGuid().ToString()

# Get the server and instance from the cms
$SqlInstances = Get-DbaRegisteredServer -SqlInstance $CmsName -Group CMS

$EndTimeStamp = Get-Date
# Format $EndTimeStamp and $LastSyncTimeStamp to be used in the SQL query with an iso datetime format
$EndTimeStampstr = $EndTimeStamp.ToString("yyyy-MM-ddTHH:mm:ss")

$SQL_GetDBBackupHistorySync = "SELECT ServerName, CONVERT(VARCHAR(19),MAX(LastUpdate),126) LastUpdate FROM [dbo].[DbBackupHistorySync] GROUP BY ServerName "
# Get the last sync timestamp for each server 
$ResLastSyncTimeStamp = Invoke-DbaQuery -SqlInstance $SqlLogInstance -Database $SqlLogDatabase -Query $SQL_GetDBBackupHistorySync
# Join the SqlInstances dataset with the $ResLastSyncTimeStamp based on ServerName

$SqlInstances = $SqlInstances | ForEach-Object {
    $ServerName = $_.Name
    $LastUpdate = ($ResLastSyncTimeStamp | Where-Object { $_.ServerName -eq $ServerName }).LastUpdate
    $_ | Add-Member -MemberType NoteProperty -Name LastUpdate -Value $LastUpdate -PassThru
}

# Read the SQL query to get the backup history from file 
$SQL_GetDBBackupHistory_template = Get-Content -Path ".\GetDbaBackupHistoryLastest.sql" -Raw

$ReturnCode = 0

#iterate over each instance in $SQLInstances and 
# get the backup history between the last sync timestamp and the current timestamp

foreach($SqlInstance in $SqlInstances) {
    $SqlInstanceName = $SqlInstance.Name
    $ResLastSyncTimeStamp = $SqlInstance.LastUpdate

    if (($null -eq $ResLastSyncTimeStamp) -or $Force) {
        $LastSyncTimeStamp = "2000-01-01T00:00:00.000"
    }
    else {
        $LastSyncTimeStamp = $ResLastSyncTimeStamp
    }
   

    # Add the where clause to the query on the [End] colum that must be greater than the last sync timestamp and less than the current timestamp
    $SQL_GetDBBackupHistory = $SQL_GetDBBackupHistory_template + "
    WHERE [End] > '$LastSyncTimeStamp' AND [End] <= '$EndTimeStampstr'"
   

    # use fasttransfer.exe to get the backup history from the server and write to the log database
    $FastTransferCommand = "${FastTransferDirectory}FastTransfer.exe --sourceconnectiontype ""mssql"" --sourceserver ""${SqlInstanceName}"" --sourcedatabase ""msdb"" --sourcetrusted --query ""`${SQL_GetDBBackupHistory}"" --targetconnectiontype ""msbulk"" --targetserver ""${SqlLogInstance}"" --targettrusted --targetdatabase ""${SqlLogDatabase}"" --targetschema ""dbo"" --targettable ""DbBackupHistory"" --method ""None"" --loadmode ""Append"" --runid ""${RunId}"""

    # Print the command to execute
    Write-Output $FastTransferCommand


    try {
            # Execute the command and pushing the $SQL_GetDBBackupHistory variable command
    Invoke-Expression $FastTransferCommand 

    # Update the last sync timestamp in the DbBackupHistorySync table
    $SQLUPDATE = "UPDATE [dbo].[DbBackupHistorySync] SET LastUpdate = '$EndTimeStampstr' WHERE ServerName = '$SqlInstanceName'"
    Invoke-DbaQuery -SqlInstance $SqlLogInstance -Database $SqlLogDatabase -Query $SQLUPDATE
        
    }
    catch {
        Write-Error "An error occured while syncing the backup history from $SqlInstanceName"
        $ReturnCode = 1
    }
}

exit $ReturnCode

