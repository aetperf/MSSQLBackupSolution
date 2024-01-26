<#  
    .SYNOPSIS
    Script to activate proxy settings in the registry
    .DESCRIPTION
    Set proxy settings in the registry
    .PARAMETER proxyServer
    the value for the proxy server
    .PARAMETER proxyBypass
    the value for the proxy bypass

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
    PS C:\> .\ActivateProxy.ps1 -proxyServer "10.1.2.3:8080" -proxyBypass "*.local;"

    #>

param 
(
    [Parameter(Mandatory)] [string] $proxyServer,
    [Parameter(Mandatory)] [string] $proxyBypass
    
)

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

Write-Host "Proxy settings set to $proxyServer"
    
}
catch {
    
    Write-Host "Error setting proxy settings"
    Write-Host $_.Exception.Message
    exit 1
}

