DROP TABLE IF EXISTS [DbBackupHistorySync];
GO

CREATE TABLE [DbBackupHistorySync]
(
    [ServerName] [nvarchar](256) NOT NULL ,
    [LastUpdateHistory] [datetime2](7) NULL,
    [LastUpdateResults] [datetime2](7) NULL
)
;
GO

ALTER TABLE [DbBackupHistorySync] 
ADD CONSTRAINT [PK_DbBackupHistorySync] 
PRIMARY KEY CLUSTERED ([ServerName]);