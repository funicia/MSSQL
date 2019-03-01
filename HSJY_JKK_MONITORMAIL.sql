

ALTER PROC HSJY_JKK_MONITORMAIL(
	@TBNAME			NVARCHAR(100),	/*监控数据临时表名称*/
	@profile_name	Nvarchar(100),	/*邮件服务器配置文件名称*/
	@Title			NVARCHAR(200),	/*邮件正文标题*/
	@Mcontent		Nvarchar(2000),	/*邮件内容简述*/
	@recipients		NVARCHAR(2000),	/*收件人，多个用;隔开*/
	@copy_recipients NVARCHAR(2000) = NULL, /*抄送*/
	@ORDER_COLUMNS	NVARCHAR(100) = NULL /*排序字段，支持字段名排序，默认按首字段正序排*/

)
AS

/*
	用数据库作业的方式进行监控,用脚本把监控数据写入临时表,然后调用下面的语句并进行设置即可进行邮件提醒.
	sample: EXEC dbo.HSJY_JKK_MonitorMail 'tempdb..#JKBC','rfc_test','邮件报错测试','renfc@gildata.com','appdata@gildata.com'
*/

--DECLARE @TBNAME			VARCHAR(100),	/*监控数据临时表名称*/
--		  @profile_name		varchar(100),	/*邮件服务器配置文件名称*/
--		  @@Title			VARCHAR(200),	/*邮件正文标题*/
--		  @Mcontent			varchar(2000),	/*邮件内容简述*/
--		  @recipients		VARCHAR(2000),	/*收件人，多个用';'隔开*/
--		  @copy_recipients NVARCHAR(2000) = NULL, /*抄送*/
--		  @ORDER_COLUMNS	NVARCHAR(100) = NULL /*排序字段，支持字段名排序，默认按首字段正序排*/
 	

-----------------------------------------------------------------

/*如果按位置传排序参数，暂时不支持，默认给成第一个字段排序*/
BEGIN TRY
	EXEC('SELECT XH = ROW_NUMBER() OVER(ORDER BY '+@ORDER_COLUMNS+') INTO #TMP'+ ' FROM '+@TBNAME)
END TRY
BEGIN CATCH
	SELECT TOP 1 @ORDER_COLUMNS =  '['+ name +']' FROM tempdb..syscolumns WHERe id = OBJECT_ID(@TBNAME)  ORDER BY colid 
END CATCH

/*字段列表*/
DECLARE @C NVARCHAR(MAX)
SELECT @C = STUFF((SELECT ',['+name+']' FROM tempdb..syscolumns WHERe id = OBJECT_ID(@TBNAME) ORDER BY colid FOR XML PATH('')),1,1,'') 

-----------------------------------------------------------------

/*将数据按排序字段排序，将排序后的数据放入tmp_html_id*/
DECLARE @SQLSS NVARCHAR(MAX)
SET @SQLSS =
		  ' INSERT INTO '+@TBNAME +CHAR(10)+
		  ' SELECT '+@C+', XH = ROW_NUMBER() OVER(ORDER BY '+@ORDER_COLUMNS+')'+ 
		  ' FROM '+@TBNAME + ' A' +
		  ' DELETE FROM '+@TBNAME + ' WHERE tmp_html_id IS NULL'


IF NOT EXISTS (SELECT 1 FROM tempdb..syscolumns WHERe id = OBJECT_ID(@TBNAME) AND name =  'tmp_html_id')
BEGIN
	EXEC('	alter table '+@TBNAME +'
			add tmp_html_id int')	
	EXEC (@SQLSS)
END

----------------------------------------------------------------------------------------------------------------

DECLARE @SQLSTR	NVARCHAR(MAX),	
		@COLUMNS NVARCHAR(MAX) = ''
SELECT @COLUMNS = 
(
	SELECT	  ','+
			  CASE WHEN xtype = 61 then 'CONVERT(VARCHAR(23),' ELSE '' END + 
				'ISNULL(['+name+'],'+  --日期格式的字段，对其进行转换，防止出现“日期T时间”的情况
				CASE WHEN xtype IN (48,52,56,59,60,62,106,108,122,127) THEN '''0'')' ELSE ''' '')' END + --数据类型处理，对数值类型的，ISNULL给0，非数值的暂时给' '，以后出现转换失败的再进行处理
				CASE WHEN xtype = 61 then ',121)' ELSE '' END 
			  +' AS [TD],'+'+'''+''''
	FROM tempdb..syscolumns WHERe id = OBJECT_ID(@TBNAME) AND name <>  'tmp_html_id'
	order by colid
	FOR XML PATH('')
) 

select @COLUMNS = STUFF(@COLUMNS,1,1,'')
 
/*HTML表格式*/--border="1px"
SELECT @SQLSTR = N'<H1 align = "center">'+@Mcontent+' </H1> 
							<table  width = "1000" cellspacing="0px" frame="hsides"
								style="border-collapse:collapse;table-layout:fixed;font-size:14px;font-family:微软雅黑;white-space:pre-line"
								cellpadding="0"; align = "center"   > 								
								<tr style="word-break : break-all;height:42" bgcolor = "#70ad47" align="center" >'

/*表头*/
SELECT @SQLSTR = @SQLSTR+ CAST((SELECT N'《font color="white"》'+name+'《/font》' as 'td',+''  FROM tempdb..syscolumns WHERe id = OBJECT_ID(@TBNAME) AND name<> 'tmp_html_id' ORDER BY colid for XML PATH(''))AS NVARCHAR(MAX)) +'</tr>'
--SELECT @SQLSTR = @SQLSTR+ CAST((SELECT  name as 'td',+''  FROM tempdb..syscolumns WHERe id = OBJECT_ID(@TBNAME) AND name<> 'tmp_html_id' ORDER BY colid for XML PATH(''))AS NVARCHAR(MAX)) +'</tr>'

SELECT @SQLSTR = REPLACE(REPLACE(@SQLSTR,'《','<'),'》','>')
--SELECT @SQLSTR
/*取表数据的字符串，用来拼接*/
SELECT @COLUMNS = N'SELECT @COLUMNS = CONVERT(NVARCHAR(MAX),
					(SELECT '
						  +'''center'' as [@align],'
						  +'[@style] = '+'''word-break : break-all;height:42;background-color: ''+'+'CASE WHEN A.tmp_html_id%2=0 THEN '+'''#f4f1f4'''+ ' ELSE '+'''#FBFFFD'''+' END'+ ','
						  + @COLUMNS
						  + '  FROM '+@TBNAME+ ' AS A ORDER BY '+@ORDER_COLUMNS+' FOR XML PATH(''tr''),type))' 


 
/*将表内数据插入到结果集字符串中*/
exec sys.sp_executesql @COLUMNS,N'@TBNAME VARCHAR(100), @COLUMNS nVARCHAR(MAX) OUTPUT',@TBNAME, @COLUMNS OUTPUT

/*拼接字符串结果集*/ 
SELECT @SQLSTR=@SQLSTR+ @COLUMNS+ N'</table>'

--SELECT @SQLSTR
 
exec msdb.dbo.sp_send_dbmail
	 @profile_name	= @profile_name, --@profile_name
	 @recipients	= @recipients, --'renfc@gildata.com;zhengyue@gildata.com', 
	 @copy_recipients = @copy_recipients,
	 @subject		= @Title,
	 @body			= @SQLSTR,
	 @body_format	= 'HTML';
