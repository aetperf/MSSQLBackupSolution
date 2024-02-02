
param 
(
    [Parameter(Mandatory)] [string] $SqlInstanceCMS = "localhost\DBA01",
    [Parameter(Mandatory)] [string] $SourceSQLPath = ".\SQL",
    [Parameter(Mandatory)] [string] $serviceAccount,
    [Parameter()] [string] $LogDirectory = ".\Logs",
    [Parameter()] [string] $LogLevel = "INFO",
    [Parameter()] [bool] $Force = $false
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
        $SilentRes = mkdir $LogDirectory -Force
        $LogfileName="MSSQL_Create_SQL_Object_${TimestampLog}.log"
        $LogFile= Join-DbaPath -Path $LogDirectory -Child $LogfileName
        Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = $LogFile}
        Write-Log -Level INFO -Message "Log File : $LogFile"
    }
}

########################################################################################################################  
## CREATE DATABASE MSSQLSolutionDB
######################################################################################################################## 
Write-Log -Level INFO -Message "Create MSSQLSolutionDB Objects on ${SqlInstanceCMS}"

try {

    if ($Force -eq $true) {        
        Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database master -Query "DROP DATABASE IF EXISTS [MSSQLBackupSolutionDB];" -ErrorAction Stop -WarningAction SilentlyContinue
        Write-Log -Level INFO -Message "Drop of database MSSQLBackupSolutionDB : Successful"
        Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database master -Query "EXEC msdb.dbo.sp_delete_job @job_name=N'MSSQLBackupSolution-CMS-Backup-Full-ALL';" -ErrorAction Stop -WarningAction SilentlyContinue
        Write-Log -Level INFO -Message "Drop of job MSSQLBackupSolution-CMS-Backup-Full-ALL : Successful"
        Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database master -Query "EXEC msdb.dbo.sp_delete_job @job_name=N'MSSQLBackupSolution-CMS-Backup-Diff-ALL';" -ErrorAction Stop -WarningAction SilentlyContinue
        Write-Log -Level INFO -Message "Drop of job MSSQLBackupSolution-CMS-Backup-Diff-ALL : Successful"
        Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database master -Query "EXEC msdb.dbo.sp_delete_job @job_name=N'MSSQLBackupSolution-CMS-Backup-Log-ALL';" -ErrorAction Stop -WarningAction SilentlyContinue
        Write-Log -Level INFO -Message "Drop of job MSSQLBackupSolution-CMS-Backup-Log-ALL : Successful"
        Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database master -Query "EXEC msdb.dbo.sp_delete_job @job_name=N'MSSQLBackupSolution-Purge-BackupCentral';" -ErrorAction Stop -WarningAction SilentlyContinue
        Write-Log -Level INFO -Message "Drop of job MSSQLBackupSolution-Purge-BackupCentral : Successful"
        Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database master -Query "EXEC msdb.dbo.sp_delete_job @job_name=N'MSSQLBackupSolution-Purge-Remote-FromCMS';" -ErrorAction Stop -WarningAction SilentlyContinue
        Write-Log -Level INFO -Message "Drop of job MSSQLBackupSolution-Purge-Remote-FromCMS : Successful"
        Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database master -Query "EXEC msdb.dbo.sp_delete_proxy @proxy_name=N'Proxy_MSSQLBackup_Service';" -ErrorAction Stop -WarningAction SilentlyContinue
        Write-Log -Level INFO -Message "Drop of proxy Proxy_MSSQLBackup_Service : Successful"
        Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database master -Query "DROP CREDENTIAL [ServiceAccount_MSSQLBackups];" -ErrorAction Stop -WarningAction SilentlyContinue
        Write-Log -Level INFO -Message "Drop of credential ServiceAccount_MSSQLBackups : Successful"

        Write-Log -Level INFO -Message "Cleanup of MSSQLBackupSolutionDB objects : Successful"
                

    }

    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -File "$SourceSQLPath\Create_Database_MSSQLBackupSolutionDB.sql" -QueryTimeout 30 -ErrorAction Stop -WarningAction Stop
    Write-Log -Level INFO -Message "Creation of database MSSQLBackupSolutionDB : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Error during the creation of database MSSQLBackupSolutionDB"
    exit 1
}

########################################################################################################################  
## CREATE TABLE BackupResults
######################################################################################################################## 
Write-Log -Level INFO -Message "Create table BackupResults"

try {
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database "MSSQLBackupSolutionDB" -File "$SourceSQLPath\Create_Table_BackupResult.sql" -QueryTimeout 5 -ErrorAction Stop 
    Write-Log -Level INFO -Message "Creation of table BackupResults : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Error during the creation of table BackupResults"
    exit 1
}

########################################################################################################################  
## CREATE CREDENTIAL
######################################################################################################################## 
Write-Log -Level INFO -Message "Create Credential ServiceAccount_MSSQLBackups"

$Credential = Get-Credential -UserName $serviceAccount -Message "Enter the password for the service account ${serviceAccount}"

if ($Credential -eq $null) {
    Write-Log -Level ERROR -Message "Error on the credential of ${serviceAccount}"
    exit 1
}

try {
    $CurrentDomain=$Env:UserDomain
    $UserName = $Credential.UserName
    $identity="${CurrentDomain}\${UserName}"
    $securestring=$Credential.Password
    $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($securestring)
    $secret = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)

    $query="CREATE CREDENTIAL [ServiceAccount_MSSQLBackups] WITH IDENTITY = N'${identity}', SECRET = N'${secret}'" 
    Write-Log -Level INFO -Message "CREATE CREDENTIAL [ServiceAccount_MSSQLBackups] WITH IDENTITY = N'${identity}', SECRET = N'*********'"
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database master -Query $query -QueryTimeout 15 -ErrorAction Stop 
    Write-Log -Level INFO -Message "Creation of credential : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Error during the creation of credential : ServiceAccount_MSSQLBackups"
    exit 1
}

########################################################################################################################  
## CREATE PROXY
######################################################################################################################## 
Write-Log -Level INFO -Message "Create Proxy Proxy_MSSQLBackup_Service"

try {
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database msdb -File "$SourceSQLPath\Create_Proxy_Service_Account.sql" -ErrorAction Stop
    Write-Log -Level INFO -Message "Creation of proxy : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Error during the creation of proxy : Proxy_MSSQLBackup_Service"
    exit 1
}

########################################################################################################################  
## CREATE JOB BACKUP FULL
########################################################################################################################
Write-Log -Level INFO -Message "Create jobs Backup Full"

try {
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database msdb -File "$SourceSQLPath\Create_Jobs_BACKUP_FULL.sql" -ErrorAction Stop
    Write-Log -Level INFO -Message "Creation of jobs Backup Full : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Error during the creation of jobs : Backup Full"
    exit 1
}
########################################################################################################################  
## CREATE JOB BACKUP DIFF
########################################################################################################################
Write-Log -Level INFO -Message "Create jobs Backup Diff"

try {
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database msdb -File "$SourceSQLPath\Create_Jobs_BACKUP_DIFF.sql" -ErrorAction Stop
    Write-Log -Level INFO -Message "Creation of jobs Backup Diff : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Error during the creation of jobs : Backup Diff"
    exit 1
}
########################################################################################################################  
## CREATE JOB BACKUP LOG
########################################################################################################################
Write-Log -Level INFO -Message "Create jobs Backup Log"

try {
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database msdb -File "$SourceSQLPath\Create_Jobs_BACKUP_LOG.sql" -ErrorAction Stop
    Write-Log -Level INFO -Message "Creation of jobs Backup Log : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Error during the creation of jobs : Backup Log"
    exit 1
}
########################################################################################################################  
## CREATE JOB PURGE CENTRAL 
########################################################################################################################
Write-Log -Level INFO -Message "Create jobs Purge Central"

try {
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database msdb -File "$SourceSQLPath\Create_Jobs_PurgeCentral.sql" -ErrorAction Stop
    Write-Log -Level INFO -Message "Creation of jobs Purge Central : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Error during the creation of jobs : Purge Central"
    exit 1
}
########################################################################################################################  
## CREATE PROXY PURGE REMOTE 
########################################################################################################################
Write-Log -Level INFO -Message "Create jobs Purge Remote"

try {
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database msdb -File "$SourceSQLPath\Create_Jobs_PurgeRemote.sql" -ErrorAction Stop
    Write-Log -Level INFO -Message "Creation of jobs Purge Remote : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Error during the creation of jobs : Purge Remote"
    exit 1
}

exit 0


    

