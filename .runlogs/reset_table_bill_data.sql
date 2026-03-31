USE [RESTAURANT];
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRAN;

DECLARE @availableStatusId INT = (
    SELECT TOP (1) StatusID
    FROM dbo.TableStatus
    WHERE UPPER(StatusCode) = 'AVAILABLE'
    ORDER BY StatusID
);

IF @availableStatusId IS NULL
BEGIN
    SET @availableStatusId = 1;
END;

-- Xoa du lieu giao dich lien quan don/bill
DELETE FROM dbo.OrderItemIngredients;
DELETE FROM dbo.Bills;
DELETE FROM dbo.Payments;
DELETE FROM dbo.OrderItems;
DELETE FROM dbo.Orders;

-- Reset trang thai ban
UPDATE dbo.DiningTables
SET CurrentOrderID = NULL,
    StatusID = @availableStatusId,
    UpdatedAt = GETDATE();

-- Reseed identity ve tu dau (ban ghi tiep theo = 1)
DBCC CHECKIDENT ('dbo.OrderItemIngredients', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Bills', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Payments', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.OrderItems', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.Orders', RESEED, 0) WITH NO_INFOMSGS;

COMMIT;

SELECT
    (SELECT COUNT(*) FROM dbo.Orders) AS OrdersCount,
    (SELECT COUNT(*) FROM dbo.OrderItems) AS OrderItemsCount,
    (SELECT COUNT(*) FROM dbo.OrderItemIngredients) AS OrderItemIngredientsCount,
    (SELECT COUNT(*) FROM dbo.Bills) AS BillsCount,
    (SELECT COUNT(*) FROM dbo.Payments) AS PaymentsCount,
    (SELECT COUNT(*) FROM dbo.DiningTables WHERE CurrentOrderID IS NOT NULL) AS TablesWithCurrentOrder,
    (SELECT COUNT(*) FROM dbo.DiningTables WHERE StatusID <> @availableStatusId) AS NonAvailableTables;
