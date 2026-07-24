USE  AdventureWorks_DW;
GO

--------------------------------------------------
-- 0. Create Gold Schema
--------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'gold')
BEGIN
    EXEC('CREATE SCHEMA gold');
END
GO
 
--------------------------------------------------
-- 1. DimProduct
--------------------------------------------------
DROP VIEW IF EXISTS gold.DimProduct;
GO

CREATE VIEW gold.DimProduct AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY p.ProductID) AS SK_Product, 
    p.ProductID,
    p.Name AS ProductName,
    p.ProductNumber,
    p.Color AS ProductColor,
    p.Size,
    p.Weight,
    p.ProductLine,
    p.Class,
    p.Style,
    p.StandardCost,
    p.ListPrice,
    COALESCE(ps.Name, 'N/A') AS SubcategoryName,
    COALESCE(pc.Name, 'N/A') AS CategoryName,
    GETDATE() AS StartDate,
    NULL AS EndDate,
    1 AS IsCurrent
FROM silver.Product p
LEFT JOIN silver.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN silver.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID;
GO

--------------------------------------------------
-- 2. DimCustomer
--------------------------------------------------
DROP VIEW IF EXISTS gold.DimCustomer;
GO

CREATE VIEW gold.DimCustomer AS
SELECT
ROW_NUMBER() OVER (ORDER BY c.CustomerID) AS SK_Customer,
    c.CustomerID,
    c.PersonID,
    c.StoreID,
    c.TerritoryID,
    c.AccountNumber,
    COALESCE(p.FirstName + ' ' + ISNULL(p.LastName, ''), s.Name, 'Unknown') AS CustomerName,
    COALESCE(s.Name, 'Individual Customer') AS StoreName,
    CASE 
        WHEN c.StoreID IS NOT NULL AND c.PersonID IS NOT NULL THEN 'Store & Individual'
        WHEN c.StoreID IS NOT NULL THEN 'Store'
        WHEN c.PersonID IS NOT NULL THEN 'Individual'
        ELSE 'Unknown'
    END AS CustomerType,
    GETDATE() AS StartDate,
    NULL AS EndDate,
    1 AS IsCurrent
FROM silver.Customer c
LEFT JOIN silver.Person p ON c.PersonID = p.BusinessEntityID
LEFT JOIN silver.Store s ON c.StoreID = s.BusinessEntityID;
GO

--------------------------------------------------
-- 3. DimGeography
--------------------------------------------------
DROP VIEW IF EXISTS gold.DimGeography;
GO

CREATE VIEW gold.DimGeography AS
SELECT 
ROW_NUMBER() OVER (ORDER BY a.AddressID) AS SK_Geography,
    a.AddressID,
    a.AddressLine1,
    a.AddressLine2,
    a.City,
    sp.StateProvinceID,
    sp.StateProvinceCode,
    COALESCE(sp.Name, 'Unknown') AS StateProvinceName,
    cr.CountryRegionCode,
    COALESCE(cr.Name, 'Unknown') AS CountryRegionName,
    st.TerritoryID,
    st.Name AS Territoryname,
    COALESCE(st.[GROUP], 'Unknown') AS TerritoryGroup
FROM silver.Address a
LEFT JOIN silver.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
LEFT JOIN silver.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode
LEFT JOIN silver.SalesTerritory st ON sp.TerritoryID = st.TerritoryID;
GO

--------------------------------------------------
-- 4. DimShipMethod
--------------------------------------------------
DROP VIEW IF EXISTS gold.DimShipMethod;
GO

CREATE VIEW gold.DimShipMethod AS
SELECT
ROW_NUMBER() OVER (ORDER BY ShipMethodID) AS SK_ShipMethod,
ShipMethodID,
Name AS ShipMethodName,
ShipBase,
ShipRate
FROM silver.ShipMethod;
GO

--------------------------------------------------
-- 5.DimCreditCard
--------------------------------------------------
DROP VIEW IF EXISTS gold.DimCreditCard;
GO

CREATE VIEW gold.DimCreditCard AS
SELECT
    ROW_NUMBER() OVER (ORDER BY CreditCardID) AS SK_CreditCard,
    CreditCardID,
    CardType,
    'XXXX-XXXX-XXXX-' + RIGHT(CardNumber, 4) AS CardNumberMasked,
    '**' AS ExpMonth,
    '****' AS ExpYear
FROM silver.CreditCard;
GO

--------------------------------------------------
-- 6. DimDate (Physical Table for Date Dimension)
--------------------------------------------------
IF OBJECT_ID('gold.DimDate', 'U') IS NOT NULL DROP TABLE gold.DimDate;

CREATE TABLE gold.DimDate (
    DateKey INT PRIMARY KEY,
    [Date] DATE,
    [Year] INT,
    [Quarter] INT,
    [Month] INT,
    MonthName NVARCHAR(20),
    [Day] INT,
    DayOfWeek INT,
    DayName NVARCHAR(20)
);

-- Populate DimDate (2010 to 2025)
DECLARE @StartDate DATE = '2010-01-01';
DECLARE @EndDate DATE = '2025-12-31';

WHILE @StartDate <= @EndDate
BEGIN
    INSERT INTO gold.DimDate (DateKey, [Date], [Year], [Quarter], [Month], MonthName, [Day], DayOfWeek, DayName)
    VALUES (
        CAST(CONVERT(VARCHAR(8), @StartDate, 112) AS INT),
        @StartDate,
        YEAR(@StartDate),
        DATEPART(QUARTER, @StartDate),
        MONTH(@StartDate),
        DATENAME(MONTH, @StartDate),
        DAY(@StartDate),
        DATEPART(WEEKDAY, @StartDate),
        DATENAME(WEEKDAY, @StartDate)
    );
    SET @StartDate = DATEADD(DAY, 1, @StartDate);
END;
GO

--------------------------------------------------
-- 7. FactSales
--------------------------------------------------
DROP VIEW IF EXISTS gold.FactSales;
GO

CREATE VIEW gold.FactSales AS
SELECT 
    sd.SalesOrderDetailID AS SalesDetailKey,
    sh.SalesOrderID AS OrderKey,
    CAST(CONVERT(VARCHAR(8), sh.OrderDate, 112) AS INT) AS OrderDateKey,
    CAST(CONVERT(VARCHAR(8), sh.DueDate, 112) AS INT) AS DueDateKey,
    CAST(CONVERT(VARCHAR(8), sh.ShipDate, 112) AS INT) AS ShipDateKey,
    dc.SK_Customer,
    dp.SK_Product,
    dg.SK_Geography AS ShipGeographyKey,
    dsm.SK_ShipMethod,
    dcc.SK_CreditCard,
 CASE 
     WHEN sh.OnlineOrderFlag = 1 THEN 'Online'
     ELSE 'Reseller / Store'
 END AS SalesChannel,
    sd.OrderQty AS OrderQuantity,
    sd.UnitPrice,
    sd.UnitPriceDiscount,
    sd.LineTotal,
    sh.SubTotal AS OrderSubTotal,
    sh.TaxAmt AS TaxAmount,
    sh.Freight

FROM silver.SalesOrderHeader sh
INNER JOIN silver.SalesOrderDetail sd
    ON sh.SalesOrderID = sd.SalesOrderID

INNER JOIN gold.DimCustomer dc
    ON sh.CustomerID = dc.CustomerID

INNER JOIN gold.DimProduct dp
    ON sd.ProductID = dp.ProductID

INNER JOIN gold.DimGeography dg
    ON sh.ShipToAddressID = dg.AddressID

INNER JOIN gold.DimShipMethod dsm
    ON sh.ShipMethodID = dsm.ShipMethodID

LEFT JOIN gold.DimCreditCard dcc
    ON sh.CreditCardID = dcc.CreditCardID;
GO

--------------------------------------------------
-- 8. Data Validation & Row Count Check
--------------------------------------------------
SELECT 'Bronze Sales Details' AS Layer, COUNT(*) AS Row_Count FROM bronze.SalesOrderDetail
UNION ALL
SELECT 'Silver Sales Details', COUNT(*) FROM silver.SalesOrderDetail
UNION ALL
SELECT 'Gold FactSales Rows', COUNT(*) FROM gold.FactSales;
GO

