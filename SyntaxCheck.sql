
 IF EXISTS (SELECT * FROM tempdb.dbo.sysobjects o WHERE o.xtype in ('U') and o.id = object_id(N'tempdb..#tempIdentityTables'))
 DROP TABLE #tempIdentityTables
 
CREATE TABLE #tempIdentityTables(
 id int not null,
 name [varchar](255) NOT NULL,
 identOn int default (0),
 ansiNullOn int default (0),
 [owner] VARCHAR(255),
 [objectType] VARCHAR(255),
 [createdDate] datetime,
 [definition] VARCHAR(MAX), --definition
 command VARCHAR(MAX), --definition
 results VARCHAR(MAX),
 processed int default (0),
 )
 

 insert into #tempIdentityTables (id, name, identOn, ansiNullOn, [owner], [objectType], [createdDate], [definition])
 select
 o.id,
 o.name,
 OBJECTPROPERTY(id, 'ExecIsQuotedIdentOn') as quoted_ident_on,
 OBJECTPROPERTY(id, 'ExecIsAnsiNullsOn') as ansi_nulls_on,
 user_name(o.uid) owner ,
 --o.type,
 pr.type_desc ,
 pr.create_date ,
 mod.definition
 from sysobjects o
 INNER JOIN sys.sql_modules mod ON o.id = mod.object_id
 inner join
 ( select object_id, name, type_desc,create_date from sys.views
 union
 select object_id, name, type_desc,create_date from sys.procedures
 union
 SELECT object_id, name, type_desc,create_date FROM sys.objects WHERE type IN ('FN', 'IF', 'TF', 'TR') -- scalar, inline table-valued, table-valued, trigger
 ) as pr on pr.object_id = o.id
 where category = 0
 

 DECLARE @id int
 DECLARE @name VARCHAR(255)
 DECLARE @owner VARCHAR(255)
 DECLARE @identOn int
 DECLARE @ansiNullOn int
 DECLARE @SQL VARCHAR(MAX)
 DECLARE @definition VARCHAR(MAX)
 --set start condition cycle
 SELECT TOP 1 @id = id, @name = name , @owner = [owner], @identOn = identOn, @ansiNullOn = ansiNullOn, @definition =[definition] FROM #tempIdentityTables WHERE processed = 0
 
WHILE @id IS NOT NULL
 BEGIN
 set @SQL = ''
 

 SELECT @SQL = @SQL +'SET FMTONLY ON ' + CHAR(13)+CHAR(10)

 
SELECT @SQL = @SQL + ' EXECUTE ('' '+ REPLACE(@definition,'''', '''''') +' '')' + CHAR(13)+CHAR(10)
 

 update #tempIdentityTables
 set command = @SQL, processed = 1
 where #tempIdentityTables.id = @id
 

 set @id = null;
 SELECT TOP 1 @id = id, @name = name , @owner = [owner], @identOn = identOn, @ansiNullOn = ansiNullOn, @definition =[definition] FROM #tempIdentityTables WHERE processed = 0
 
END
 
-- run actual queries
 DECLARE @loopId int
 DECLARE @ExecSQL NVARCHAR(MAX)
 DECLARE @procName VARCHAR(255) = null
 DECLARE @objectType VARCHAR(255) = null
 
set @id = null
 select top 1 @loopId = id, @ExecSQL = command, @procName = name, @objectType = objectType from #tempIdentityTables where processed = 0 OR processed = -1 OR processed = 1
 
WHILE @loopId IS NOT NULL
 BEGIN
 
BEGIN TRY
 print 'Checking: ' + @procName
 EXEC sp_executesql @ExecSQL
 
update #tempIdentityTables
 set processed = 2
 where #tempIdentityTables.id = @loopId
 END TRY
 BEGIN CATCH
 
DECLARE @Failure varchar(MAX) = ''
 select @Failure = ERROR_MESSAGE();
 print 'Error detected: ' + @Failure
 update #tempIdentityTables
 set processed = -2,
 results = @Failure
 where #tempIdentityTables.id = @loopId
 END CATCH;
 

 set @loopId = null;
 select top 1 @loopId = id, @ExecSQL = command, @procName = name, @objectType = objectType from #tempIdentityTables where processed = 0 OR processed = -1 OR processed = 1
 
END
 -- results returned are queries with errors
 select name, owner, results, objectType from #tempIdentityTables where results is not null

 drop table #tempIdentityTables