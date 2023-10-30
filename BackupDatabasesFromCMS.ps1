 <#
    .SYNOPSIS
        Backup databases of the CMS to target Directory using groups
    .DESCRIPTION
        Objective : List SQL Server Instances from a CMS and Backup all databases (except tempdb) to a target Backup directory
        the script will create a .bak; .diff or .trn file depending of the backup type (full; diff, log)
        "${BackupDirectory}\servername\instancename\dbname\backuptype\servername_dbname_backuptype_timestamp.${BackupExtension}"
       
    .PARAMETER CMSSqlInstance
        The SQL Server instance hosting the CMS database to list instances to backup.

    .PARAMETER Group
        The root group in the CMS where SQLInstances to backup will be listed.

    .PARAMETER BackupType
        The SQL Server backup type (Full, Diff, Log).

    .PARAMETER BackupDirectory
        Target root directory (target backup folder root in each target MSSQL Instance)

    .PARAMETER FileCount
        Number of files to split the backup (improve performance of backup and restore)
        Default 1
        
    .PARAMETER LogDirectory
        Directory where a log file can be stored (Optionnal)

    .NOTES
        Tags: DisasterRecovery, Backup, Restore
        Author: Romain Ferraton, Pierre-Antoine Collet
        Website: 
        Copyright: (c) 2022 by Romain Ferraton, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT
        
        Dependencies : 
            Install-Module Logging
            Install-Module dbatools

        Compatibility : Powershell 5+

    .LINK
        
    .EXAMPLE
        PS C:\> $ProgressPreference = "SilentlyContinue"
        PS C:\> BackupDatabasesFromCMS.ps1 -CMSSqlInstance "localhost\DBA01" -Group "All" -BackupType "Full" -BackupDirectory "G:\BACKUPDB"  -LogDirectory "D:\MSSQLBackupSolution\Logs"
    .EXAMPLE   
        PS C:\> BackupDatabasesFromCMS.ps1 -CMSSqlInstance "localhost\DBA01" -Group "All" -BackupType "Diff" -BackupDirectory "G:\BACKUPDB"  -LogDirectory "D:\MSSQLBackupSolution\Logs"
    .EXAMPLE    
        PS C:\> BackupDatabasesFromCMS.ps1 -CMSSqlInstance "localhost\DBA01" -Group "All" -BackupType "Log" -BackupDirectory "G:\BACKUPDB"  -LogDirectory "D:\MSSQLBackupSolution\Logs"

    #>

param 
(
    [Parameter(Mandatory)] [ValidateSet('Full','Diff','Log')] [string] $BackupType,
    [Parameter(Mandatory)] [string] $BackupDirectory,
    [Parameter(Mandatory)] [string] $CMSSqlInstance,
    [Parameter()] [Int16] $FileCount = 1,
    [Parameter()] [string] $Group = "All",
    [Parameter()] [Int16] $Timeout = 3600,
    [Parameter()] [string] $LogLevel = "INFO",
    [Parameter()] [string] $LogDirectory,
    [Parameter()] [string] $LogSQLInstance = "localhost\DBA01",
    [Parameter()] [string] $LogDatabase = "MSSQLBackupSolutionDB"
)

#############################################################################################
## LOGGING PREPARATION
#############################################################################################
Set-LoggingDefaultLevel -Level $LogLevel
$ProgressPreference = "SilentlyContinue"
Add-LoggingTarget -Name Console -Configuration @{
    ColorMapping = @{
        DEBUG = 'Gray'
        INFO  = 'White'
        ERROR  = 'DarkRed'
    };
    Level='DEBUG'
}

$TimestampLog=Get-Date -UFormat "%Y-%m-%d_%H%M%S"


#############################################################################################
## BACKUP PREPARATION : Get Instances in CMS to run BackupDatabasesOneInstance.ps1 script
#############################################################################################
$InstancesName=Get-DbaRegServer -SqlInstance $CMSSqlInstance -Group $Group | select -Unique Name
$CMSBackupStartTimeStamp = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"

Write-Log -Level DEBUG -Message "Starting backup of ${Group} group of the CMS ${CMSSqlInstance} at ${CMSBackupStartTimeStamp}"
$FailedInstance=@()

#############################################################################################
## BACKUP : run BackupDatabasesOneInstance.ps1 script for Each Instance found
#############################################################################################
$InstancesName |  ForEach-Object {
    $InstanceName=$_.Name
    Write-Log -Level DEBUG -Message "Starting backup of instance ${InstanceName}"
    .\BackupDatabasesOneInstance.ps1 -SqlInstance $InstanceName -BackupType $BackupType -FileCount $FileCount -BackupDirectory $BackupDirectory -LogDirectory $LogDirectory -LogSQLInstance $LogSQLInstance -LogDatabase $LogDatabase
    $RC=$LASTEXITCODE
    if($RC -ne 0){
        $FailedInstance+=$InstanceName
    }  
}

#############################################################################################
## LOG and EXITCODE
#############################################################################################
$CMSBackupEndTimeStamp = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
$tspan= New-TimeSpan -Start $CMSBackupStartTimeStamp -End $CMSBackupEndTimeStamp

$CMSBackupDuration=$tspan.Seconds

if($FailedInstance.count -eq 0){
    $NbFailedInstance=0
    Write-Log -Level DEBUG -Message "Backups of ${Group} group of the CMS ${CMSSqlInstance} finish successfully in ${CMSBackupDuration} seconds"
}
else{
    $NbFailedInstance=$FailedInstance.count    
    $FailedInstance | ForEach-Object {
      $NameOfInstanceFailed+=$_+" "
    }
    Write-Log -Level DEBUG -Message "Backups of ${Group} group of the CMS ${CMSSqlInstance} finish with errors in ${CMSBackupDuration} seconds. ${NbFailedInstance} Failed instance : ${NameOfInstanceFailed}"
}

Wait-Logging

Exit $NbFailedInstance

