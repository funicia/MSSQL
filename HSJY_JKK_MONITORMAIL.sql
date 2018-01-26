

ALTER PROC HSJY_JKK_MONITORMAIL(
	@TBNAME			NVARCHAR(100),	/*���������ʱ������*/
	@profile_name	Nvarchar(100),	/*�ʼ������������ļ�����*/
	@Title			NVARCHAR(200),	/*�ʼ����ı���*/
	@Mcontent		Nvarchar(2000),	/*�ʼ����ݼ���*/
	@recipients		NVARCHAR(2000),	/*�ռ��ˣ������;����*/
	@copy_recipients NVARCHAR(2000) = NULL /*����*/

)
AS

/*
	�����ݿ���ҵ�ķ�ʽ���м��,�ýű��Ѽ������д����ʱ��,Ȼ������������䲢�������ü��ɽ����ʼ�����.
	sample: EXEC dbo.HSJY_JKK_MonitorMail 'tempdb..#JKBC','rfc_test','�ʼ��������','funicia@xxx.com','xxx@xxx.com'
*/

--DECLARE @TBNAME			VARCHAR(100),	/*���������ʱ������*/
--		  @profile_name		varchar(100),	/*�ʼ������������ļ�����*/
--		  @@Title			VARCHAR(200),	/*�ʼ����ı���*/
--		  @Mcontent			varchar(2000),	/*�ʼ����ݼ���*/
--		  @recipients		VARCHAR(2000)	/*�ռ��ˣ������';'����*/
 
DECLARE @SQLSTR	NVARCHAR(MAX),		
		@COLUMNS NVARCHAR(MAX) = '',
		@COLID  INT = 1
		 

WHILE @COLID<=(SELECT MAX(colid) FROM tempdb..syscolumns WHERe id = OBJECT_ID(@TBNAME))
BEGIN
	SELECT @COLUMNS=@COLUMNS+',ISNULL(['+name+'],'+''' '')' +' AS [TD],'+'+'' '+'''' FROM tempdb..syscolumns WHERe id = OBJECT_ID(@TBNAME) and colid=@COLID
	SELECT @COLID=@COLID+1
END
  
SELECT @COLUMNS=SUBSTRING(@COLUMNS,2,LEN(@COLUMNS)-1)
 
/*HTML���ʽ*/
SELECT @SQLSTR = N'<H1 align = "center">'+@Mcontent+' </H1> 
							<table border="1px" width = "900" cellspacing="0px" 
								style="border-collapse:collapse;table-layout:fixed;font-size:14px;font-family:΢���ź�;white-space:pre-line"
								cellpadding="0"; align = "center"   > <tr bgcolor="Silver" align = "center"  >'

/*��ͷ*/
SELECT @SQLSTR = @SQLSTR+ CAST((SELECT name as 'td',+' '  FROM tempdb..syscolumns WHERe id = OBJECT_ID(@TBNAME) ORDER BY colid for XML PATH(''))AS NVARCHAR(MAX)) +'</tr>'

/*ȡ�����ݵ��ַ���������ƴ��*/
SELECT @COLUMNS = N'SELECT @COLUMNS = CONVERT(NVARCHAR(MAX),
					(SELECT 
						 ''word-break : break-all; width="100%";'' as [@style],
					     ''center'' as [@align],
						  '+ @COLUMNS+ '   FROM '+@TBNAME+ ' FOR XML PATH('+'''tr''),type)) ' 
 
/*���������ݲ��뵽������ַ�����*/
exec sys.sp_executesql @COLUMNS,N'@TBNAME VARCHAR(100), @COLUMNS nVARCHAR(MAX) OUTPUT',@TBNAME, @COLUMNS OUTPUT

/*ƴ���ַ��������*/ 
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
