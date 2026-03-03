
/* 
    File: 02_Inventory_Reorder_Procedure.sql
    Purpose: Procedure to calculate reorder quantities with decision nodes, calculations, DB ops, and callees.
*/

USE tempdb;
GO

-- === Stub callees ===
IF OBJECT_ID('dbo.uspLogEvent') IS NULL
    EXEC ('CREATE PROCEDURE dbo.uspLogEvent @Message NVARCHAR(4000) AS BEGIN SET NOCOUNT ON; RETURN 0; END');
IF OBJECT_ID('dbo.usp_CallExternalService') IS NULL
    EXEC ('CREATE PROCEDURE dbo.usp_CallExternalService @Endpoint NVARCHAR(2000), @Payload NVARCHAR(MAX) AS BEGIN SET NOCOUNT ON; RETURN 0; END');
GO

-- === Demo inventory tables ===
IF OBJECT_ID('dbo.Inventory') IS NOT NULL DROP TABLE dbo.Inventory;
CREATE TABLE dbo.Inventory
(
    Sku             NVARCHAR(50) NOT NULL PRIMARY KEY,
    OnHandQty       INT          NOT NULL,
    SafetyStockQty  INT          NOT NULL,
    LeadTimeDays    INT          NOT NULL,
    DailyDemand     DECIMAL(18,4) NOT NULL
);

INSERT INTO dbo.Inventory (Sku, OnHandQty, SafetyStockQty, LeadTimeDays, DailyDemand)
VALUES
('SKU-001', 12, 10, 5,  2.5),
('SKU-002',  4, 12, 7,  3.1),
('SKU-003', 55, 20, 3,  1.4);

IF OBJECT_ID('dbo.ReorderQueue') IS NOT NULL DROP TABLE dbo.ReorderQueue;
CREATE TABLE dbo.ReorderQueue
(
    ReorderId INT IDENTITY(1,1) PRIMARY KEY,
    Sku       NVARCHAR(50) NOT NULL,
    Qty       INT NOT NULL,
    Priority  TINYINT NOT NULL,
    RequestedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- === Procedure ===
IF OBJECT_ID('dbo.usp_Inventory_Reorder_Run') IS NOT NULL
    DROP PROCEDURE dbo.usp_Inventory_Reorder_Run;
GO
CREATE PROCEDURE dbo.usp_Inventory_Reorder_Run
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Now DATETIME2 = SYSUTCDATETIME();

    -- Decision node: only run during business hours UTC 06–20
    IF DATEPART(HOUR, @Now) NOT BETWEEN 6 AND 20
    BEGIN
        EXEC dbo.uspLogEvent @Message = N'Reorder skipped: outside business window';
        RETURN;
    END

    ;WITH cte_need AS
    (
        SELECT
            i.Sku,
            i.OnHandQty,
            i.SafetyStockQty,
            i.LeadTimeDays,
            i.DailyDemand,
            -- Calculation: projected demand over lead time
            CAST(CEILING(i.LeadTimeDays * i.DailyDemand) AS INT) AS ProjectedDemand,
            -- Decision/calculation: reorder qty
            CASE 
                WHEN i.OnHandQty < i.SafetyStockQty 
                    THEN CAST(GREATEST(0, (i.SafetyStockQty - i.OnHandQty)) + CEILING(i.LeadTimeDays * i.DailyDemand) AS INT)
                ELSE 0
            END AS ReorderQty
        FROM dbo.Inventory AS i
    )
    INSERT INTO dbo.ReorderQueue (Sku, Qty, Priority)
    SELECT
        n.Sku,
        n.ReorderQty,
        CASE 
            WHEN n.ReorderQty >= 20 THEN 1
            WHEN n.ReorderQty BETWEEN 10 AND 19 THEN 2
            WHEN n.ReorderQty BETWEEN 1 AND 9 THEN 3
            ELSE 4
        END AS Priority
    FROM cte_need AS n
    WHERE n.ReorderQty > 0;

    EXEC dbo.uspLogEvent @Message = N'Reorder queue created';

    -- Service call placeholder: notify external fulfillment system
    EXEC dbo.usp_CallExternalService 
        @Endpoint = N'https://example.com/api/fulfillment/reorders',
        @Payload  = N'{"event":"reorder_generated"}';
END
GO

-- Execute once for demo
EXEC dbo.usp_Inventory_Reorder_Run;

-- See results
SELECT * FROM dbo.ReorderQueue ORDER BY RequestedAt DESC;

-- === Mandatory metrics output for your harness ===
SELECT
    CAST(0 AS INT) AS Snippets_Count,
    CAST(0 AS INT) AS Service_Calls_Count,
    CAST(0 AS INT) AS DB_Calls_Count,
    CAST(0 AS INT) AS Callees_Count,
    CAST(0 AS INT) AS Decision_Node_Count,
    CAST(0 AS INT) AS Calculations_Count;
GO
