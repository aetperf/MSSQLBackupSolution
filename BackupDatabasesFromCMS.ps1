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

    .PARAMETER FullBackupInterval
        Specifies the number of days after the last full backup before triggering a new full backup if we do a backup Diff or Log. If the time elapsed since the last full backup exceeds this interval, a new full backup will be initiated. (Default : 15 days)
        
    .PARAMETER LogDirectory
        Directory where a log file can be stored (Optionnal)

    .PARAMETER LogSQLInstance
        SQL Server instance hosting the log database (Optionnal) default : localhost\DBA01

    .PARAMETER LogDatabase
        Log database name (Optionnal) default : MSSQLBackupSolutionDB

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
    [Parameter(Mandatory)] [string] $ExecDirectory,
    [Parameter()] [Int16] $FileCount = 1,
    [Parameter()] [Int16] $FullBackupInterval = 15,
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

try {
    $InstancesName=Get-DbaRegServer -SqlInstance $CMSSqlInstance -Group $Group -EnableException -WarningVariable warningVariable | Select-Object -Unique Name
    $CMSBackupStartTimeStamp = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"

    Write-Log -Level DEBUG -Message "Starting backup of ${Group} group of the CMS ${CMSSqlInstance} at ${CMSBackupStartTimeStamp}"
    $FailedInstance=@()
}
catch {
    Write-Log -Level ERROR -Message "Impossible to connect to CMS instance : ${SqlInstance}"
    $WarningVariable.Message | ForEach-Object{
        Write-Log -Level ERROR -Message $_
    }
    
    Exit 1
}


#############################################################################################
## BACKUP : run BackupDatabasesOneInstance.ps1 script for Each Instance found
#############################################################################################
$InstancesName |  ForEach-Object {
    $InstanceName=$_.Name
    Write-Log -Level DEBUG -Message "Starting backup of instance ${InstanceName}"
    cd $ExecDirectory
    .\BackupDatabasesOneInstance.ps1 -SqlInstance $InstanceName -BackupType $BackupType -FileCount $FileCount -FullBackupInterval $FullBackupInterval -BackupDirectory $BackupDirectory -LogDirectory $LogDirectory -LogSQLInstance $LogSQLInstance -LogDatabase $LogDatabase
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

$CMSBackupDuration=$tspan.TotalSeconds

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

$Exitcode=0
If ($NbFailedInstance -gt 0)
{$Exitcode=1}

Exit $ExitCode

