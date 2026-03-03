
USE tempdb;
IF OBJECT_ID('dbo.uspLogEvent') IS NULL EXEC('CREATE PROCEDURE dbo.uspLogEvent @Message NVARCHAR(4000) AS BEGIN SET NOCOUNT ON; END');
IF OBJECT_ID('dbo.usp_CallExternalService') IS NULL EXEC('CREATE PROCEDURE dbo.usp_CallExternalService @Endpoint NVARCHAR(2000), @Payload NVARCHAR(MAX) AS BEGIN SET NOCOUNT ON; END');
IF OBJECT_ID('dbo.usp_Segment_F3') IS NOT NULL DROP PROCEDURE dbo.usp_Segment_F3;
GO
CREATE PROCEDURE dbo.usp_Segment_F3 @Country NVARCHAR(10)=NULL AS
BEGIN
  SET NOCOUNT ON;
  IF OBJECT_ID('tempdb..#Cust') IS NOT NULL DROP TABLE #Cust; IF OBJECT_ID('tempdb..#Seg') IS NOT NULL DROP TABLE #Seg;
  CREATE TABLE #Cust(CustomerId INT,Country NVARCHAR(10),Spend DECIMAL(18,2),Orders INT,LastAt DATETIME2);
  CREATE TABLE #Seg(CustomerId INT PRIMARY KEY,Tier NVARCHAR(20),Score DECIMAL(18,2));
  INSERT INTO #Cust VALUES(1,N'IN',11000,40,DATEADD(DAY,-3,SYSUTCDATETIME())),(2,N'US',4200,9,DATEADD(DAY,-40,SYSUTCDATETIME())),(3,N'GB',6200,16,DATEADD(DAY,-12,SYSUTCDATETIME()));
  ;WITH B AS(SELECT CustomerId,Spend,Orders,CASE WHEN Spend>=10000 THEN N'Platinum' WHEN Spend>=5000 THEN N'Gold' WHEN Spend>=1000 THEN N'Silver' ELSE N'Bronze' END AS Tier FROM #Cust WHERE @Country IS NULL OR Country=@Country),
  S AS(SELECT CustomerId,Tier,CAST(ROUND((Spend/NULLIF(Orders,0))*CASE Tier WHEN N'Platinum' THEN 1.25 WHEN N'Gold' THEN 1.15 WHEN N'Silver' THEN 1.05 ELSE 1.00 END,2) AS DECIMAL(18,2)) AS Score FROM B)
  MERGE #Seg AS T USING S AS X ON T.CustomerId=X.CustomerId
  WHEN MATCHED THEN UPDATE SET T.Tier=X.Tier,T.Score=X.Score
  WHEN NOT MATCHED BY TARGET THEN INSERT(CustomerId,Tier,Score) VALUES(X.CustomerId,X.Tier,X.Score)
  WHEN NOT MATCHED BY SOURCE THEN DELETE;
  EXEC dbo.uspLogEvent @Message=N'Segmented';
  EXEC dbo.usp_CallExternalService @Endpoint=N'https://example.com/api/segments',@Payload=N'{"event":"segments_updated"}';
  SELECT * FROM #Seg ORDER BY Tier DESC,Score DESC;
  SELECT 1 AS Snippets_Count,1 AS Service_Calls_Count,2 AS DB_Calls_Count,1 AS Callees_Count,2 AS Decision_Node_Count,3 AS Calculations_Count;
END
GO
EXEC dbo.usp_Segment_F3 @Country=NULL;
GO
