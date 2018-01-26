

ALTER PROC HSJY_JKK_MONITORMAIL(
	@TBNAME			NVARCHAR(100),	/*监控数据临时表名称*/
	@profile_name	Nvarchar(100),	/*邮件服务器配置文件名称*/
	@Title			NVARCHAR(200),	/*邮件正文标题*/
	@Mcontent		Nvarchar(2000),	/*邮件内容简述*/
	@recipients		NVARCHAR(2000),	/*收件人，多个用;隔开*/
	@copy_recipients NVARCHAR(2000) = NULL /*抄送*/

)
AS

/*
	用数据库作业的方式进行监控,用脚本把监控数据写入临时表,然后调用下面的语句并进行设置即可进行邮件提醒.
	sample: EXEC dbo.HSJY_JKK_MonitorMail 'tempdb..#JKBC','rfc_test','邮件报错测试','funicia@xxx.com','xxx@xxx.com'
*/

--DECLARE @TBNAME			VARCHAR(100),	/*监控数据临时表名称*/
--		  @profile_name		varchar(100),	/*邮件服务器配置文件名称*/
--		  @@Title			VARCHAR(200),	/*邮件正文标题*/
--		  @Mcontent			varchar(2000),	/*邮件内容简述*/
--		  @recipients		VARCHAR(2000)	/*收件人，多个用';'隔开*/
 
DECLARE @SQLSTR	NVARCHAR(MAX),		
		@COLUMNS NVARCHAR(MAX) = '',
		@COLID  INT = 1
		 

WHILE @COLID<=(SELECT MAX(colid) FROM tempdb..syscolumns WHERe id = OBJECT_ID(@TBNAME))
BEGIN
	SELECT @COLUMNS=@COLUMNS+',ISNULL(['+name+'],'+''' '')' +' AS [TD],'+'+'' '+'''' FROM tempdb..syscolumns WHERe id = OBJECT_ID(@TBNAME) and colid=@COLID
	SELECT @COLID=@COLID+1
END
  
SELECT @COLUMNS=SUBSTRING(@COLUMNS,2,LEN(@COLUMNS)-1)
 
/*HTML表格式*/
SELECT @SQLSTR = N'<H1 align = "center">'+@Mcontent+' </H1> 
							<table border="1px" width = "900" cellspacing="0px" 
								style="border-collapse:collapse;table-layout:fixed;font-size:14px;font-family:微软雅黑;white-space:pre-line"
								cellpadding="0"; align = "center"   > <tr bgcolor="Silver" align = "center"  >'

/*表头*/
SELECT @SQLSTR = @SQLSTR+ CAST((SELECT name as 'td',+' '  FROM tempdb..syscolumns WHERe id = OBJECT_ID(@TBNAME) ORDER BY colid for XML PATH(''))AS NVARCHAR(MAX)) +'</tr>'

/*取表数据的字符串，用来拼接*/
SELECT @COLUMNS = N'SELECT @COLUMNS = CONVERT(NVARCHAR(MAX),
					(SELECT 
						 ''word-break : break-all; width="100%";'' as [@style],
					     ''center'' as [@align],
						  '+ @COLUMNS+ '   FROM '+@TBNAME+ ' FOR XML PATH('+'''tr''),type)) ' 
 
/*将表内数据插入到结果集字符串中*/
exec sys.sp_executesql @COLUMNS,N'@TBNAME VARCHAR(100), @COLUMNS nVARCHAR(MAX) OUTPUT',@TBNAME, @COLUMNS OUTPUT

/*拼接字符串结果集*/ 
SELECT @SQLSTR=@SQLSTR+ @COLUMNS+ N'</table>'


--select @SQLSTR
----select @tableHTML
exec msdb.dbo.sp_send_dbmail
	 @profile_name	= @profile_name, --@profile_name
	 @recipients	= @recipients, --'funicia@xxx.com;zhengyue@xxx.com', 
	 @copy_recipients = @copy_recipients,
	 @subject		= @Title,
	 @body			= @SQLSTR,
	 @body_format	= 'HTML';
