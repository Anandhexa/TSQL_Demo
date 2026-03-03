
USE tempdb;
GO

IF OBJECT_ID('dbo.uspLogEvent') IS NULL
    EXEC('CREATE PROCEDURE dbo.uspLogEvent @Message NVARCHAR(4000) AS BEGIN SET NOCOUNT ON; END');
IF OBJECT_ID('dbo.usp_CallExternalService') IS NULL
    EXEC('CREATE PROCEDURE dbo.usp_CallExternalService @Endpoint NVARCHAR(2000), @Payload NVARCHAR(MAX) AS BEGIN SET NOCOUNT ON; END');

IF OBJECT_ID('dbo.Orders_B1') IS NOT NULL DROP TABLE dbo.Orders_B1;
CREATE TABLE dbo.Orders_B1
(
    OrderId INT PRIMARY KEY,
    CustomerId INT NOT NULL,
    Qty INT NOT NULL,
    UnitPrice DECIMAL(18,2) NOT NULL,
    Status NVARCHAR(20) NOT NULL DEFAULT N'NEW',
    NetAmount DECIMAL(18,2) NULL
);

INSERT INTO dbo.Orders_B1(OrderId, CustomerId, Qty, UnitPrice) VALUES
(101, 9001, 4, 120.00),
(102, 9002, 1, 300.00);

IF OBJECT_ID('dbo.usp_Process_Order_B1') IS NOT NULL DROP PROCEDURE dbo.usp_Process_Order_B1;
GO
CREATE PROCEDURE dbo.usp_Process_Order_B1
    @OrderId INT,
    @Notify BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @OrderId IS NULL
    BEGIN
        EXEC dbo.uspLogEvent @Message = N'OrderId missing';
        RAISERROR('OrderId required',16,1);
        RETURN;
    END

    DECLARE @Qty INT, @UnitPrice DECIMAL(18,2), @Gross DECIMAL(18,2), @Discount DECIMAL(5,2), @Net DECIMAL(18,2);

    SELECT @Qty = Qty, @UnitPrice = UnitPrice FROM dbo.Orders_B1 WHERE OrderId = @OrderId;
    IF @@ROWCOUNT = 0
    BEGIN
        EXEC dbo.uspLogEvent @Message = N'Order not found';
        RAISERROR('Order not found',16,1);
        RETURN;
    END

    SET @Gross = @Qty * @UnitPrice;
    SET @Discount = CASE WHEN @Qty >= 10 THEN 0.15 WHEN @Qty >= 5 THEN 0.08 WHEN @Qty >= 3 THEN 0.05 ELSE 0.00 END;
    SET @Net = @Gross * (1 - @Discount);

    IF @Net >= 400
        UPDATE dbo.Orders_B1 SET NetAmount = @Net, Status = N'PRIORITY' WHERE OrderId = @OrderId;
    ELSE
        UPDATE dbo.Orders_B1 SET NetAmount = @Net, Status = N'CONFIRMED' WHERE OrderId = @OrderId;

    EXEC dbo.uspLogEvent @Message = N'Order processed';

    IF @Notify = 1
        EXEC dbo.usp_CallExternalService @Endpoint = N'https://example.com/api/order', @Payload = N'{"event":"updated"}';

    SELECT * FROM dbo.Orders_B1 WHERE OrderId = @OrderId;

    SELECT
        CAST(1 AS INT) AS Snippets_Count,
        CAST(1 AS INT) AS Service_Calls_Count,
        CAST(3 AS INT) AS DB_Calls_Count,
        CAST(1 AS INT) AS Callees_Count,
        CAST(3 AS INT) AS Decision_Node_Count,
        CAST(3 AS INT) AS Calculations_Count;
END
GO

EXEC dbo.usp_Process_Order_B1 @OrderId = 101, @Notify = 1;
GO
