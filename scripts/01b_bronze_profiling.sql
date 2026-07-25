USE AdventureWorks_DW;
GO

-- ===================================================================
-- TEST 1: DUPLICATE PRIMARY KEYS (should never happen in a clean OLTP
-- source, but bronze is untouched, so we verify rather than assume)
-- ===================================================================
SELECT 'Product' AS [Table], 'Duplicate ProductID' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM (SELECT ProductID FROM bronze.[Product] GROUP BY ProductID HAVING COUNT(*) > 1) d;

SELECT 'Customer' AS [Table], 'Duplicate CustomerID' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM (SELECT CustomerID FROM bronze.Customer GROUP BY CustomerID HAVING COUNT(*) > 1) d;

SELECT 'SalesOrderHeader' AS [Table], 'Duplicate SalesOrderID' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM (SELECT SalesOrderID FROM bronze.SalesOrderHeader GROUP BY SalesOrderID HAVING COUNT(*) > 1) d;
GO

-- ===================================================================
-- TEST 2: NEGATIVE OR ZERO VALUES IN BUSINESS-CRITICAL NUMERIC COLUMNS
-- ===================================================================
SELECT 'SalesOrderDetail' AS [Table], 'Non-positive OrderQty' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count], MIN(OrderQty) AS [Example_Messy_Value]
FROM bronze.SalesOrderDetail
WHERE OrderQty <= 0;

SELECT 'SalesOrderDetail' AS [Table], 'Negative UnitPrice' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count], MIN(UnitPrice) AS [Example_Messy_Value]
FROM bronze.SalesOrderDetail
WHERE UnitPrice < 0;

SELECT 'Product' AS [Table], 'Negative or Null ListPrice' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count], MIN(ListPrice) AS [Example_Messy_Value]
FROM bronze.[Product]
WHERE ListPrice < 0 OR ListPrice IS NULL;

SELECT 'Product' AS [Table], 'Negative StandardCost' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count], MIN(StandardCost) AS [Example_Messy_Value]
FROM bronze.[Product]
WHERE StandardCost < 0;
GO

-- ===================================================================
-- TEST 3: DATE LOGIC ERRORS (a ship or due date earlier than the order
-- date is not physically possible and signals a data entry problem)
-- ===================================================================
SELECT 'SalesOrderHeader' AS [Table], 'ShipDate before OrderDate' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM bronze.SalesOrderHeader
WHERE ShipDate < OrderDate;

SELECT 'SalesOrderHeader' AS [Table], 'DueDate before OrderDate' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM bronze.SalesOrderHeader
WHERE DueDate < OrderDate;
GO

-- ===================================================================
-- TEST 4: MISSING / NULL VALUES IN KEY DESCRIPTIVE COLUMNS
-- ===================================================================
SELECT 'Person' AS [Table], 'Missing FirstName or LastName' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM bronze.Person
WHERE FirstName IS NULL OR LastName IS NULL OR TRIM(FirstName) = '' OR TRIM(LastName) = '';

SELECT '[Address]' AS [Table], 'Missing City or PostalCode' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM bronze.[Address]
WHERE City IS NULL OR TRIM(City) = '' OR PostalCode IS NULL OR TRIM(PostalCode) = '';

SELECT 'Product' AS [Table], 'Missing Color' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM bronze.[Product]
WHERE Color IS NULL OR TRIM(Color) = '';
GO

-- ===================================================================
-- TEST 5: CATEGORICAL VALUE INSPECTION (casing/spacing inconsistency risk)
-- ===================================================================
SELECT 'Product' AS [Table], 'Distinct raw Color values' AS [Anomaly_Type],
       COUNT(DISTINCT Color) AS [Distinct_Raw_Count]
FROM bronze.[Product];

SELECT 'CountryRegion' AS [Table], 'Distinct raw Name values' AS [Anomaly_Type],
       COUNT(DISTINCT Name) AS [Distinct_Raw_Count]
FROM bronze.CountryRegion;
GO

-- ===================================================================
-- TEST 6: REFERENTIAL INTEGRITY BREAKS (orphaned foreign keys)
-- ===================================================================

-- 6a. Sales order lines pointing to non-existent Products
SELECT 'SalesOrderDetail' AS [Table], 'Orphaned ProductID' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM bronze.SalesOrderDetail d
LEFT JOIN bronze.[Product] p ON d.ProductID = p.ProductID
WHERE p.ProductID IS NULL;

-- 6b. Sales orders pointing to non-existent Customers
SELECT 'SalesOrderHeader' AS [Table], 'Orphaned CustomerID' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM bronze.SalesOrderHeader h
LEFT JOIN bronze.Customer c ON h.CustomerID = c.CustomerID
WHERE c.CustomerID IS NULL;

-- 6c. Sales orders pointing to non-existent Territories
SELECT 'SalesOrderHeader' AS [Table], 'Orphaned TerritoryID' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM bronze.SalesOrderHeader h
LEFT JOIN bronze.SalesTerritory t ON h.TerritoryID = t.TerritoryID
WHERE h.TerritoryID IS NOT NULL AND t.TerritoryID IS NULL;

-- 6d. Products pointing to non-existent Subcategories
SELECT 'Product' AS [Table], 'Orphaned ProductSubcategoryID' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM bronze.[Product] p
LEFT JOIN bronze.ProductSubcategory s ON p.ProductSubcategoryID = s.ProductSubcategoryID
WHERE p.ProductSubcategoryID IS NOT NULL AND s.ProductSubcategoryID IS NULL;

-- 6e. Subcategories pointing to non-existent Categories
SELECT 'ProductSubcategory' AS [Table], 'Orphaned ProductCategoryID' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM bronze.ProductSubcategory s
LEFT JOIN bronze.ProductCategory c ON s.ProductCategoryID = c.ProductCategoryID
WHERE c.ProductCategoryID IS NULL;

-- 6f. Addresses pointing to non-existent StateProvince
SELECT '[Address]' AS [Table], 'Orphaned StateProvinceID' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM bronze.[Address] a
LEFT JOIN bronze.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
WHERE sp.StateProvinceID IS NULL;

-- 6g. StateProvince pointing to non-existent CountryRegion
SELECT 'StateProvince' AS [Table], 'Orphaned CountryRegionCode' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM bronze.StateProvince sp
LEFT JOIN bronze.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode
WHERE cr.CountryRegionCode IS NULL;

-- 6h. Customers pointing to non-existent Persons (nullable FK, only check when present)
SELECT 'Customer' AS [Table], 'Orphaned PersonID' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM bronze.Customer c
LEFT JOIN bronze.Person p ON c.PersonID = p.BusinessEntityID
WHERE c.PersonID IS NOT NULL AND p.BusinessEntityID IS NULL;

-- 6i. Customers pointing to non-existent Stores (nullable FK, only check when present)
SELECT 'Customer' AS [Table], 'Orphaned StoreID' AS [Anomaly_Type],
       COUNT(*) AS [Affected_Row_Count]
FROM bronze.Customer c
LEFT JOIN bronze.Store s ON c.StoreID = s.BusinessEntityID
WHERE c.StoreID IS NOT NULL AND s.BusinessEntityID IS NULL;
GO


SELECT
    pc.Name AS Category,
    COUNT(*) AS MissingColorCount
FROM bronze.Product p
LEFT JOIN bronze.ProductSubcategory ps
    ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN bronze.ProductCategory pc
    ON ps.ProductCategoryID = pc.ProductCategoryID
WHERE p.Color IS NULL
   OR TRIM(p.Color) = ''
GROUP BY pc.Name
ORDER BY MissingColorCount DESC;



SELECT ProductID,
       Name,
       ProductNumber,
       ProductSubcategoryID
FROM bronze.Product
WHERE Color IS NULL;


SELECT
    COUNT(*) AS ProductsWithoutSubcategory
FROM bronze.Product
WHERE ProductSubcategoryID IS NULL;


SELECT
    ProductID,
    Name,
    Color
FROM bronze.Product
WHERE ProductSubcategoryID IS NULL
  AND Color IS NOT NULL;





  SELECT DISTINCT Color
FROM bronze.Product
ORDER BY Color;

SELECT DISTINCT Name
FROM bronze.CountryRegion
ORDER BY Name;
