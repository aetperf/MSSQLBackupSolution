USE [master]
GO
CREATE CREDENTIAL [ServiceAccount4MSSQLBackups] WITH IDENTITY = N'CORP\srv_sql_bck_p', SECRET = N'<Password>'
GO
