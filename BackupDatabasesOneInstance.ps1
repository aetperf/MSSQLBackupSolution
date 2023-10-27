 <#
    .SYNOPSIS
        Backup of all databases of a single SQL Server SqlInstance to target Directory
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

        Compatibility : Powershell 5+

    .LINK
        
    .EXAMPLE
        PS C:\> $ProgressPreference = "SilentlyContinue"
        PS C:\> .\BackupDatabasesOneInstance.ps1 -SqlInstance MySQLServerInstance -BackupType Diff -BackupDirectory "S:\BACKUPS" -FileCount 1 -LogDirectory "D:\scripts\logs"
        This will perform a differential backups of all databases of the MySQLServerInstance Instance in the S:\BACKUPS Directory and log will be console displayed as well as writen in a timestamped file in the D:\scripts\logs directory
    .EXAMPLE
        PS C:\> .\BackupDatabasesOneInstance.ps1 -SqlInstance MySQLServerInstance -BackupType Full -BackupDirectory "S:\BACKUPS" -FileCount 4
        This will perform a Full backups of all databases of the MySQLServerInstance Instance in the S:\BACKUPS Directory with backup files slitted into 4 parts and log will be console displayed
    .EXAMPLE
        PS C:\> D:\MSSQLBackupSolution\BackupDatabasesOneInstance.ps1 -SqlInstance $SqlInstance -BackupType $Backuptype -BackupDirectory $BackupDirectory

    #>



param 
(
    [Parameter(Mandatory)] [string] $SqlInstance,
    [Parameter(Mandatory)] [ValidateSet('Full','Diff','Log')] [string] $BackupType,
    [Parameter(Mandatory)] [string] $BackupDirectory,
    [Parameter()] [Int16] $FileCount = 1,
    [Parameter()] [string] $LogLevel = "INFO",
    [Parameter()] [string] $LogDirectory,
    [Parameter()] [string] $logSQLInstance = "localhost\DBA01",
    [Parameter()] [string] $logDatabase = "MSSQLBackupSolutionDB"
)

#############################################################################################
## LOGGING PREPARATION
#############################################################################################
Set-LoggingDefaultLevel -Level $LogLevel
Add-LoggingTarget -Name Console -Configuration @{
    ColorMapping = @{
        DEBUG = 'Gray'
        INFO  = 'White'
        ERROR  = 'DarkRed'
    };
    Level='DEBUG'
}


if ($PSBoundParameters.ContainsKey('LogDirectory'))
{   
    if ($LogDirectory -ne "")
    {
        $TimestampLog=Get-Date -UFormat "%Y-%m-%d_%H%M%S"
        mkdir $LogDirectory -Force
        $InstanceCleanedName=$SqlInstance -replace '[\W]','_'
        $InstanceLogDir = Join-DbaPath -Path $LogDirectory -Child $InstanceCleanedName    
        mkdir $InstanceLogDir -Force
        $LogfileName="MSSQLBackupSolution_${InstanceCleanedName}_${BackupType}_${TimestampLog}.log"
        $LogFile= Join-DbaPath -Path $InstanceLogDir -Child $LogfileName
        Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = $LogFile}
        Write-Log -Level INFO -Message "Log File : $LogFile"
    }
}



$InstanceBackupStartTimeStamp=Get-Date

Write-Log -Level INFO -Message "Parameter SQLInstance : ${SqlInstance}"
Write-Log -Level INFO -Message "Parameter BackupType : ${BackupType}"
Write-Log -Level INFO -Message "Parameter BackupDirectory : ${BackupDirectory}"
Write-Log -Level INFO -Message "Parameter FileCount : ${FileCount}"

$ExitCode=0

#############################################################################################
## BACKUP PREPARATION : Get Databases to Backup
#############################################################################################

try{
    switch ( $BackupType ) 
        {
            "Full" 
                {
                    $BackupExtension="bak"  
                    $Databases = Get-DbaDatabase -SqlInstance $SqlInstance -ExcludeDatabase "tempdb","model" -EnableException -WarningVariable WarningVariable  | Where-Object {($_.IsUpdateable) -and ($_.Status -ilike "Normal*")}
                }
            "Diff" 
                {
                    $BackupExtension="bak" 
                    $Databases = Get-DbaDatabase -SqlInstance $SqlInstance -ExcludeDatabase "tempdb","model","master" -EnableException -WarningVariable WarningVariable | Where-Object {($_.IsUpdateable) -and ($_.Status -ilike "Normal*")}
                }
            "Log"  
                {
                    $BackupExtension="trn"  
                    $Databases = Get-DbaDatabase -SqlInstance $SqlInstance -ExcludeDatabase "tempdb","model" -EnableException -WarningVariable WarningVariable | Where-Object { ($_.IsUpdateable) -and ($_.Status -ilike "Normal*") -and ($_.RecoveryModel -ne "Simple")}
                }    
        }
    
}
catch
{
    $ErrorMessage = $WarningVariable.Message
    Write-Log -Level ERROR -Message "Impossible to Connect to Target Instance ${SqlInstance}. Error : ${ErrorMessage} "
    Exit 99
}

Write-Log -Level INFO -Message "Backup Extension : ${BackupExtension}"

#############################################################################################
## BACKUP
#############################################################################################

$Databases |  ForEach-Object {
    $DatabaseBackupStartTimeStamp = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
    $DatabaseName=$_.Name
    $InstanceName=$_.InstanceName
    $ComputerName=$_.ComputerName
    $FullUserName="${Env:UserDomain}\${Env:UserName}"

    try{
        ### BACKUP using dbatools
        $SilentRes=Backup-DbaDatabase -SqlInstance $SqlInstance -Database $DatabaseName -Type $BackupType -CompressBackup -Checksum -Verify -FileCount $FileCount -Path "${BackupDirectory}\servername\instancename\dbname\backuptype" -FilePath "servername_dbname_backuptype_timestamp.${BackupExtension}" -TimeStampFormat "yyyyMMdd_HHmm" -ReplaceInName -CreateFolder -WarningVariable WarningVariable -OutVariable BackupResults -EnableException
        
        $BackupDuration = $BackupResults.Duration
        $BackupCompressedSize = $BackupResults.CompressedBackupSize
        Write-DbaDbTableData -SqlInstance $logSQLInstance -Database $logDatabase -InputObject $BackupResults -Table dbo.BackupResults -AutoCreateTable -UseDynamicStringLength
        $SuccessfulMessage = "Backup ${BackupType} of ${SqlInstance} - Database : ${DatabaseName} : Successful in ${BackupDuration} and ${BackupCompressedSize}"
        Write-Log -Level INFO -Message $SuccessfulMessage
    }
    catch{
        $ExitCode=1
        $DatabaseBackupEndTimeStamp=Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
        $ErrorMessage="Backup ${BackupType} of ${ComputerName}\${InstanceName}.${DatabaseName} : Failed"
        Write-Log -Level ERROR -Message $ErrorMessage
        # get all error messages in case of multiple warning/error messages
        if ($WarningVariable)
                 {  
                    $ErrorMessage = ""
                    foreach ($warning in $WarningVariable) {
                        $ErrorMessage += $warning.Message
                        $dbatoolsmessage = $warning.Message
                        Write-Log -Level ERROR -Message $dbatoolsmessage                        
                    }
                 }

        $Message= "InstanceName : ${SqlInstance} | Database : ${DatabaseName} | Type : ${BackupType} | Error Message : ${ErrorMessage}"

        $InsertQuery="INSERT INTO [dbo].[BackupResults] ([BackupComplete] ,[BackupFile] ,[BackupFilesCount] ,[BackupFolder] ,[BackupPath] ,[DatabaseName] ,[Notes] ,[Script] ,[Verified] ,[ComputerName] ,[InstanceName] ,[SqlInstance] ,[AvailabilityGroupName] ,[Database] ,[DatabaseId] ,[UserName] ,[Start] ,[End] ,[Duration] ,[Path] ,[TotalSize] ,[CompressedBackupSize] ,[CompressionRatio] ,[Type] ,[BackupSetId] ,[DeviceType] ,[Software] ,[FullName] ,[FileList] ,[Position] ,[FirstLsn] ,[DatabaseBackupLsn] ,[CheckpointLsn] ,[LastLsn] ,[SoftwareVersionMajor] ,[IsCopyOnly] ,[RecoveryModel] ,[KeyAlgorithm] ,[EncryptorThumbprint] ,[EncryptorType] ,[Message]) VALUES (@BackupComplete ,@BackupFile ,@BackupFilesCount ,@BackupFolder ,@BackupPath ,@DatabaseName ,@Notes ,@Script ,@Verified ,@ComputerName ,@InstanceName ,@SqlInstance ,@AvailabilityGroupName ,@Database ,@DatabaseId ,@UserName ,@Start ,@End ,@Duration ,@Path ,@TotalSize ,@CompressedBackupSize ,@CompressionRatio ,@Type ,@BackupSetId ,@DeviceType ,@Software ,@FullName ,@FileList ,@Position ,@FirstLsn ,@DatabaseBackupLsn ,@CheckpointLsn ,@LastLsn ,@SoftwareVersionMajor ,@IsCopyOnly ,@RecoveryModel ,@KeyAlgorithm ,@EncryptorThumbprint ,@EncryptorType ,@Message)"


        $BackupResults=@{
            BackupComplete=0 
            BackupFile="" 
            BackupFilesCount="${FileCount}" 
            BackupFolder="${BackupDirectory}" 
            BackupPath="" 
            DatabaseName="${DatabaseName}" 
            Notes="" 
            Script="" 
            Verified="" 
            ComputerName="${ComputerName}" 
            InstanceName="${InstanceName}" 
            SqlInstance="${SqlInstance}" 
            AvailabilityGroupName="" 
            Database="${DatabaseName}" 
            DatabaseId="" 
            UserName="${FullUserName}" 
            Start="${DatabaseBackupStartTimeStamp}" 
            End="${DatabaseBackupEndTimeStamp}" 
            Duration="" 
            Path="" 
            TotalSize="" 
            CompressedBackupSize="" 
            CompressionRatio="" 
            Type="${BackupType}" 
            BackupSetId="" 
            DeviceType="" 
            Software="Microsoft SQL Server" 
            FullName="" 
            FileList="" 
            Position="" 
            FirstLsn="" 
            DatabaseBackupLsn="" 
            CheckpointLsn="" 
            LastLsn="" 
            SoftwareVersionMajor="" 
            IsCopyOnly="" 
            LastRecoveryForkGUID="" 
            RecoveryModel="" 
            KeyAlgorithm="" 
            EncryptorThumbprint="" 
            EncryptorType="" 
            Message="${Message}" 
        }

        #Log Error in LogDatabase
        Invoke-DbaQuery -SqlInstance $logSQLInstance -Database $logDatabase -Query $InsertQuery -SqlParameter $BackupResults
    }

}

#############################################################################################
## Finish wih Compute ExitCode : Exit with non zero if any database backup failed
#############################################################################################

Start-Sleep -Seconds 1 

$InstanceBackupEndTimeStamp=Get-Date
$tspan= New-TimeSpan -Start $InstanceBackupStartTimeStamp -End $InstanceBackupEndTimeStamp
$InstanceBackupDuration=$tspan.Seconds

if($ExitCode -eq 0){
    Write-Log -Level INFO -Message "Backup ${BackupType} of databases on ${SqlInstance} : Successful in ${InstanceBackupDuration} seconds"
}
else{
    Write-Log -Level ERROR -Message "Backup ${BackupType} of databases on ${SqlInstance} : Failed in ${InstanceBackupDuration} seconds"
}

Wait-Logging

Exit $ExitCode


 
