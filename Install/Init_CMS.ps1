
param 
(
    [Parameter(Mandatory)] [string] $SqlInstanceCMS = "localhost\DBA01",
    [Parameter(Mandatory)] [string] $configFilePath = ".\MSSQL_BackupSolution.config",
    [Parameter(Mandatory)] [string] $GroupName = "ALL",
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
        $SilentRes = mkdir $LogDirectory -Force
        $LogfileName="MSSQL_Init_CMS_${TimestampLog}.log"
        $LogFile= Join-DbaPath -Path $LogDirectory -Child $LogfileName
        Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = $LogFile}
        Write-Log -Level INFO -Message "Log File : $LogFile"
    }
}

########################################################################################################################  
## CREATION OF CMS GROUP
########################################################################################################################  
Write-Log -Level INFO -Message "Starting creation of CMS Group"
try {
    $RegServerGroup=Get-DbaRegServerGroup -SqlInstance $SqlInstanceCMS -Group $GroupName

    if($RegServerGroup -eq $null){
        Write-Log -Level INFO -Message "Create into CMS instance $SqlInstanceCMS : $GroupName Group"
        $Silentres=Add-DbaRegServerGroup -SqlInstance $SqlInstanceCMS -Name $GroupName 
    }
    else{
        Write-Log -Level INFO -Message "$GroupName Group : already exists into CMS instance $SqlInstanceCMS"
    }
}
catch {
    Write-Log -Level ERROR -Message "Error on the creation of CMS Group $GroupName"
    exit 1
}


########################################################################################################################  
## IMPORT INSTANCES INTO THE CMS
########################################################################################################################  
Write-Log -Level INFO -Message "Starting import of instances into the CMS instance $SqlInstanceCMS"

try {
    Get-Content -Path $ConfigFilePath | ForEach-Object {
        $Silentres=Add-DbaRegServer -SqlInstance $SqlInstanceCMS -ServerName $_ -Group $GroupName -WarningAction SilentlyContinue
    }
}
catch {
    Write-Log -Level ERROR -Message "Error on the import of instance $_ on the CMS"
    exit 1
}

Write-Log -Level INFO -Message "Creation of CMS Group : Successful"
Write-Log -Level INFO -Message "Import of instances into CMS Group : Successful"



