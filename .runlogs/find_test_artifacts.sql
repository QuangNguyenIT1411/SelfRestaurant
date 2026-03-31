SET NOCOUNT ON;
DECLARE @pattern NVARCHAR(100) = 'AUTO%';
DECLARE @sql NVARCHAR(MAX) = N'';

;WITH cols AS (
    SELECT
        s.name AS schema_name,
        t.name AS table_name,
        c.name AS column_name,
        ty.name AS type_name
    FROM sys.tables t
    JOIN sys.schemas s ON s.schema_id = t.schema_id
    JOIN sys.columns c ON c.object_id = t.object_id
    JOIN sys.types ty ON ty.user_type_id = c.user_type_id
    WHERE ty.name IN ('varchar','nvarchar','char','nchar','text','ntext')
)
SELECT @sql = STRING_AGG(CAST(
    'BEGIN TRY IF EXISTS (SELECT 1 FROM ' + QUOTENAME(schema_name) + '.' + QUOTENAME(table_name) + ' WHERE ' + QUOTENAME(column_name) + ' LIKE ''' + @pattern + ''') ' +
    'SELECT DB_NAME() AS DbName, ''' + schema_name + '.' + table_name + ''' AS TableName, ''' + column_name + ''' AS ColumnName, COUNT(*) AS HitCount FROM ' + QUOTENAME(schema_name) + '.' + QUOTENAME(table_name) + ' WHERE ' + QUOTENAME(column_name) + ' LIKE ''' + @pattern + '''; END TRY BEGIN CATCH END CATCH;'
AS NVARCHAR(MAX)), CHAR(10))
FROM cols;

EXEC sp_executesql @sql;
