
USE tempdb;
IF OBJECT_ID('dbo.uspLogEvent') IS NULL EXEC('CREATE PROCEDURE dbo.uspLogEvent @Message NVARCHAR(4000) AS BEGIN SET NOCOUNT ON; END');
IF OBJECT_ID('dbo.usp_CallExternalService') IS NULL EXEC('CREATE PROCEDURE dbo.usp_CallExternalService @Endpoint NVARCHAR(2000), @Payload NVARCHAR(MAX) AS BEGIN SET NOCOUNT ON; END');
IF OBJECT_ID('dbo.usp_Gen_Reorders_F2') IS NOT NULL DROP PROCEDURE dbo.usp_Gen_Reorders_F2;
GO
CREATE PROCEDURE dbo.usp_Gen_Reorders_F2 @RunMode NVARCHAR(10)=N'NORMAL' AS
BEGIN
  SET NOCOUNT ON;
  IF OBJECT_ID('tempdb..#Inv') IS NOT NULL DROP TABLE #Inv; IF OBJECT_ID('tempdb..#Queue') IS NOT NULL DROP TABLE #Queue;
  CREATE TABLE #Inv(Sku NVARCHAR(20),OnHand INT,Safety INT,Lead INT,Demand DECIMAL(18,4));
  CREATE TABLE #Queue(Sku NVARCHAR(20),Qty INT,Priority TINYINT,At DATETIME2 DEFAULT SYSUTCDATETIME());
  INSERT INTO #Inv VALUES(N'A',5,10,7,2.1),(N'B',25,12,5,1.2),(N'C',3,15,6,3.0);
  IF DATEPART(HOUR,SYSUTCDATETIME()) NOT BETWEEN 6 AND 20 BEGIN EXEC dbo.uspLogEvent @Message=N'Outside window'; RETURN; END
  ;WITH N AS(SELECT Sku,CAST(CEILING(Lead*Demand) AS INT) AS Proj,CASE WHEN OnHand<Safety THEN CAST(GREATEST(0,Safety-OnHand)+CEILING(Lead*Demand) AS INT) ELSE 0 END AS ReorderQty FROM #Inv)
  INSERT INTO #Queue(Sku,Qty,Priority)
  SELECT Sku,ReorderQty,CASE WHEN ReorderQty>=20 THEN 1 WHEN ReorderQty BETWEEN 10 AND 19 THEN 2 WHEN ReorderQty BETWEEN 1 AND 9 THEN 3 ELSE 4 END
  FROM N WHERE ReorderQty>0 AND @RunMode<>N'DRYRUN';
  IF @RunMode=N'DRYRUN' EXEC dbo.uspLogEvent @Message=N'Dry run' ELSE EXEC dbo.uspLogEvent @Message=N'Queued';
  EXEC dbo.usp_CallExternalService @Endpoint=N'https://example.com/api/reorder',@Payload=N'{"event":"ready"}';
  SELECT * FROM #Queue ORDER BY At DESC;
  SELECT 1 AS Snippets_Count,1 AS Service_Calls_Count,2 AS DB_Calls_Count,1 AS Callees_Count,3 AS Decision_Node_Count,3 AS Calculations_Count;
END
GO
EXEC dbo.usp_Gen_Reorders_F2 @RunMode=N'NORMAL';
GO