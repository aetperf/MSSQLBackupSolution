 <#
    .SYNOPSIS
        Backup of all databases of the CMS to target Directory
    .DESCRIPTION
        Objective : Backup all databases (except tempdb) to a target Backup directory in parallel
        the script will create a .bak; .diff or .trn file depending of the backup type (full; diff, log)
        "${BackupDirectory}\servername\instancename\dbname\backuptype\servername_dbname_backuptype_timestamp.${BackupExtension}"
       
    .PARAMETER SqlInstance
        The SQL Server instance hosting the databases to be backed up.

    .PARAMETER BackupType
        The SQL Server backup type (Full, Diff, Log).

    .PARAMETER BackupDirectory
        Target root directory

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
            Install-Module JoinModule

        Compatibility : Powershell 7.3+

    .LINK
        
    .EXAMPLE
        PS C:\> .\BackupDatabasesOneInstance.ps1 -SqlInstance MySQLServerInstance -BackupType Diff -BackupDirectory "S:\BACKUPS" -FileCount 1 -LogDirectory "D:\scripts\logs"
        This will perform a differential backups of all databases of the MySQLServerInstance Instance in the S:\BACKUPS Directory and log will be console displayed as well as writen in a timestamped file in the D:\scripts\logs directory
    
        PS C:\> .\BackupDatabasesOneInstance.ps1 -SqlInstance MySQLServerInstance -BackupType Full -BackupDirectory "S:\BACKUPS" -FileCount 4
        This will perform a Full backups of all databases of the MySQLServerInstance Instance in the S:\BACKUPS Directory with backup files slitted into 4 parts and log will be console displayed

        PS C:\> D:\MSSQLBackupSolution\BackupDatabasesOneInstance.ps1 -SqlInstance $SqlInstance -BackupType $Backuptype -BackupDirectory $BackupDirectory

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
    [Parameter()] [string] $LogDirectory
)

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



$InstancesName=Get-DbaRegServer -SqlInstance $CMSSqlInstance -Group $Group | select -Unique Name
$CMSBackupStartTimeStamp = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"

Write-Log -Level DEBUG -Message "Starting backup of ${Group} group of the CMS ${CMSSqlInstance} at ${CMSBackupStartTimeStamp}"
$FailedInstance=@()
$InstancesName |  ForEach-Object {
    $InstanceName=$_.Name
    Write-Log -Level DEBUG -Message "Starting backup of instance ${InstanceName}"
    .\BackupDatabasesOneInstance.ps1 -SqlInstance $InstanceName -BackupType $BackupType -FileCount $FileCount -BackupDirectory $BackupDirectory -LogDirectory $LogDirectory 
    $RC=$LASTEXITCODE
    if($RC -ne 0){
        $FailedInstance+=$InstanceName
    }  
}

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

