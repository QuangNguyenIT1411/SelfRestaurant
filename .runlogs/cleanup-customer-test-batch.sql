SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;

USE RESTAURANT;
BEGIN TRANSACTION;

DECLARE @Kill TABLE (CustomerID INT PRIMARY KEY);
INSERT INTO @Kill(CustomerID)
SELECT CustomerID
FROM dbo.Customers
WHERE Username LIKE 'AUTO%'
   OR Username LIKE 'DBG%'
   OR Username LIKE 'CODEX%'
   OR Username LIKE 'CUSD[_]%'
   OR Username LIKE 'PROBE%'
   OR Username LIKE 'MENUCHECK%'
   OR Username LIKE 'KH20%'
   OR Username LIKE 'FLOW%'
   OR Username LIKE 'CUST%'
   OR Username LIKE 'TESTUSER%'
   OR Email LIKE 'AUTO%'
   OR Email LIKE 'DBG%'
   OR Email LIKE 'CODEX%'
   OR Email LIKE 'CUSD[_]%'
   OR Email LIKE 'PROBE%'
   OR Email LIKE 'MENUCHECK%'
   OR Email LIKE '%example.local%'
   OR Email LIKE '%local.dev%'
   OR Email LIKE '%example.com%'
   OR Name LIKE 'Auto %'
   OR Name LIKE 'Dbg %'
   OR Name LIKE 'Codex %'
   OR Name LIKE '%Test%'
   OR Name LIKE 'Flow %'
   OR Name LIKE 'OrderTest';

DELETE prt FROM dbo.PasswordResetTokens prt JOIN @Kill k ON k.CustomerID = prt.CustomerID;
DELETE lc FROM dbo.LoyaltyCards lc JOIN @Kill k ON k.CustomerID = lc.CustomerID;
DELETE c FROM dbo.Customers c JOIN @Kill k ON k.CustomerID = c.CustomerID;

COMMIT TRANSACTION;

SELECT COUNT(*) AS RemainingSuspects
FROM dbo.Customers
WHERE Username LIKE 'AUTO%'
   OR Username LIKE 'DBG%'
   OR Username LIKE 'CODEX%'
   OR Username LIKE 'CUSD[_]%'
   OR Username LIKE 'PROBE%'
   OR Username LIKE 'MENUCHECK%'
   OR Username LIKE 'KH20%'
   OR Username LIKE 'FLOW%'
   OR Username LIKE 'CUST%'
   OR Username LIKE 'TESTUSER%'
   OR Email LIKE 'AUTO%'
   OR Email LIKE 'DBG%'
   OR Email LIKE 'CODEX%'
   OR Email LIKE 'CUSD[_]%'
   OR Email LIKE 'PROBE%'
   OR Email LIKE 'MENUCHECK%'
   OR Email LIKE '%example.local%'
   OR Email LIKE '%local.dev%'
   OR Email LIKE '%example.com%'
   OR Name LIKE 'Auto %'
   OR Name LIKE 'Dbg %'
   OR Name LIKE 'Codex %'
   OR Name LIKE '%Test%'
   OR Name LIKE 'Flow %'
   OR Name LIKE 'OrderTest';
