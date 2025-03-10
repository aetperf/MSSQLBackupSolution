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

    .PARAMETER ExecDirectory
        Execution directory (should be the directory of the script itselft)

    .PARAMETER HoursDelay
        Number of hours to elect files for purging. All files older than HoursDelay hours will be deleted
        Default 168 : 7*24
        
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
        PurgeFilesFromCMS.ps1 -FileType "Log" -CMSSqlInstance "localhost\DBA01" -Group "All" -RemoteBackupDirectory "G$\BACKUPDB" -ExecDirectory "D:\MSSQLBackupSolution" -LogDirectory "D:\MSSQLBackupSolution\Logs" -HoursDelay 168
    .EXAMPLE    
        PurgeFilesFromCMS.ps1 -FileType "Full" -CMSSqlInstance "localhost\DBA01" -Group "All" -RemoteBackupDirectory "G$\BACKUPDB" -ExecDirectory "D:\MSSQLBackupSolution" -LogDirectory "D:\MSSQLBackupSolution\Logs" -HoursDelay 168

    #>

    param 
    (    
        [Parameter(Mandatory)] [ValidateSet('Full','Diff','Log','ShellLog')] [string] $FileType,
        [Parameter(Mandatory)] [string] $RemoteBackupDirectory,
        [Parameter(Mandatory)] [string] $CMSSqlInstance,
        [Parameter(Mandatory)] [string] $ExecDirectory,
        [Parameter()] [string] $Group = "All",    
        [Parameter()] [int] $HoursDelay=168, #24*7
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
            $LogfileName="MSSQLBackupSolution_PurgeFromCMS_${TimestampLog}.log"
            $LogFile= Join-DbaPath -Path $LogDirectory -Child $LogfileName
            Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = $LogFile}
            Write-Log -Level INFO -Message "Log File : $LogFile"
        }
    }
    
    
    #############################################################################################
    ## Purge PREPARATION : Get Instances in CMS to run PurgeFiles.ps1 for each Instance
    #############################################################################################
    $ServersName=Get-DbaRegServer -SqlInstance $CMSSqlInstance -Group $Group | select -Unique ServerName
    
    $CMSPurgeStartTimeStamp = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
    
    Write-Log -Level INFO -Message "Starting Purge ${FileType} files for the ""${Group}"" group of the CMS ${CMSSqlInstance}"
    
    #############################################################################################
    ## Purge : run PurgeFiles.ps1 Each Instance found
    #############################################################################################
    $FailedPurge=@()
    $NbFailedPurge=0
    $ServersName |  ForEach-Object {
        $ComputerName=$_.ServerName
        
        $SourceRemoteDir = "\\${ComputerName}\${RemoteBackupDirectory}"
        Write-Log -Level INFO -Message "Starting Purging ${FileType} files on Computer ${ComputerName} from ${SourceRemoteDir} older than ${HoursDelay} hours"
        cd $ExecDirectory
        try {
            .\PurgeFiles.ps1 -FileType $FileType -RootDirectory $SourceRemoteDir -LogDirectory $LogDirectory -HoursDelay $HoursDelay 
            $RC=$LASTEXITCODE   
            if($RC -gt 0){
                $FailedPurge+=$ComputerName
                Write-Log -Level ERROR -Message "Failed Purging ${FileType} files on Computer ${ComputerName} from ${SourceRemoteDir} older than ${HoursDelay} hours"
                $NbFailedPurge++
            }      
        }
        catch {
            $FailedPurge+=$ComputerName
            Write-Log -Level ERROR -Message "Failed Purging ${FileType} files on Computer ${ComputerName} from ${SourceRemoteDir} older than ${HoursDelay} hours"
            $NbFailedPurge++
        }
        
        
         
        Wait-Logging
    }
    
    #############################################################################################
    ## LOG and EXITCODE
    #############################################################################################
    $CMSPurgeEndTimeStamp = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
    $tspan= New-TimeSpan -Start $CMSPurgeStartTimeStamp -End $CMSPurgeEndTimeStamp
    
    $CMSPurgeDuration=$tspan.TotalSeconds
    
    
    Wait-Logging
    
    $ExitCode=0
    if ($NbFailedPurge -gt 0)
    {$ExitCode=1}
    
    Exit $ExitCode
    
    