SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.Orders', N'SN') IS NOT NULL
    DROP SYNONYM dbo.Orders;
IF OBJECT_ID(N'dbo.OrderItems', N'SN') IS NOT NULL
    DROP SYNONYM dbo.OrderItems;
IF OBJECT_ID(N'dbo.OrderStatus', N'SN') IS NOT NULL
    DROP SYNONYM dbo.OrderStatus;

IF OBJECT_ID(N'dbo.OrderStatus', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.OrderStatus
    (
        StatusID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        StatusCode VARCHAR(50) NOT NULL,
        StatusName NVARCHAR(100) NOT NULL
    );
    CREATE UNIQUE INDEX UX_OrderStatus_StatusCode ON dbo.OrderStatus(StatusCode);
END

IF OBJECT_ID(N'dbo.Orders', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Orders
    (
        OrderID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        OrderCode VARCHAR(50) NULL,
        OrderTime DATETIME NOT NULL CONSTRAINT DF_Orders_OrderTime DEFAULT (GETDATE()),
        CompletedTime DATETIME NULL,
        Note NVARCHAR(1000) NULL,
        IsActive BIT NULL CONSTRAINT DF_Orders_IsActive DEFAULT (1),
        TableID INT NULL,
        CustomerID INT NULL,
        StatusID INT NOT NULL,
        CashierID INT NULL
    );
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Orders') AND name = N'UX_Orders_OrderCode')
BEGIN
    CREATE UNIQUE INDEX UX_Orders_OrderCode ON dbo.Orders(OrderCode) WHERE OrderCode IS NOT NULL;
END
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Orders') AND name = N'idx_orders_time')
BEGIN
    CREATE INDEX idx_orders_time ON dbo.Orders(OrderTime);
END
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Orders') AND name = N'idx_orders_status')
BEGIN
    CREATE INDEX idx_orders_status ON dbo.Orders(StatusID);
END
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Orders') AND name = N'idx_orders_table')
BEGIN
    CREATE INDEX idx_orders_table ON dbo.Orders(TableID);
END

IF OBJECT_ID(N'dbo.OrderItems', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.OrderItems
    (
        ItemID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        Quantity INT NOT NULL,
        UnitPrice DECIMAL(18,2) NOT NULL,
        LineTotal DECIMAL(18,2) NOT NULL,
        Note NVARCHAR(500) NULL,
        OrderID INT NOT NULL,
        DishID INT NOT NULL
    );
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.OrderItems') AND name = N'idx_orderitems_order')
BEGIN
    CREATE INDEX idx_orderitems_order ON dbo.OrderItems(OrderID);
END
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.OrderItems') AND name = N'idx_orderitems_dish')
BEGIN
    CREATE INDEX idx_orderitems_dish ON dbo.OrderItems(DishID);
END

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Orders_OrderStatus')
BEGIN
    ALTER TABLE dbo.Orders WITH NOCHECK
    ADD CONSTRAINT FK_Orders_OrderStatus FOREIGN KEY (StatusID) REFERENCES dbo.OrderStatus(StatusID);
END

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_OrderItems_Orders')
BEGIN
    ALTER TABLE dbo.OrderItems WITH NOCHECK
    ADD CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (OrderID) REFERENCES dbo.Orders(OrderID);
END
