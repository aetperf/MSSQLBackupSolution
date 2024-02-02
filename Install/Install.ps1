# Adapt Variables and fill the list of target instances in the .\MSSQL_BackupSolution.config file
$serviceAccount = "srv_vcic_frk_bck_p"
$proxyServer = "10.104.175.41:9480"
$proxyBypass = "*.mh.lvmh;10.*"
$configFilePath = ".\MSSQL_BackupSolution.config"
$LogDirectory = ".\Logs" # scripts logs directory
$LogLevel = "DEBUG" # DEBUG, INFO, ERROR
$Force = $true # True, False
$SqlInstanceCMS = "localhost\DBA01"


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


if ($LogDirectory -ne "")
{
    $TimestampLog=Get-Date -UFormat "%Y-%m-%d_%H%M%S"
    $Silentmkdir = mkdir $LogDirectory -Force
    $LogfileName="MSSQL_Backup_Solution_Install_${TimestampLog}.log"
    $LogFile= Join-DbaPath -Path $LogDirectory -Child $LogfileName
    Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = $LogFile}
    Write-Log -Level INFO -Message "Log File : $LogFile"
}


########################################################################################################################  
## INSTALL
########################################################################################################################

try {
    $WarningCount = 0

    Write-Log -Level INFO -Message "INSTALL MSSQLBACKUP SOLUTION : STARTING"

    # Activate proxy settings ========================================================
    Write-Log -Level INFO -Message "ACTIVATE PROXY SETTINGS : STARTING"
    .\ActivateProxy.ps1 -proxyServer $proxyServer -proxyBypass $proxyBypass
    if ($LASTEXITCODE -ne 0){
        if ($Force -eq $false){
            Write-Log -Level ERROR -Message "ACTIVATE PROXY SETTINGS : FAILED"
            Exit 1
        }
        else{
            Write-Log -Level WARNING -Message "ACTIVATE PROXY SETTINGS : FAILED but force mode is activated"
            $WarningCount++
        }
        
    }
    else {
        Write-Log -Level INFO -Message "ACTIVATE PROXY SETTINGS : SUCCESSFUL"
    }
    

    # Checks prerequisites ========================================================
    Write-Log -Level INFO -Message "CHECKS PREREQUISITES : STARTING"
    .\MSSQL_Backup_Check_Config.ps1 -serviceAccount $serviceAccount -configFilePath $configFilePath
    if ($LASTEXITCODE -ne 0){
        if ($Force -eq $false){
            Write-Log -Level ERROR -Message "CHECKS PREREQUISITES : FAILED"
            Exit 1
        }
        else{
            Write-Log -Level WARNING -Message "CHECKS PREREQUISITES : FAILED but force mode is activated"
            $WarningCount++
        }
    }
    else {
        Write-Log -Level INFO -Message "CHECKS PREREQUISITES : SUCCESSFUL"
    }
    


    # Install MSSQL Instance ========================================================
    Write-Log -Level INFO -Message "INSTALL MSSQL INSTANCE DBA01 : STARTING"
    .\Install-MSSQLInstance-dbatools.ps1
    if ($LASTEXITCODE -ne 0){
        if ($Force -eq $false){
            Write-Log -Level ERROR -Message "INSTALL MSSQL INSTANCE DBA01 : FAILED"
            Exit 1
        }
        else{
            Write-Log -Level WARNING -Message "INSTALL MSSQL INSTANCE DBA01 : FAILED but force mode is activated"
            $WarningCount++
        }
    }
    else {
        Write-Log -Level INFO -Message "INSTALL MSSQL INSTANCE DBA01 : SUCCESSFUL"
    }
    

    # Create SQL Objects ========================================================
    Write-Log -Level INFO -Message "CREATE SQL OBJECTS : STARTING"
    .\Create_SQL_Object.ps1 -SqlInstanceCMS $SqlInstanceCMS -SourceSQLPath ".\SQL" -serviceAccount $serviceAccount -Force $Force
    if ($LASTEXITCODE -ne 0){
        if ($Force -eq $false){
            Write-Log -Level ERROR -Message "CREATE SQL OBJECTS : FAILED"
            Exit 1
        }
        else{
            Write-Log -Level WARNING -Message "CREATE SQL OBJECTS : FAILED but force mode is activated"
            $WarningCount++
        }
    }    
    else {
        Write-Log -Level INFO -Message "CREATE SQL OBJECTS : SUCCESSFUL"
    }
    

    # Init CMS ========================================================
    Write-Log -Level INFO -Message "INIT CMS : STARTING"
    .\Init_CMS.ps1 -SqlInstanceCMS $SqlInstanceCMS -configFilePath $configFilePath -GroupName "ALL"
    if ($LASTEXITCODE -ne 0){
        if ($Force -eq $false){
            Write-Log -Level ERROR -Message "INIT CMS : FAILED"
            Exit 1
        }
        else{
            Write-Log -Level WARNING -Message "INIT CMS : FAILED but force mode is activated"
            $WarningCount++
        }
    }
    else {
        Write-Log -Level INFO -Message "INIT CMS : SUCCESSFUL"
    }
    


    # Finish ========================================================

    if ($WarningCount -gt 0){
        Write-Log -Level WARNING -Message "INSTALL MSSQLBACKUP SOLUTION : WARNING $WarningCount warning(s) during the installation of the solution with force mode activated"
        Exit 1
    }
    else {
        Write-Log -Level INFO -Message "INSTALL MSSQLBACKUP SOLUTION : SUCCESSFULL"
        Exit 0
    }   

    
}
catch {
    Write-Log -Level ERROR -Message "INSTALL MSSQLBACKUP SOLUTION : FAILED"
    Exit 2
}
