param 
(
    [Parameter(Mandatory)] [string] $SqlInstanceCMS,
    [Parameter()] [string] $LogDirectory,
    [Parameter()] [string] $LogLevel = "INFO"
)

########################################################################################################################  
## LOGGING PREPARATION
########################################################################################################################  
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
        $LogfileName="MSSQL_Uninstall_${TimestampLog}.log"
        $LogFile= Join-DbaPath -Path $LogDirectory -Child $LogfileName
        Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = $LogFile}
        Write-Log -Level INFO -Message "Log File : $LogFile"
    }
}

########################################################################################################################  
## DROP JOBS
######################################################################################################################## 
Write-Log -Level INFO -Message "Starting suppress jobs"
try {
    Invoke-DbaQuery -SqlInstance  $SqlInstanceCMS -Database msdb -Query "EXEC msdb.dbo.sp_delete_job @job_name=N'MSSQLBackupSolution-CMS-Backup-Full-ALL', @delete_unused_schedule=1"
    Invoke-DbaQuery -SqlInstance  $SqlInstanceCMS -Database msdb -Query "EXEC msdb.dbo.sp_delete_job @job_name=N'MSSQLBackupSolution-CMS-Backup-Diff-ALL', @delete_unused_schedule=1"
    Invoke-DbaQuery -SqlInstance  $SqlInstanceCMS -Database msdb -Query "EXEC msdb.dbo.sp_delete_job @job_name=N'MSSQLBackupSolution-CMS-Backup-Log-ALL', @delete_unused_schedule=1"
    Invoke-DbaQuery -SqlInstance  $SqlInstanceCMS -Database msdb -Query "EXEC msdb.dbo.sp_delete_job @job_name=N'MSSQLBackupSolution-Purge-BackupCentral', @delete_unused_schedule=1"
    Invoke-DbaQuery -SqlInstance  $SqlInstanceCMS -Database msdb -Query "EXEC msdb.dbo.sp_delete_job @job_name=N'MSSQLBackupSolution-Purge-Remote-FromCMS', @delete_unused_schedule=1"
    Write-Log -Level INFO -Message "Suppress jobs : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Suppress jobs : Failed"
    exit 1
}

########################################################################################################################  
## DROP PROXY
########################################################################################################################
Write-Log -Level INFO -Message "Starting suppress proxy"
try {
    Invoke-DbaQuery -SqlInstance  $SqlInstanceCMS -Database msdb -Query "EXEC msdb.dbo.sp_delete_proxy @proxy_name=N'Proxy_MSSQLBackup_Service'"
    Write-Log -Level INFO -Message "Suppress proxy : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Suppress proxy : Failed"
    exit 1
}

########################################################################################################################  
## DROP CREDENTIAL
########################################################################################################################
Write-Log -Level INFO -Message "Starting suppress credential"
try {
    Invoke-DbaQuery -SqlInstance  $SqlInstanceCMS -Database master -Query "DROP CREDENTIAL [ServiceAccount_MSSQLBackups]"
    Write-Log -Level INFO -Message "Suppress credential : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Suppress credential : Failed"
    exit 1
}

########################################################################################################################  
## DROP TABLE
########################################################################################################################
Write-Log -Level INFO -Message "Starting suppress table"
try {
    Invoke-DbaQuery -SqlInstance  $SqlInstanceCMS -Database MSSQLBackupSolutionDB -Query "DROP TABLE [dbo].[BackupResults]"
    Write-Log -Level INFO -Message "Suppress table : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Suppress table : Failed"
    exit 1
}

########################################################################################################################  
## DROP DATABASE
########################################################################################################################
Write-Log -Level INFO -Message "Starting suppress database"
try {
    Invoke-DbaQuery -SqlInstance  $SqlInstanceCMS -Database master -Query "ALTER DATABASE [MSSQLBackupSolutionDB] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE;DROP DATABASE [MSSQLBackupSolutionDB];"
    Write-Log -Level INFO -Message "Suppress database : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Suppress database : Failed"
    exit 1
}
