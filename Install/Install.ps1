# Adapt Variables and fill the list of target instances in the .\MSSQL_BackupSolution.config file
$serviceAccount = "srv_vcic_frk_bck_p"
$proxyServer = "10.104.175.41:9480"
$proxyBypass = "*.mh.lvmh;10.*"
$configFilePath = ".\MSSQL_BackupSolution.config"
$LogDirectory = ".\Logs" # scripts logs directory
$LogLevel = "DEBUG" # DEBUG, INFO, ERROR
$Force = "True" # True, False


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

########################################################################################################################  
## INSTALL
########################################################################################################################

try {
    $WarningCount = 0

    Write-Log -Level INFO -Message "Starting installation of the solution MSSQL_BackupSolution"

    # Activate proxy settings ========================================================
    Write-Log -Level INFO -Message "Activate proxy settings"
    .\ActivateProxy.ps1 -proxyServer $proxyServer -proxyBypass $proxyBypass
    if ($LASTEXITCODE -ne 0){
        if ($Force -eq "False"){
            Write-Log -Level ERROR -Message "FAILED : Error during the activation of the proxy settings"
            Exit 1
        }
        else{
            Write-Log -Level WARNING -Message "FAILED : Error during the activation of the proxy settings but force mode is activated"
            $WarningCount++
        }
        
    }
    else {
        Write-Log -Level INFO -Message "Activate proxy settings : Successful"
    }
    

    # Checks prerequisites ========================================================
    Write-Log -Level INFO -Message "Checks prerequisites"
    .\MSSQL_Backup_Check_Config.ps1 -serviceAccount $serviceAccount -configFilePath $configFilePath -LogDirectory $LogDirectory
    if ($LASTEXITCODE -ne 0){
        if ($Force -eq "False"){
            Write-Log -Level ERROR -Message "FAILED : Error during the checks prerequisites"
            Exit 1
        }
        else{
            Write-Log -Level WARNING -Message "FAILED : Error during the checks prerequisites but force mode is activated"
            $WarningCount++
        }
    }
    else {
        Write-Log -Level INFO -Message "Checks prerequisites : Successful"
    }
    


    # Install MSSQL Instance ========================================================
    Write-Log -Level INFO -Message "Install MSSQL Instance DBA01"
    .\Install-MSSQLInstance-dbatools.ps1
    if ($LASTEXITCODE -ne 0){
        if ($Force -eq "False"){
            Write-Log -Level ERROR -Message "FAILED : Error during the installation of MSSQL Instance DBA01"
            Exit 1
        }
        else{
            Write-Log -Level WARNING -Message "FAILED : Error during the installation of MSSQL Instance DBA01 but force mode is activated"
            $WarningCount++
        }
    }
    else {
        Write-Log -Level INFO -Message "Install MSSQL Instance DBA01 : Successful"
    }
    

    # Create SQL Objects ========================================================
    Write-Log -Level INFO -Message "Create SQL Objects"
    .\MSSQL_Create_SQL_Object.ps1 -serviceAccount $serviceAccount -LogDirectory $LogDirectory
    if ($LASTEXITCODE -ne 0){
        if ($Force -eq "False"){
            Write-Log -Level ERROR -Message "FAILED : Error during the creation of SQL Objects"
            Exit 1
        }
        else{
            Write-Log -Level WARNING -Message "FAILED : Error during the creation of SQL Objects but force mode is activated"
            $WarningCount++
        }
    }    
    else {
        Write-Log -Level INFO -Message "Create SQL Objects : Successful"
    }
    

    # Init CMS ========================================================
    Write-Log -Level INFO -Message "Init CMS"
    .\MSSQL_Init_CMS.ps1 -configFilePath $configFilePath -LogDirectory $LogDirectory
    if ($LASTEXITCODE -ne 0){
        if ($Force -eq "False"){
            Write-Log -Level ERROR -Message "FAILED : Error during the init of CMS"
            Exit 1
        }
        else{
            Write-Log -Level WARNING -Message "FAILED : Error during the init of CMS but force mode is activated"
            $WarningCount++
        }
    }
    else {
        Write-Log -Level INFO -Message "Init CMS : Successful"
    }
    


    # Finish ========================================================

    if ($WarningCount -gt 0){
        Write-Log -Level WARNING -Message "WARNING : $WarningCount warning(s) during the installation of the solution with force mode activated"
        Exit 1
    }
    else {
        Write-Log -Level INFO -Message "SUCCESS : Installation of the solution MSSQL_BackupSolution Completed"
        Exit 0
    }   

    
}
catch {
    Write-Log -Level ERROR -Message "FAILED : Error during the installation of the solution"
    Exit 2
}
