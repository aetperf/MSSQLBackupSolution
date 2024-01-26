<#  
    .SYNOPSIS
    Script to de-activate proxy settings in the registry
    .DESCRIPTION
    Reset proxy settings in the registry
    .PARAMETER LogDirectory
    Directory where a log file can be stored (Optionnal)
    .PARAMETER LogLevel
    Level of logging (Optionnal) : INFO, WARNING, ERROR; Default : INFO

    .NOTES
        Tags: DisasterRecovery, Backup, Restore
        Author: Romain Ferraton, Antoine François
        Website: 
        Copyright: (c) 2022 by Romain Ferraton, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT
        Version: 1.0.0         

        Compatibility : Powershell 5+
    .EXAMPLE
    PS C:\> .\DeactivateProxy.ps1 -LogDirectory ".\Logs"

    
    #>

    param 
    (
        [Parameter()] [string] $LogDirectory,
        [Parameter()] [string] $LogLevel = "INFO"
        
    )
    
    if ($PSBoundParameters.ContainsKey('LogDirectory'))
    {   
        if ($LogDirectory -ne "")
        {
            $TimestampLog=Get-Date -UFormat "%Y-%m-%d_%H%M%S"
            mkdir $LogDirectory -Force
            $LogfileName="Deactivate-Proxy_${TimestampLog}.log"
            $LogFile= Join-DbaPath -Path $LogDirectory -Child $LogfileName
            Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = $LogFile}
            Write-Log -Level INFO -Message "Log File : $LogFile"
        }
    }
    
    try {

            # Reset proxy settings to default
            $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
            Set-ItemProperty -Path $regPath -Name ProxyEnable -Value 0
            Remove-ItemProperty -Path $regPath -Name ProxyServer -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $regPath -Name ProxyOverride -ErrorAction SilentlyContinue

            # Refresh Internet Explorer settings
            $iePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
            $ieZone = Get-ItemProperty -Path $iePath
            Set-ItemProperty -Path $iePath -Name ProxySettingsPerUser -Value 1
            $ieZone | ForEach-Object { $_.ProxySettingsPerUser = 1 }
    }
    catch {
        Write-Log -Level ERROR -Message "Error while de-activating proxy settings"
        Write-Log -Level ERROR -Message $_.Exception.Message
        exit 1
    }
    