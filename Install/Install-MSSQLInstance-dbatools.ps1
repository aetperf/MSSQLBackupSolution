$isopath="D:\_Sources\SQL\SW_DVD9_NTRL_SQL_Svr_Standard_Edtn_2019Nov2019_64Bit_English_OEM_VL_X22-18928.iso"
$InstanceName="DBA01"
$Version=2019
$Port=19433
$RootDir="D:\MSSQL"
$DataPath=$RootDir+"\DATA"
$LogPath=$RootDir+"\LOG"
$BackupPath=$RootDir+"\BACKUP"
$SQLCollation="French_CI_AS"
$TempDBPath=$RootDir+"\TEMPDB"
$UpdateSourcePath="D:\_Sources\SQL"
$FeatureList="SQLEngine,Conn"
$AuthenticationMode="Mixed"

$adminGroup = Get-LocalGroup -SID "S-1-5-32-544"
$adminGroupName = $adminGroup.Name

$CurrentUser=$Env:UserDomain+"\"+$Env:UserName
$AdminAccount=@($CurrentUser,"BUILTIN\${adminGroupName}")

$Configuration=@{
FEATURES = $FeatureList
TCPENABLED = 1
AGTSVCSTARTUPTYPE = "Automatic"
BROWSERSVCSTARTUPTYPE = "Automatic"
IACCEPTSQLSERVERLICENSETERMS = 1
ENU = 1
}

$MountISO = Mount-DiskImage -ImagePath $isopath
$LetterISO = ($MountISO | Get-Volume).DriveLetter
$SourceMSSQLPath=$LetterISO+":\"

$SilentRes=mkdir $RootDir -force
$SilentRes=mkdir $DataPath -force
$SilentRes=mkdir $LogPath -force
$SilentRes=mkdir $BackupPath -force
$SilentRes=mkdir $TempDBPath -force

try {
$MSSQLInstallResult=Install-DbaInstance -InstanceName $InstanceName -Version $Version -Port $Port -Configuration $Configuration -AuthenticationMode $AuthenticationMode -Path $SourceMSSQLPath -DataPath $DataPath -LogPath $LogPath -TempPath $TempDbPath -BackupPath $BackupPath -UpdateSourcePath $UpdateSourcePath -AdminAccount $AdminAccount -SqlCollation $SqlCollation -PerformVolumeMaintenanceTasks 
Dismount-DiskImage -ImagePath $isopath
$MSSQLInstallResult
return 0
    
}
catch {
    write-host $_.Exception.Message
    return 1
}
