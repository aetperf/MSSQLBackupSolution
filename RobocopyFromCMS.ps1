<#
    .SYNOPSIS
        Robocopy all backups files from all mssql instances defined in a CMS to a central backup directory
    .DESCRIPTION
        Objective : Robocopy all backups files from all mssql instances defined in a CMS to a central backup directory
       
    .PARAMETER CMSSqlInstance
        The SQL Server instance hosting the CMS database to list instances to backup.

    .PARAMETER Group
        The root group in the CMS where SQLInstances to backup will be listed.

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
    .EXAMPLE    
        PS C:\> RobocopyFromCMS.ps1 -CMSSqlInstance "localhost\DBA01" -Group "All" -CentralBackupDirectory "D:\MSSQLBackupsCentral" -RemoteBackupDirectory "G$\BACKUPDB"  -LogDirectory "D:\MSSQLBackupSolution\Logs"

    #>

param 
(
    [Parameter(Mandatory)] [string] $CentralBackupDirectory,
    [Parameter(Mandatory)] [string] $RemoteBackupDirectory,
    [Parameter(Mandatory)] [string] $CMSSqlInstance,
    [Parameter(Mandatory)] [string] $ExecDirectory,
    [Parameter()] [string] $Group = "All",
    [Parameter()] [Int16] $Timeout = 3600,
    [Parameter()] [string] $LogLevel = "INFO",
    [Parameter()] [string] $LogDirectory
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
        $TimestampLog=Get-Date -UFormat "%Y-%m-%d"
        mkdir $LogDirectory -Force
        $LogfileName="MSSQLBackupSolution_Robocopy_${TimestampLog}.log"
        $LogFile= Join-DbaPath -Path $LogDirectory -Child $LogfileName
        Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = $LogFile}
        Write-Log -Level INFO -Message "Log File : $LogFile"
    }
}


cd $ExecDirectory
import-module .\Start-ConsoleProcess.ps1 -Force
import-module .\Invoke-Robocopy.ps1 -Force

#############################################################################################
## ROBOCOPY PREPARATION : Get Instances in CMS to run Invoke-Robocopy for each Instance
#############################################################################################
$ServersName=Get-DbaRegServer -SqlInstance $CMSSqlInstance -Group $Group | select -Unique ServerName

$CMSRobocopyStartTimeStamp = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"

Write-Log -Level INFO -Message "Starting Robocopy of ${Group} group of the CMS ${CMSSqlInstance} at ${CMSRobocopyStartTimeStamp}"

#############################################################################################
## Robocopy : run Invoke-Robocopy for Each Instance found
#############################################################################################
$FailedRobocopy=@()
$ServersName |  ForEach-Object {
    $ComputerName=$_.ServerName
    
    $SourceRemoteDir = "\\${ComputerName}\${RemoteBackupDirectory}"
    Write-Log -Level INFO -Message "Starting Robocopy of Computer ${ComputerName} from ${SourceRemoteDir} to ${CentralBackupDirectory}"
    Invoke-Robocopy -Source $SourceRemoteDir -Destination $CentralBackupDirectory -ArgumentList @('/e', '/np', '/ndl', '/nfl' ) -Verbose
    $RC=$LASTEXITCODE
    
    if($RC -gt 4){
        $FailedRobocopy+=$ComputerName
    }  
}

#############################################################################################
## LOG and EXITCODE
#############################################################################################
$CMSRobocopyEndTimeStamp = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
$tspan= New-TimeSpan -Start $CMSRobocopyStartTimeStamp -End $CMSRobocopyEndTimeStamp

$CMSRobocopyDuration=$tspan.TotalSeconds



if($FailedRobocopy.count -eq 0){
    $NbFailedRobocopy=0
    Write-Log -Level INFO -Message "Robocopy of ${Group} group of the CMS ${CMSSqlInstance} finish successfully in ${CMSRobocopyDuration} seconds"
}
else{
    $NbFailedRobocopy=$FailedRobocopy.count    
    $FailedRobocopy | ForEach-Object {
      $NameOfRobocopyFailed+=$_+" "
    }
    Write-Log -Level ERROR -Message "Robocopy of ${Group} group of the CMS ${CMSSqlInstance} finish with errors in ${CMSRobocopyDuration} seconds. ${NbFailedRobocopy} Failed server : ${NameOfRobocopyFailed}"
}

Wait-Logging

$ExitCode=0
if ($NbFailedRobocopy -gt 0)
{$ExitCode=1}

Exit $ExitCode

