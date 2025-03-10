 <#
    .SYNOPSIS
        Take the CMS name as parameter and use it to retrieve the backup results from all servers in the CMS since the last sync timestamp
    .DESCRIPTION
        Objectives : 
        - Take the CMS name as parameter and use it to retrieve the backup history from all servers in the CMS since the last sync timestamp
        - Write the result into a table BackupResults in the database
        - Update the last sync timestamp in the table BackupResults
        
        The script will use the following tables:
        - BackupResults : to store the backup results
        - DbBackupHistorySync : to store the last sync timestamp

    .PARAMETER CmsName
        The name of the CMS to use to retrieve the backup results
    .PARAMETER SqlLogInstance
        The name of the SQL Server instance to use to connect to the database that contains the backup results tables
    .PARAMETER SqlLogDatabase
        The name of the database that contains the history tables
    .PARAMETER Force
        If specified, the script will force the sync and ignore the last sync timestamp
    .PARAMETER FastTransferDirectory
        The directory to use for the fasttransfer.exe utility
    .PARAMETER ParallelDegree
        Determine the degree of parallelisme to get data 0 ==> all cpu, -2 ==> 1/2 of CPU, 3 ==> 3 CPUs, 1 ==> No Parallel
    .PARAMETER Whatif

    .EXAMPLE
        .\Sync-DbaDbBackupResults.ps1 -CmsName "BCKFSPRD01" -SqlLogInstance "BCKFSPRD01" -SqlLogDatabase "MSSQLBackupSolution_Reporting" -FastTransferDirectory "E:\FastTransfer\"
        Sync the backup history from all servers in the CMS MyCms since the last sync timestamp
#>

param (
    [string]$CmsName,
    [string]$SqlLogInstance,
    [string]$SqlLogDatabase,
    [switch]$Force,
    [string]$FastTransferDirectory,    
    [int]$ParallelDegree=1,
    [switch]$Whatif
)

# Load the dbatools module
#Import-Module dbatools

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

$ft_mode="None"

if($ParallelDegree -ne 1)
{$ft_mode="Ntile"}

# Get the server and instance from the cms
$SqlInstances = Get-DbaRegisteredServer -SqlInstance $CmsName -Group CMS

$EndTimeStamp = Get-Date
# Format $EndTimeStamp and $LastSyncTimeStamp to be used in the SQL query with an iso datetime format
$EndTimeStampstr = $EndTimeStamp.ToString("yyyy-MM-ddTHH:mm:ss")

$SQL_GetDBBackupResultsSync = "SELECT ServerName, CONVERT(VARCHAR(19),MAX(LastUpdateResults),126) LastUpdate FROM [dbo].[DbBackupHistorySync] GROUP BY ServerName "
# Get the last sync timestamp for each server 
$ResLastSyncTimeStamp = Invoke-DbaQuery -SqlInstance $SqlLogInstance -Database $SqlLogDatabase -Query $SQL_GetDBBackupResultsSync
# Join the SqlInstances dataset with the $ResLastSyncTimeStamp based on ServerName




$SqlInstances = $SqlInstances | ForEach-Object {
    $ServerName = $_.Name
    $LastUpdate = ($ResLastSyncTimeStamp | Where-Object { $_.ServerName -eq $ServerName }).LastUpdate

    # Ajoute la propriété LastUpdate
    $_ | Add-Member -MemberType NoteProperty -Name LastUpdate -Value $LastUpdate -PassThru 
}


# Read the SQL query to get the backup history from file 
$SQL_GetBackupResults_template = Get-Content -Path ".\GetBackupResults.sql" -Raw

$ReturnCode = 0

#iterate over each instance in $SQLInstances and 
# get the backup history between the last sync timestamp and the current timestamp

foreach($SqlInstance in $SqlInstances) {
    $SqlInstanceName = $SqlInstance.Name
    $ResLastSyncTimeStamp = $SqlInstance.LastUpdate    

    if (($ResLastSyncTimeStamp -is [DBNull]) -or $Force) {
        $LastSyncTimeStamp = "2000-01-01T00:00:00"
    }
    else {
        $LastSyncTimeStamp = $ResLastSyncTimeStamp
    }
   

    # Add the where clause to the query on the [End] colum that must be greater than the last sync timestamp and less than the current timestamp
    $SQL_GetDBBackupResults = $SQL_GetBackupResults_template.replace("%%CollecServer%%",$SqlInstanceName) + "
    WHERE [End] > '${LastSyncTimeStamp}' AND [End] <= '${EndTimeStampstr}'"
    #Write-Output $SQL_GetDBBackupResults


    # use fasttransfer.exe to get the backup history from the server and write to the log database
    $FastTransferCommand = "${FastTransferDirectory}FastTransfer.exe --sourceconnectiontype ""mssql"" --sourceserver ""${SqlInstanceName}"" --sourcedatabase ""MSSQLBackupSolutionDB"" --sourcetrusted --query ""`${SQL_GetDBBackupResults}"" --targetconnectiontype ""msbulk"" --targetserver ""${SqlLogInstance}"" --targettrusted --targetdatabase ""${SqlLogDatabase}"" --targetschema ""dbo"" --targettable ""BackupResults"" --method ""${ft_mode}"" --distributeKeyColumn ""[end]"" --sourceschema ""dbo"" --sourcetable ""BackupResults"" --degree ""${ParallelDegree}"" --loadmode ""Append"" --runid ""${RunId}"" --settingsfile ""${FastTransferDirectory}FastTransfer_Settings.json"""

    if(!$Whatif)
    {
        try {
                # Execute the command and pushing the $SQL_GetDBBackupResults variable command and get return code
                Invoke-Expression $FastTransferCommand -ErrorAction Stop   
                $ftrc=$LASTEXITCODE     

                Write-Output "FastTransfer Return Code = ${ftrc}"


                # Update the last sync timestamp in the DbBackupHistorySync table only if the return code is 0
                if ($ftrc -eq 0) {

                    $SQLUPDATE = "UPDATE [dbo].[DbBackupHistorySync] SET LastUpdateResults = '$EndTimeStampstr' WHERE ServerName = '$SqlInstanceName'"
                    Invoke-DbaQuery -SqlInstance $SqlLogInstance -Database $SqlLogDatabase -Query $SQLUPDATE
                }
            
        }
        catch {
            Write-Error "An error occured while syncing the backup history from $SqlInstanceName"
            $ReturnCode = 1
        }
    }
}

exit $ReturnCode

