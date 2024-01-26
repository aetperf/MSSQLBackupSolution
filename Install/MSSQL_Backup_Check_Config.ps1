 <#
    .SYNOPSIS
        Check the requirements for the installation of MSSQL_BackupSolution
    .DESCRIPTION
        Objectives : 
        Check the internet access of the central server.
        Check if module Logging is installed.
        Check if module Dbatools is installed.
        Check if the service account for the backup is created 
        Check if the service account has the permission on target instances.
       
    .PARAMETER serviceAccount
        The name of the service account.

    .PARAMETER configFilePath
        The path of the configuration file who contains servers and instances names.
    
    .PARAMETER LogDirectory
        Directory where a log file can be stored (Optionnal)

    .NOTES
        Tags: DisasterRecovery, Backup, Restore
        Author: Romain Ferraton, Pierre-Antoine Collet
        Website: 
        Copyright: (c) 2022 by Romain Ferraton, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT
        Version: 1.0.0         

        Compatibility : Powershell 5+

    .LINK
        
    .EXAMPLE
        PS C:\> .\MSSQL_Backup_Check_Config.ps1 -serviceAccount "SVC_SQLBackup" -configFilePath "C:\MSSQL_Backup\MSSQL_BackupSolution.config" -LogDirectory "C:\MSSQL_Backup\Logs"
        
    #>

param 
(
    [Parameter(Mandatory)] [string] $serviceAccount,
    [Parameter(Mandatory)] [string] $configFilePath,
    [Parameter()] [string] $LogDirectory,
    [Parameter()] [string] $LogLevel = "INFO"
    
)

########################################################################################################################  
## BEGIN INTERNET ACCESS CHECK : check internet access 
########################################################################################################################  
Write-Host "Internet Access Check"
$internetAccess = Test-Connection -ComputerName "www.google.com" -Count 2 -Quiet
if ($internetAccess) {
    Write-Host "You have Internet Access" -ForegroundColor Green
} else {
    Write-Host "You don't have Internet Access" -ForegroundColor Red
    Exit 1
}

########################################################################################################################  
## BEGIN MODULES CHECK : check module Logging and DBATOOLS
######################################################################################################################## 
Write-Host "Module Check" 

$installedModuleLogging = Get-InstalledModule -Name "Logging" -ErrorAction SilentlyContinue
if ($installedModuleLogging -eq $null) {
    Write-Host "Module Logging not installed"
    $reponse = Read-Host "Do you want to install it (Y/N) "
    if($reponse -eq "Y"){
        Install-Module Logging -Scope AllUsers -Force 
        Import-Module Logging -Scope SystemDefault
    }
    else{
        exit 1
    }
} else {
    Import-Module Logging -Scope SystemDefault
    Write-Host "Module Logging already installed"
}

$installedModuleDbatools = Get-InstalledModule -Name "Dbatools" -ErrorAction SilentlyContinue
if ($installedModuleDbatools -eq $null) {
    Write-Host "Module Dbatools not installed"
    $reponse = Read-Host "Do you want to install it (Y/N) "
    if($reponse -eq "Y"){
        Install-Module dbatools -Scope AllUsers -Force
        Set-DbatoolsInsecureConnection -Scope SystemDefault
    }
    else{
        exit 1
    }
} else {
    Set-DbatoolsInsecureConnection -Scope SystemDefault
    Write-Host "Module Dbatools already installed"
}

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
        $LogfileName="MSSQL_Backup_Check_Config_${TimestampLog}.log"
        $LogFile= Join-DbaPath -Path $LogDirectory -Child $LogfileName
        Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = $LogFile}
        Write-Log -Level INFO -Message "Log File : $LogFile"
    }
}




########################################################################################################################  
## BEGIN SERVICE ACCOUNT ON AD CHECK : check if the service account has been created on the AD
########################################################################################################################     
Write-Log -Level INFO -Message "Service Account Check on AD"                                                                               
$adUser = Get-ADUser -Filter {SamAccountName -eq $serviceAccount}
if ($adUser -ne $null) {
    Write-Log -Level INFO -Message "Service Account : ${serviceAccount} has been created on the AD ==> OK"
} else {
    Write-Log -Level ERROR -Message "Service Account : ${serviceAccount} has not been created on the AD ==> KO"
}

########################################################################################################################
## BEGIN SERVICE ACCOUNT ON SERVER CHECK : check if the service account has been added to the local administrators group
######################################################################################################################## 

$configList = Get-Content -Path $configFilePath
$serverResults = @{}

$cred = Get-Credential 
foreach ($server in $configList) {
    $serverName = $server -split '\\' | Select-Object -First 1

    Write-Log -Level INFO -Message "Service Account Check on Server : ${serverName}" 

    $session = New-PSSession -ComputerName $serverName -Credential $cred

    $isAdmin = Invoke-Command -Session $session -ScriptBlock {
        param($serviceAccount)
        $adminGroupMembers = Get-LocalGroupMember -Group "Administrators"
        $adminGroupMembers | Where-Object { $_.Name -match $serviceAccount }
    } -ArgumentList $serviceAccount

    Remove-PSSession $session

    if ($isAdmin -ne $null) {
        Write-Log -Level INFO -Message "Service Account : ${serviceAccount} has been added to the local administrators group on ${serverName} ==> OK"
    } else {
        Write-Log -Level ERROR -Message "Service Account : ${serviceAccount} has not been added to the local administrators group on ${serverName} ==> KO"
    }
    $serverResults[$serverName]=$isAdmin
}

########################################################################################################################
## BEGIN SUMMARY OF CHECK
######################################################################################################################## 
Write-Log -Level INFO -Message "SUMMARY CHECK : "
Write-Log -Level INFO -Message "Internet access check : Successful"
Write-Log -Level INFO -Message "Install of module Logging : Successful"
Write-Log -Level INFO -Message "Install of module Dbatools : Successful"
if ($adUser -ne $null) {
    Write-Log -Level INFO -Message "Service Account created : Successful"
}
else{
    Write-Log -Level ERROR -Message "Service Account created : Failed"
}
foreach ($key in $serverResults.Keys) {
    $value = $serverResults[$key]
    if($value -ne $null){
        Write-Log -Level INFO -Message "Service Account added to local administrators on ${key} : Successful"
    }
    else{
        Write-Log -Level ERROR -Message "Service Account added to local administrators on ${key} : Failed"
    }
}




