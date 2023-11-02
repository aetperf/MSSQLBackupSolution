<#
    .SYNOPSIS
        Purge of the backup files or logs file
    .DESCRIPTION
        

    .PARAMETER FileType
        The file type (Full, Diff, Tran, Log). Will determine the extensions of files

    .PARAMETER RootDirectory
        Target root directory. The directory that will be to root for recursion
    
    .PARAMETER HoursDelay
        Will delete files older than HoursDelay hours
        
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

        Compatibility : Powershell 5+

    .LINK
        
    .EXAMPLE
        PS C:\> PurgeFiles.ps1 -FileType "Full" -RootDirectory "D:\MSSQLBackupsCentral" -LogDirectory "D:\MSSQLBackupSolution\Logs" -HoursDelay 168
    .EXAMPLE   
        PS C:\> PurgeFiles.ps1 -FileType "Diff" -RootDirectory "D:\MSSQLBackupsCentral" -LogDirectory "D:\MSSQLBackupSolution\Logs" -HoursDelay 168
    .EXAMPLE    
        PS C:\> PurgeFiles.ps1 -FileType "Trn" -RootDirectory "D:\MSSQLBackupsCentral" -LogDirectory "D:\MSSQLBackupSolution\Logs" -HoursDelay 168
    .EXAMPLE    
        PS C:\> PurgeFiles.ps1 -FileType "Log" -RootDirectory "D:\MSSQLBackupSolution\Logs" -LogDirectory "D:\MSSQLBackupSolution\Logs" -HoursDelay 168


    #>

param 
(
    [Parameter(Mandatory)] [ValidateSet('Full','Diff','Tran','Log')] [string] $FileType,
    [Parameter()] [string] $RootDirectory,
    [Parameter()] [string] $LogDirectory,
    [Parameter()] [int] $HoursDelay=168, #24*7
    [Parameter()] [string] $LogLevel = "INFO"
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

if ($PSBoundParameters.ContainsKey('LogDirectory'))
{   
    if ($LogDirectory -ne "")
    {
        try{
            $TimestampLog=Get-Date -UFormat "%Y-%m-%d"
            if (-not(Test-Path $LogDirectory)) {mkdir $LogDirectory -Force}
            $LogfileName="Purge_${FileType}_${TimestampLog}.log"
            $LogFile= Join-DbaPath -Path $LogDirectory -Child $LogfileName
            Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = $LogFile}
            Write-Log -Level INFO -Message "Log File : $LogFile"
        }
        catch{
            Write-Log -Level ERROR -Message "Failed to initialize log file in ${LogDirectory}"
            Exit 1
        }
    }
}


$PurgeStartTimeStamp=Get-Date

Write-Log -Level INFO -Message "Parameter FileType : ${FileType}"
Write-Log -Level INFO -Message "Parameter RootDirectory : ${RootDirectory}"
Write-Log -Level INFO -Message "Parameter HoursDelay : ${HoursDelay}"


#############################################################################################
## PURGE PREPARATION : Get the extension file
#############################################################################################


    
switch ( $FileType ) 
    {
        "Full" 
            {
                $FileExtension="bak"  
            }
        "Diff" 
            {
                $FileExtension="bak" 
            }
        "Tran"  
            {
                $FileExtension="trn"  
            } 
        "Log"  
            {
                $FileExtension="log"  
            }    
    }

Write-Log -Level INFO -Message "File Extension : .${FileExtension}"

#############################################################################################
## PURGE
#############################################################################################

$ExitCode=0

if (-not(Test-Path $RootDirectory)) {
       Write-Log -Level ERROR -Message "Failed ${RootDirectory} directory does not exist" 
    Exit 1   
}

try {
    $TimeDelay = (Get-Date).AddHours(-$HoursDelay)
    $resulttmp=Get-ChildItem -Path $RootDirectory -Recurse -Include *.$FileExtension -Exclude $LogfileName 
    $result= $resulttmp | Where-Object { $_.LastWriteTime -lt $TimeDelay } 
    $NbFiles=$result.Count
    Write-Log -Level INFO -Message "Found ${NbFiles} files to delete"
}
catch
{
    Write-Log -Level ERROR -Message "Problem when trying to list ${FileExtension} files on ${RootDirectory}" 
    $ExitCode=1
}

if ($ExitCode -eq 0)
{
    try {
        $result | ForEach-Object {
            $fileName=$_.FullName
            Write-Log -Level INFO -Message "Starting the delete of ${fileName}"
            Remove-Item -Path $_.FullName -WhatIf
        }
        
    }
    catch {    
        Write-Log -Level ERROR -Message "Problem when trying to remove ${fileName}"
        $ExitCode=1
    }
}



#############################################################################################
## Finish wih Compute ExitCode : Exit with non zero if purge failed
#############################################################################################

$PurgeEndTimeStamp=Get-Date
$tspan= New-TimeSpan -Start $PurgeStartTimeStamp -End $PurgeEndTimeStamp
$PurgeDuration=$tspan.TotalSeconds

if($ExitCode -eq 0){
    Write-Log -Level INFO -Message "Purge of .${FileExtension} files in ${RootDirectory} : Successful purge of ${NbFiles} files in ${PurgeDuration} seconds"
}
else{
    Write-Log -Level ERROR -Message "Purge of .${FileExtension} files  in ${RootDirectory} : Failed in ${PurgeDuration} seconds"
}

Wait-Logging

Exit $ExitCode
