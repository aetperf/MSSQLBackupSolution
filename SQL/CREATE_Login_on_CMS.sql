USE [master]
GO

/****** Object:  Login [MH\srv_mcie_frk_bck_p]    Script Date: 01/12/2023 16:45:18 ******/
CREATE LOGIN [CORP\srv_mcie_sql_p] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]
GO

ALTER SERVER ROLE [sysadmin] ADD MEMBER [CORP\srv_mcie_sql_p]
GO

