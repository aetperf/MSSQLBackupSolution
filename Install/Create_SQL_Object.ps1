
param 
(
    #[Parameter(Mandatory)] [string] $Login,
    #[Parameter(Mandatory)] [string] $Password,
    [Parameter(Mandatory)] [string] $SqlInstanceCMS,
    [Parameter(Mandatory)] [string] $SourceSQLPath,
    #[Parameter(Mandatory)] [PSCredential] $Credential,
    [Parameter()] [string] $LogDirectory,
    [Parameter()] [string] $LogLevel = "INFO"
)

$User = "DESKTOP-I7IQL69\romain"
$PWord = ConvertTo-SecureString -String "P@sSwOrd" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord

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
        $LogfileName="MSSQL_Create_SQL_Object_${TimestampLog}.log"
        $LogFile= Join-DbaPath -Path $LogDirectory -Child $LogfileName
        Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = $LogFile}
        Write-Log -Level INFO -Message "Log File : $LogFile"
    }
}

########################################################################################################################  
## CREATE DATABASE MSSQLSolutionDB
######################################################################################################################## 
Write-Log -Level INFO -Message "Create Database MSSQLSolutionDB"

try {
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -File "$SourceSQLPath\Create_Database_MSSQLSolutionDB.sql"
    Write-Log -Level INFO -Message "Creation of database MSSQLSolutionDB : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Error during the creation of database MSSQLSolutionDB"
    exit 1
}

########################################################################################################################  
## CREATE TABLE BackupResults
######################################################################################################################## 
Write-Log -Level INFO -Message "Create table BackupResults"

try {
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -File "$SourceSQLPath\Create_Table_BackupResult.sql" 
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

try {
    $identity=$Credential.UserName
    $securestring=$Credential.Password
    $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($securestring)
    $secret = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)

    $query="CREATE CREDENTIAL [ServiceAccount_MSSQLBackups] WITH IDENTITY = N'$identity', SECRET = N'$secret'" 
    Write-Log -Level INFO -Message "CREATE CREDENTIAL [ServiceAccount_MSSQLBackups] WITH IDENTITY = N'$identity', SECRET = N'*********'"
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database master -Query $query
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
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database msdb -File "$SourceSQLPath\Create_Proxy_Service_Account.sql"
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
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database msdb -File "$SourceSQLPath\Create_Jobs_BACKUP_FULL.sql"
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
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database msdb -File "$SourceSQLPath\Create_Jobs_BACKUP_DIFF.sql"
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
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database msdb -File "$SourceSQLPath\Create_Jobs_BACKUP_LOG.sql"
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
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database msdb -File "$SourceSQLPath\Create_Jobs_PurgeCentral.sql"
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
    Invoke-DbaQuery -SqlInstance $SqlInstanceCMS -Database msdb -File "$SourceSQLPath\Create_Jobs_PurgeRemote.sql"
    Write-Log -Level INFO -Message "Creation of jobs Purge Remote : Successful"
}
catch {
    Write-Log -Level ERROR -Message "Error during the creation of jobs : Purge Remote"
    exit 1
}


    

