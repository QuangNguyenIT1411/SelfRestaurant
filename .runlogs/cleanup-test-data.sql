SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;

USE RESTAURANT;
BEGIN TRANSACTION;

DECLARE @TestCustomers TABLE (CustomerID INT PRIMARY KEY);
INSERT INTO @TestCustomers(CustomerID)
SELECT CustomerID
FROM dbo.Customers
WHERE Username LIKE 'cusd[_]%';

DELETE prt
FROM dbo.PasswordResetTokens prt
JOIN @TestCustomers tc ON tc.CustomerID = prt.CustomerID;

DELETE lc
FROM dbo.LoyaltyCards lc
JOIN @TestCustomers tc ON tc.CustomerID = lc.CustomerID;

DELETE c
FROM dbo.Customers c
JOIN @TestCustomers tc ON tc.CustomerID = c.CustomerID;

DELETE oi
FROM dbo.OrderItems oi
JOIN dbo.Dishes d ON d.DishID = oi.DishID
WHERE d.Name LIKE 'AUTO_ADMIN_TEST[_]%';

DELETE cd
FROM dbo.CategoryDish cd
JOIN dbo.Dishes d ON d.DishID = cd.DishID
WHERE d.Name LIKE 'AUTO_ADMIN_TEST[_]%';

DELETE di
FROM dbo.DishIngredients di
JOIN dbo.Dishes d ON d.DishID = di.DishID
WHERE d.Name LIKE 'AUTO_ADMIN_TEST[_]%';

DELETE FROM dbo.Dishes
WHERE Name LIKE 'AUTO_ADMIN_TEST[_]%';

DELETE FROM dbo.Bills;
DELETE FROM dbo.OrderItemIngredients;
DELETE FROM dbo.Payments;
DELETE FROM dbo.OrderItems;
DELETE FROM dbo.Orders;

COMMIT TRANSACTION;

USE RESTAURANT_ORDERS;
IF OBJECT_ID('dbo.OrderItems', 'U') IS NOT NULL DELETE FROM dbo.OrderItems;
IF OBJECT_ID('dbo.Orders', 'U') IS NOT NULL DELETE FROM dbo.Orders;
IF OBJECT_ID('dbo.InboxEvents', 'U') IS NOT NULL DELETE FROM dbo.InboxEvents;
IF OBJECT_ID('dbo.OutboxEvents', 'U') IS NOT NULL DELETE FROM dbo.OutboxEvents;

USE RESTAURANT_BILLING;
IF OBJECT_ID('dbo.Bills', 'U') IS NOT NULL DELETE FROM dbo.Bills;
IF OBJECT_ID('dbo.OutboxEvents', 'U') IS NOT NULL DELETE FROM dbo.OutboxEvents;

USE RESTAURANT_CUSTOMERS;
IF OBJECT_ID('dbo.ReadyDishNotifications', 'U') IS NOT NULL DELETE FROM dbo.ReadyDishNotifications;
IF OBJECT_ID('dbo.InboxEvents', 'U') IS NOT NULL DELETE FROM dbo.InboxEvents;
