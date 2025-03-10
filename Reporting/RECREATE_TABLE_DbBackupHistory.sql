
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DbBackupHistory]') AND type in (N'U'))
DROP TABLE [dbo].[DbBackupHistory]
GO


CREATE TABLE [dbo].[DbBackupHistory](
	[ComputerName] [nvarchar](256) NOT NULL,
	[InstanceName] [nvarchar](128) NOT NULL,
	[SqlInstance] [nvarchar](256) NULL,
	[AvailabilityGroupName] [nvarchar](256) NULL,
	[Database] [nvarchar](256) NOT NULL,
	[DatabaseId] INT  NULL,
	[UserName] [nvarchar](256) NULL,
	[Start] [datetime2](7) NOT NULL,
	[End] [datetime2](7) NULL,
	[Duration] [bigint] NULL,
	[Path] [nvarchar](4000) NULL,
	[TotalSize] [bigint] NULL,
	[CompressedBackupSize] [bigint] NULL,
	[CompressionRatio] [float] NULL,
	[Type] [nvarchar](100) NOT NULL,
	[BackupSetId] int NULL,
	[DeviceType] [nvarchar](100) NULL,
	[Software] [nvarchar](500) NULL,
	[FullName] [nvarchar](4000) NULL,
	[FileList] [nvarchar](4000) NULL,
	[Position] [int] NULL,
	[FirstLsn] [nvarchar](100) NOT NULL,
	[DatabaseBackupLsn] [nvarchar](100) NOT NULL,
	[CheckpointLsn] [nvarchar](100) NOT NULL,
	[LastLsn] [nvarchar](100) NOT NULL,
	[SoftwareVersionMajor] [tinyint] NULL,
	[IsCopyOnly] [bit] NULL,
	[LastRecoveryForkGUID] [uniqueidentifier] NULL,
	[RecoveryModel] [nvarchar](50) NOT NULL,
	[KeyAlgorithm] [nvarchar](128) NULL,
	[EncryptorThumbprint] [nvarchar](1024) NULL,
	[EncryptorType] [nvarchar](128) NULL
) ON [PRIMARY] 
GO




