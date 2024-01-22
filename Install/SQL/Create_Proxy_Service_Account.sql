USE [msdb]
GO

EXEC msdb.dbo.sp_add_proxy @proxy_name=N'Proxy_MSSQLBackup_Service',@credential_name=N'ServiceAccount_MSSQLBackups', 
		@enabled=1
GO

EXEC msdb.dbo.sp_grant_proxy_to_subsystem @proxy_name=N'Proxy_MSSQLBackup_Service', @subsystem_id=3
GO

