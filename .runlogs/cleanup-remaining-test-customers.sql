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
WHERE Username LIKE 'AUTO%'
   OR Username LIKE 'DBG[_]%'
   OR Username LIKE 'CODEX[_]%'
   OR Email LIKE 'AUTO%'
   OR Email LIKE 'DBG[_]%'
   OR Email LIKE 'CODEX[_]%';

DELETE prt FROM dbo.PasswordResetTokens prt JOIN @CustomerTests x ON x.CustomerID = prt.CustomerID;
DELETE lc FROM dbo.LoyaltyCards lc JOIN @CustomerTests x ON x.CustomerID = lc.CustomerID;
DELETE c FROM dbo.Customers c JOIN @CustomerTests x ON x.CustomerID = c.CustomerID;

COMMIT TRANSACTION;
