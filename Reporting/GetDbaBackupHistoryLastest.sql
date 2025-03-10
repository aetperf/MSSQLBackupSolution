SELECT
    a.BackupSetRank,
    a.Server,
    '' as AvailabilityGroupName,
    a.[Database],
    a.DatabaseId,
    a.Username,
    a.Start,
    a.[End],
    a.Duration,
    a.[Path],
    a.Type,
    a.TotalSize,
    a.CompressedBackupSize,
    a.MediaSetId,
    a.BackupSetID,
    a.Software,
    a.position,
    a.first_lsn,
    a.database_backup_lsn,
    a.checkpoint_lsn,
    a.last_lsn,
    a.first_lsn as 'FirstLSN',
    a.database_backup_lsn as 'DatabaseBackupLsn',
    a.checkpoint_lsn as 'CheckpointLsn',
    a.last_lsn as 'LastLsn',
    a.software_major_version,
    a.DeviceType,
    a.is_copy_only,
    a.last_recovery_fork_guid,
    a.recovery_model,
    a.EncryptorThumbprint,
    a.EncryptorType,
    a.KeyAlgorithm
FROM (
    SELECT
    RANK() OVER (ORDER BY backupset.last_lsn , backupset.backup_finish_date DESC) AS 'BackupSetRank',
    backupset.database_name AS [Database],
    (SELECT database_id FROM sys.databases WHERE name = backupset.database_name) AS DatabaseId,
    backupset.user_name AS Username,
    backupset.backup_start_date AS Start,
    backupset.server_name as [Server],
    backupset.backup_finish_date AS [End],
    DATEDIFF(SECOND, backupset.backup_start_date, backupset.backup_finish_date) AS Duration,
    mediafamily.physical_device_name AS Path,
        backupset.backup_size AS TotalSize,
	backupset.compressed_backup_size as CompressedBackupSize,
	encryptor_thumbprint as EncryptorThumbprint,
	encryptor_type as EncryptorType,
	key_algorithm AS KeyAlgorithm,
    CASE backupset.type
    WHEN 'L' THEN 'Log'
    WHEN 'D' THEN 'Full'
    WHEN 'F' THEN 'File'
    WHEN 'I' THEN 'Differential'
    WHEN 'G' THEN 'Differential File'
    WHEN 'P' THEN 'Partial Full'
    WHEN 'Q' THEN 'Partial Differential'
    ELSE NULL
    END AS Type,
    backupset.media_set_id AS MediaSetId,
    mediafamily.media_family_id as mediafamilyid,
    backupset.backup_set_id as BackupSetID,
    CASE mediafamily.device_type
    WHEN 2 THEN 'Disk'
    WHEN 102 THEN 'Permanent Disk Device'
    WHEN 5 THEN 'Tape'
    WHEN 105 THEN 'Permanent Tape Device'
    WHEN 6 THEN 'Pipe'
    WHEN 106 THEN 'Permanent Pipe Device'
    WHEN 7 THEN 'Virtual Device'
    WHEN 9 THEN 'URL'
    ELSE 'Unknown'
    END AS DeviceType,
    backupset.position,
    backupset.first_lsn,
    backupset.database_backup_lsn,
    backupset.checkpoint_lsn,
    backupset.last_lsn,
    backupset.software_major_version,
    mediaset.software_name AS Software,
    backupset.is_copy_only,
    backupset.last_recovery_fork_guid,
    backupset.recovery_model
    FROM msdb..backupmediafamily AS mediafamily
    JOIN msdb..backupmediaset AS mediaset ON mediafamily.media_set_id = mediaset.media_set_id
    JOIN msdb..backupset AS backupset ON backupset.media_set_id = mediaset.media_set_id
    ) AS a