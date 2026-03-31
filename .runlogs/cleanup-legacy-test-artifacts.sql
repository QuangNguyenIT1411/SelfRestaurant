SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;

USE RESTAURANT;
BEGIN TRANSACTION;

DECLARE @CustomerTests TABLE (CustomerID INT PRIMARY KEY);
INSERT INTO @CustomerTests(CustomerID)
SELECT CustomerID
FROM dbo.Customers
WHERE Username LIKE 'dbg[_]%' OR Username LIKE 'codex[_]%' OR Email LIKE 'dbg[_]%' OR Email LIKE 'codex[_]%';

DELETE prt FROM dbo.PasswordResetTokens prt JOIN @CustomerTests x ON x.CustomerID = prt.CustomerID;
DELETE lc FROM dbo.LoyaltyCards lc JOIN @CustomerTests x ON x.CustomerID = lc.CustomerID;
DELETE c FROM dbo.Customers c JOIN @CustomerTests x ON x.CustomerID = c.CustomerID;

DELETE FROM dbo.OrderItemIngredients;
DELETE FROM dbo.Payments;
DELETE FROM dbo.Bills;
DELETE FROM dbo.OrderItems;
DELETE FROM dbo.Orders;

DELETE di
FROM dbo.DishIngredients di
JOIN dbo.Ingredients i ON i.IngredientID = di.IngredientID
WHERE i.Name LIKE 'AUTO%' OR i.Name LIKE 'DBG[_]%' OR i.Name LIKE 'CODEX[_]%';

DELETE oi
FROM dbo.OrderItemIngredients oi
JOIN dbo.Ingredients i ON i.IngredientID = oi.IngredientID
WHERE i.Name LIKE 'AUTO%' OR i.Name LIKE 'DBG[_]%' OR i.Name LIKE 'CODEX[_]%';

DELETE cd
FROM dbo.CategoryDish cd
JOIN dbo.Dishes d ON d.DishID = cd.DishID
WHERE d.Name LIKE 'AUTO%' OR d.Name LIKE 'DBG[_]%' OR d.Name LIKE 'CODEX[_]%';

DELETE di
FROM dbo.DishIngredients di
JOIN dbo.Dishes d ON d.DishID = di.DishID
WHERE d.Name LIKE 'AUTO%' OR d.Name LIKE 'DBG[_]%' OR d.Name LIKE 'CODEX[_]%';

DELETE oi
FROM dbo.OrderItems oi
JOIN dbo.Dishes d ON d.DishID = oi.DishID
WHERE d.Name LIKE 'AUTO%' OR d.Name LIKE 'DBG[_]%' OR d.Name LIKE 'CODEX[_]%';

DELETE FROM dbo.Dishes
WHERE Name LIKE 'AUTO%' OR Name LIKE 'DBG[_]%' OR Name LIKE 'CODEX[_]%';

DELETE FROM dbo.MenuCategory
WHERE CategoryID IN (
  SELECT CategoryID FROM dbo.Categories WHERE Name LIKE 'AUTO%' OR Name LIKE 'DBG[_]%' OR Name LIKE 'CODEX[_]%'
);

DELETE FROM dbo.Categories
WHERE Name LIKE 'AUTO%' OR Name LIKE 'DBG[_]%' OR Name LIKE 'CODEX[_]%';

DELETE FROM dbo.Ingredients
WHERE Name LIKE 'AUTO%' OR Name LIKE 'DBG[_]%' OR Name LIKE 'CODEX[_]%';

DELETE FROM dbo.Employees
WHERE Username LIKE 'AUTO%' OR Username LIKE 'DBG[_]%' OR Username LIKE 'CODEX[_]%'
   OR Email LIKE 'AUTO%' OR Email LIKE 'DBG[_]%' OR Email LIKE 'CODEX[_]%'
   OR Name LIKE 'AUTO%';

COMMIT TRANSACTION;
