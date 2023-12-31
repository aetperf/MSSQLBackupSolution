USE [MSSQLBackupSolutionDB]
GO

CREATE TABLE [dbo].[BackupResults](
	[BackupComplete] [bit] NULL,
	[BackupFile] [nvarchar](4000) NULL,
	[BackupFilesCount] [int] NULL,
	[BackupFolder] [nvarchar](4000) NULL,
	[BackupPath] [nvarchar](4000) NULL,
	[DatabaseName] [nvarchar](256) NULL,
	[Notes] [nvarchar](max) NULL,
	[Script] [nvarchar](max) NULL,
	[Verified] [bit] NULL,
	[ComputerName] [nvarchar](256) NULL,
	[InstanceName] [nvarchar](256) NULL,
	[SqlInstance] [nvarchar](256) NULL,
	[AvailabilityGroupName] [nvarchar](256) NULL,
	[Database] [nvarchar](256) NULL,
	[DatabaseId] [nvarchar](256) NULL,
	[UserName] [nvarchar](256) NULL,
	[Start] [datetime2](7) NULL,
	[End] [datetime2](7) NULL,
	[Duration] [bigint] NULL,
	[Path] [nvarchar](max) NULL,
	[TotalSize] [bigint] NULL,
	[CompressedBackupSize] [bigint] NULL,
	[CompressionRatio] [float] NULL,
	[Type] [nvarchar](256) NULL,
	[BackupSetId] [nvarchar](256) NULL,
	[DeviceType] [nvarchar](256) NULL,
	[Software] [nvarchar](4000) NULL,
	[FullName] [nvarchar](4000) NULL,
	[FileList] [nvarchar](max) NULL,
	[Position] [int] NULL,
	[FirstLsn] [nvarchar](256) NULL,
	[DatabaseBackupLsn] [nvarchar](256) NULL,
	[CheckpointLsn] [nvarchar](256) NULL,
	[LastLsn] [nvarchar](256) NULL,
	[SoftwareVersionMajor] [int] NULL,
	[IsCopyOnly] [bit] NULL,
	[LastRecoveryForkGUID] [uniqueidentifier] NULL,
	[RecoveryModel] [nvarchar](256) NULL,
	[KeyAlgorithm] [nvarchar](256) NULL,
	[EncryptorThumbprint] [nvarchar](256) NULL,
	[EncryptorType] [nvarchar](256) NULL,
	[Message] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

