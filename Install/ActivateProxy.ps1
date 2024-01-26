<#  
    .SYNOPSIS
    Script to activate proxy settings in the registry
    .DESCRIPTION
    Set proxy settings in the registry
    .PARAMETER proxyServer
    the value for the proxy server
    .PARAMETER proxyBypass
    the value for the proxy bypass
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
    PS C:\> .\ActivateProxy.ps1 -proxyServer "http://proxy:8080" -proxyBypass "*.local;169.254.*;10.*;192.168.*" -LogDirectory "C:\MSSQL_Backup\Logs"
    PS C:\> .\ActivateProxy.ps1 -proxyServer "10.1.2.3:8080" -proxyBypass "*.local;" -LogDirectory ".\Logs"

    #>

param 
(
    [Parameter(Mandatory)] [string] $proxyServer,
    [Parameter(Mandatory)] [string] $proxyBypass,
    [Parameter()] [string] $LogDirectory,
    [Parameter()] [string] $LogLevel = "INFO"
    
)

if ($PSBoundParameters.ContainsKey('LogDirectory'))
{   
    if ($LogDirectory -ne "")
    {
        $TimestampLog=Get-Date -UFormat "%Y-%m-%d_%H%M%S"
        mkdir $LogDirectory -Force
        $LogfileName="ActivateProxy_${TimestampLog}.log"
        $LogFile= Join-DbaPath -Path $LogDirectory -Child $LogfileName
        Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = $LogFile}
        Write-Log -Level INFO -Message "Log File : $LogFile"
    }
}

try {

    # Set proxy settings in the registry
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
Set-ItemProperty -Path $regPath -Name ProxyEnable -Value 1
Set-ItemProperty -Path $regPath -Name ProxyServer -Value $proxyServer
Set-ItemProperty -Path $regPath -Name ProxyOverride -Value $proxyBypass

# Refresh Internet Explorer settings
$iePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$ieZone = Get-ItemProperty -Path $iePath
Set-ItemProperty -Path $iePath -Name ProxySettingsPerUser -Value 0
$ieZone | ForEach-Object { $_.ProxySettingsPerUser = 0 }

Write-Log -Level INFO -Message "Proxy settings set to $proxyServer"
    
}
catch {
    
    Write-Log -Level ERROR -Message "Error setting proxy settings"
    Write-Log -Level ERROR -Message $_.Exception.Message
    exit 1
}

