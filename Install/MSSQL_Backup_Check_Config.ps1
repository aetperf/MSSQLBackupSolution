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
        The name of the service account (no domain prefix).

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
        PS C:\> .\MSSQL_Backup_Check_Config.ps1 -serviceAccount "SVC_SQLBackup" -configFilePath ".\MSSQL_BackupSolution.config" -LogDirectory ".\Logs"
    #>

    param 
    (
        [Parameter(Mandatory)] [string] $serviceAccount,
        [Parameter(Mandatory)] [string] $configFilePath,
        [Parameter()] [string] $LogDirectory = ".\Logs",
        [Parameter()] [string] $LogLevel = "INFO"
        
    )
    
    [System.Net.WebRequest]::DefaultWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
    [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    
    ########################################################################################################################  
    ## BEGIN INTERNET ACCESS CHECK : check internet access 
    ########################################################################################################################  
    Write-Host "Internet Access Check"
    $internetAccess = Test-Connection -ComputerName "www.microsoft.com" -Count 2 -Quiet
    if ($internetAccess) {
        Write-Host "You have Internet Access" -ForegroundColor Green
    } else {
        Write-Host "You don't have Internet Access. Internet access is needed to install dbatools and logging powershell modules" -ForegroundColor Red
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
            Import-Module Logging -Scope Global
        }
        else{
            exit 1
        }
    } else {
        $SilentimportResult = Import-Module Logging -Scope Global
        Write-Host "Module Logging already installed"
    }
    
    $installedModuleDbatools = Get-InstalledModule -Name "Dbatools" -ErrorAction SilentlyContinue
    if ($installedModuleDbatools -eq $null) {
        Write-Host "Module Dbatools not installed"
        $reponse = Read-Host "Do you want to install it (Y/N) "
        if($reponse -eq "Y"){
            Install-Module dbatools -Scope AllUsers -Force
            Set-DbatoolsInsecureConnection -Scope SystemDefault -OutVariable $DbatoolsInsecureConnection
        }
        else{
            exit 1
        }
    } else {
        $SilentsetdbatoolsinsecureResult = Set-DbatoolsInsecureConnection -Scope SystemDefault
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
            ERROR  = 'Red'
            
        };
        Level='DEBUG'
    }
    
    if ($PSBoundParameters.ContainsKey('LogDirectory'))
    {   
        if ($LogDirectory -ne "")
        {
            $TimestampLog=Get-Date -UFormat "%Y-%m-%d_%H%M%S"
            $Silentmkdir = mkdir $LogDirectory -Force
            $LogfileName="MSSQL_Backup_Check_Config_${TimestampLog}.log"
            $LogFile= Join-DbaPath -Path $LogDirectory -Child $LogfileName
            Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = $LogFile}
            Write-Log -Level INFO -Message "Log File : $LogFile"
        }
    }
    
    
    ########################################################################################################################  
    ## BEGIN Service Account Check : check if the service account is created
    ######################################################################################################################## 
    Write-Log -Level INFO -Message "Service Account ${serviceAccount} Check on Active Directory"
    $serviceAccountObject = Get-ADUser -Identity $serviceAccount -ErrorAction SilentlyContinue
    if ($serviceAccountObject -eq $null) {
        Write-Log -Level ERROR -Message  "Service Account ${serviceAccount} not found in the AD ==> KO"
        exit 1
    } else {
        Write-Log -Level INFO -Message "Service Account ${serviceAccount} found in the AD ==> OK"
        # Retrieve the groups of ther service account
        $serviceAccountADGroups = Get-ADUser -Identity $serviceAccount -Properties memberOf | Select-Object -ExpandProperty memberOf | Get-ADGroup
    
        Write-Log -Level INFO -Message "Service Account ${serviceAccount} is member of AD Groups : "
        foreach ($group in $serviceAccountADGroups) {
            Write-Log -Level INFO -Message "Service Account ${serviceAccount} is member of the AD Group : ${group}"
        }
    }
    
    
    
    ########################################################################################################################  
    ## check if the service account has been added to the local administrators group on the CMS server
    ########################################################################################################################     
    Write-Log -Level INFO -Message "Service Account Check Member of Administrators Group on ${env:COMPUTERNAME}"   
    ## check for the local group Administrators whatever the language of the OS
    $adminGroup = Get-LocalGroup -SID "S-1-5-32-544"
    $LocalAdminGroupMembers = Get-LocalGroupMember -Group $adminGroup.Name
    
    # check if the service account is member of the local group Administrators 
    # or if it is member of a group who is member of the local group Administrators
    $isAdminDirect = $LocalAdminGroupMembers | Where-Object { $_.Name -match $serviceAccount }
    if ($isAdminDirect -ne $null) {
        Write-Log -Level INFO -Message "Service Account ${serviceAccount} is a direct member of the local administrators group on ${env:COMPUTERNAME} ==> OK"
    } 
    else {

        Write-Log -Level INFO -Message "Service Account ${serviceAccount} is not a direct member of the local administrators group on ${env:COMPUTERNAME} ==> Continue to search on Local Group"

        # Test if the service account is member of a local group who is member of the local group Administrators
        $isAdminIndirectLocal = $LocalAdminGroupMembers | Where-Object { ($_.ObjectClass -eq "Group") -and ($_.PrincipalSource -ne "ActiveDirectory")  } | Where-Object { (Get-LocalGroupMember -Group $_.Name).Name -match $serviceAccount }
    
        if ($isAdminIndirectLocal -ne $null) {
            Write-Log -Level INFO -Message "Service Account ${serviceAccount} is member of a local group who is member of the local administrators group on ${env:COMPUTERNAME} ==> OK"
        } 
        else {
            Write-Log -Level INFO -Message "Service Account ${serviceAccount} is not a member of a local group who is member of the local administrators group on ${env:COMPUTERNAME} ==> Continue to search in AD Groups"
            # Get all AD groups who are member of the local administrators group
            $AdminADGroup = $LocalAdminGroupMembers | Where-Object { ($_.ObjectClass -eq "Group") -and ($_.PrincipalSource -eq "ActiveDirectory")  }
    
            # remove domain prefix from the name of $AdminADGroup
            $AdminADGroupName = $AdminADGroup | Select-Object -ExpandProperty Name | ForEach-Object { $_ -replace ".*\\" }

            # get members of the $AdminADGroupName groups using recursive Get-AdGroupMember (using a foreach loop)
            $AdminADGroupMembers = @()

            foreach ($group in $AdminADGroupName) {
                $AdminADGroupMembers += Get-ADGroupMember -Identity $group -Recursive | Where-Object { $_.objectClass -eq "user" }
            }

    
            # test if we found the service account in the $AdminADGroupMembers variable
            $isAdminIndirectAD = $AdminADGroupMembers | Where-Object { $_.Name -match $serviceAccount }
    
    
            if($isAdminIndirectAD){
                Write-Log -Level INFO -Message "Service Account ${serviceAccount} is member of an AD group who is member of the local administrators group on ${env:COMPUTERNAME} ==> OK"
            }
            else {
                Write-Log -Level ERROR -Message "Service Account ${serviceAccount} is not found in any AD members of the local administrators group on ${env:COMPUTERNAME} ==> KO"
                exit 1
            }
    
        }
        
    }
    
    ########################################################################################################################
    ## BEGIN SERVICE ACCOUNT ON SERVER CHECK : check if the service account has been added to the local administrators group on the target servers
    ######################################################################################################################## 
    
    $configList = Get-Content -Path $configFilePath
    $serverResults = @{}
    
    $cred = Get-Credential -UserName $serviceAccount -Message "Enter the password for the service account : ${serviceAccount}"
    
    if ($cred -eq $null) {
        Write-Log -Level ERROR -Message "Get-Credential Error for the service account  : ${serviceAccount}"
        exit 1
    }

    # From the $configlist content we retrieve only the server name by splitting lines that contains a \ character or a : character 
    # and deduplicate the list of servers found
    $fullserverlist=@()
    foreach ($server in $configList) {
        if ($server -match "\\") {
            $servername = $server -split '\\' | Select-Object -First 1
            $fullserverlist += $servername
        }
        elseif ($server -match ":") {
            $servername = $server -split ':' | Select-Object -First 1
            $fullserverlist += $servername
        }
        else {
            $fullserverlist += $server
        }
    }
    $serverlist = $fullserverlist | Select-Object -Unique
    
    write-log -Level INFO -Message "List of servers to check : "
    foreach ($server in $serverlist) {
        write-log -Level INFO -Message $server
    }

    foreach ($server in $serverlist) {
        $serverName = $server -split '\\' | Select-Object -First 1
        $userName=$cred.UserName
        Write-Log -Level INFO -Message "Try Connect to : ${serverName} with ${userName}." 
    
        try {
        $session = New-PSSession -ComputerName $serverName -Credential $cred
    
        $isAdmin = Invoke-Command -Session $session -ScriptBlock {
            param($serviceAccount)
            param($serviceAccountgroups)
            ## check for the local group Administrators whatever the language of the OS
            $adminGroup = Get-LocalGroup -SID "S-1-5-32-544"
            $LocalAdminGroupMembers = Get-LocalGroupMember -Group $adminGroup.Name
    
            # check if the service account is member of the local group Administrators 
            # or if it is member of a group who is member of the local group Administrators
            $isAdminDirect = $LocalAdminGroupMembers | Where-Object { $_.Name -match $serviceAccount }
            if ($isAdminDirect -ne $null) {
                Write-Log -Level INFO -Message "Service Account : ""${serviceAccount}"" is a direct member of the local administrators group on ${env:COMPUTERNAME} ==> OK"
                return 0
            } 
            else {
                Write-Log -Level INFO -Message "Service Account ${serviceAccount} is not a direct member of the local administrators group on ${env:COMPUTERNAME} ==> Continue to search on Local Group"
                
                # Test if the service account is member of a local group who is member of the local group Administrators
                $isAdminIndirectLocal = $LocalAdminGroupMembers | Where-Object { ($_.ObjectClass -eq "Group") -and ($_.PrincipalSource -ne "ActiveDirectory")  } | Where-Object { (Get-LocalGroupMember -Group $_.Name).Name -match $serviceAccount }
    
                if ($isAdminIndirectLocal -ne $null) {
                    Write-Log -Level INFO -Message "Service Account : ""${serviceAccount}"" is member of a local group who is member of the local administrators group  on ${env:COMPUTERNAME} ==> OK"
                    return 0
                } 
                else {
                    # test if at least one group of the $serviceAccountGroups variable match at least one group of the $adminGroupMembers variable                    
                    $isAdminIndirectAD=@()
                    foreach ($group in $serviceAccountgroups) {
                        $isAdminIndirectAD[$group] = $LocalAdminGroupMembers | Where-Object { ($_.ObjectClass -eq "Group") -and ($_.PrincipalSource -eq "ActiveDirectory")  } | Where-Object { $_.Name -match $group.Name }
                        Write-Log -Level INFO -Message "Service Account : ${serviceAccount} is member of the AD Group : ${group} who is member of the local administrators group  on ${env:COMPUTERNAME} ==> OK"
                    }
                    if($isAdminIndirectAD -ne $null){
                        Write-Log -Level INFO -Message "Service Account : ${serviceAccount} is member of an AD group who is member of the local administrators group  on ${env:COMPUTERNAME} ==> OK"
                        return 0
                    }
                    else {
                        Write-Log -Level ERROR -Message "Service Account : ${serviceAccount} is not member of the local administrators group  on ${env:COMPUTERNAME} ==> KO"
                        return 1
                    }
    
                }
                
            }
        } -ArgumentList $serviceAccount $serviceAccountGroups
    
    
        
    
        if ($isAdmin -eq 0) {
            Write-Log -Level INFO -Message "Service Account : ""${serviceAccount}"" has been added to the local administrators group on ${serverName} ==> OK"
        } else {
            Write-Log -Level ERROR -Message "Service Account : ""${serviceAccount}"" has not been added to the local administrators group on ${serverName} ==> KO"
        }
        $serverResults[$serverName]=$isAdmin
    
        Remove-PSSession $session
        }
        catch {
            Write-Log -Level ERROR -Message "Error during the New-PSSession connection to the server : ${serverName} with the service account : ""${serviceAccount}"""
            exit 1
        }
    }
    
    ########################################################################################################################
    ## BEGIN SUMMARY OF CHECK
    ######################################################################################################################## 
    Write-Log -Level INFO -Message "SUMMARY CHECK : "
    Write-Log -Level INFO -Message "Internet access check : Successful"
    Write-Log -Level INFO -Message "Install of module Logging : Successful"
    Write-Log -Level INFO -Message "Install of module Dbatools : Successful"
    foreach ($key in $serverResults.Keys) {
        $value = $serverResults[$key]
        if($value -eq 0){
            Write-Log -Level INFO -Message "Service Account added to local administrators on ${key} : Successful"
        }
        else{
            Write-Log -Level ERROR -Message "Service Account added to local administrators on ${key} : Failed"
        }
    }
    
    
    
    
    