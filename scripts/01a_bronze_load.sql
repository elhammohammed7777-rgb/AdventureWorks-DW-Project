USE AdventureWorks_DW;
GO

DROP TABLE IF EXISTS bronze.SalesOrderHeader;
DROP TABLE IF EXISTS bronze.SalesOrderDetail;
DROP TABLE IF EXISTS bronze.Customer;
DROP TABLE IF EXISTS bronze.Person;
DROP TABLE IF EXISTS bronze.Store;
DROP TABLE IF EXISTS bronze.SalesTerritory;
DROP TABLE IF EXISTS bronze.[Product];
DROP TABLE IF EXISTS bronze.ProductSubcategory;
DROP TABLE IF EXISTS bronze.ProductCategory;
DROP TABLE IF EXISTS bronze.[Address];
DROP TABLE IF EXISTS bronze.StateProvince;
DROP TABLE IF EXISTS bronze.CountryRegion;

DROP TABLE IF EXISTS bronze.ShipMethod;
DROP TABLE IF EXISTS bronze.CreditCard;

GO

-- ===================================================================
-- Bronze Load: raw, untouched copy from AdventureWorks2022 (the SOURCE db)
-- Each table loads in its OWN batch (GO after every statement) so that
-- a failure in one table does not abort tables that come after/before it.
-- ===================================================================

-- Sales
SELECT * INTO bronze.SalesOrderHeader FROM AdventureWorks2022.Sales.SalesOrderHeader;
GO
SELECT * INTO bronze.SalesOrderDetail FROM AdventureWorks2022.Sales.SalesOrderDetail;
GO

-- Customers
SELECT * INTO bronze.Customer FROM AdventureWorks2022.Sales.Customer;
GO

-- Person: AdditionalContactInfo and Demographics are XML columns bound to a
-- schema collection that only exists in AdventureWorks2022 -- SELECT INTO can't
-- carry that binding across databases. Cast them to plain (untyped) XML instead;
-- the actual XML content is preserved untouched, only the schema validation is dropped.
SELECT
    BusinessEntityID,
    PersonType,
    NameStyle,
    Title,
    FirstName,
    MiddleName,
    LastName,
    Suffix,
    EmailPromotion,
    CAST(AdditionalContactInfo AS XML) AS AdditionalContactInfo,
    CAST(Demographics AS XML) AS Demographics,
    rowguid,
    ModifiedDate
INTO bronze.Person
FROM AdventureWorks2022.Person.Person;
GO

-- Store: same issue, one XML column (Demographics)
SELECT
    BusinessEntityID,
    Name,
    SalesPersonID,
    CAST(Demographics AS XML) AS Demographics,
    rowguid,
    ModifiedDate
INTO bronze.Store
FROM AdventureWorks2022.Sales.Store;
GO

SELECT * INTO bronze.SalesTerritory FROM AdventureWorks2022.Sales.SalesTerritory;
GO


-- Ship Method
SELECT *
INTO bronze.ShipMethod
FROM AdventureWorks2022.Purchasing.ShipMethod;
GO

-- Credit Card
SELECT *
INTO bronze.CreditCard
FROM AdventureWorks2022.Sales.CreditCard;
GO


-- Products
SELECT * INTO bronze.[Product] FROM AdventureWorks2022.Production.[Product];
GO
SELECT * INTO bronze.ProductSubcategory FROM AdventureWorks2022.Production.ProductSubcategory;
GO
SELECT * INTO bronze.ProductCategory FROM AdventureWorks2022.Production.ProductCategory;
GO

-- Geography
SELECT * INTO bronze.[Address] FROM AdventureWorks2022.Person.[Address];
GO
SELECT * INTO bronze.StateProvince FROM AdventureWorks2022.Person.StateProvince;
GO
SELECT * INTO bronze.CountryRegion FROM AdventureWorks2022.Person.CountryRegion;
GO

-- ===================================================================
-- Row count check (quick sanity check, not full profiling -- that's 01b)
-- ===================================================================
SELECT 'SalesOrderHeader' AS TableName, COUNT(*) AS [RowCount] FROM bronze.SalesOrderHeader
UNION ALL SELECT 'SalesOrderDetail', COUNT(*) FROM bronze.SalesOrderDetail
UNION ALL SELECT 'Customer', COUNT(*) FROM bronze.Customer
UNION ALL SELECT 'Person', COUNT(*) FROM bronze.Person
UNION ALL SELECT 'Store', COUNT(*) FROM bronze.Store
UNION ALL SELECT 'SalesTerritory', COUNT(*) FROM bronze.SalesTerritory
UNION ALL SELECT 'Product', COUNT(*) FROM bronze.[Product]
UNION ALL SELECT 'ProductSubcategory', COUNT(*) FROM bronze.ProductSubcategory
UNION ALL SELECT 'ProductCategory', COUNT(*) FROM bronze.ProductCategory
UNION ALL SELECT 'Address', COUNT(*) FROM bronze.[Address]
UNION ALL SELECT 'StateProvince', COUNT(*) FROM bronze.StateProvince
UNION ALL SELECT 'CountryRegion', COUNT(*) FROM bronze.CountryRegion


UNION ALL
SELECT 'ShipMethod', COUNT(*) FROM bronze.ShipMethod

UNION ALL
SELECT 'CreditCard', COUNT(*) FROM bronze.CreditCard;


GO