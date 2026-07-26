USE AdventureWorks_DW;
GO

/*=========================================================
DROP SILVER TABLES
=========================================================*/

DROP TABLE IF EXISTS silver.SalesOrderDetail;
DROP TABLE IF EXISTS silver.SalesOrderHeader;
DROP TABLE IF EXISTS silver.Customer;
DROP TABLE IF EXISTS silver.Person;
DROP TABLE IF EXISTS silver.Store;
DROP TABLE IF EXISTS silver.Product;
DROP TABLE IF EXISTS silver.ProductSubcategory;
DROP TABLE IF EXISTS silver.ProductCategory;
DROP TABLE IF EXISTS silver.SalesTerritory;
DROP TABLE IF EXISTS silver.Address;
DROP TABLE IF EXISTS silver.StateProvince;
DROP TABLE IF EXISTS silver.CountryRegion;
DROP TABLE IF EXISTS silver.ShipMethod;
DROP TABLE IF EXISTS silver.CreditCard;
GO

/*=========================================================
CREATE TABLES

Per Profiling.docx, bronze TEST 2/3/4 mostly returned 0 issues; the only
confirmed finding was 248 products with a missing Color. Even so, the
NOT NULL + fallback pattern below is kept as a defensive guard on the
columns profiling checked (StandardCost, ListPrice, City, PostalCode,
FirstName, LastName, Color) -- if bronze is ever reloaded from a source
that DOES contain blanks/negatives in these columns, the fallback keeps
the pipeline from silently producing NULLs or breaking on re-run,
instead of assuming every future load will be as clean as this one.
=========================================================*/

CREATE TABLE silver.ProductCategory
(
    ProductCategoryID INT PRIMARY KEY,
    Name NVARCHAR(50) NOT NULL
);

CREATE TABLE silver.ProductSubcategory
(
    ProductSubcategoryID INT PRIMARY KEY,
    ProductCategoryID INT NOT NULL,
    Name NVARCHAR(50) NOT NULL
);

-- Color: NOT NULL -> 'Unknown' fallback (TEST 4 found 248 blanks; decision
-- documented in Profiling.docx: Color is optional, rows kept, value standardized)
-- StandardCost/ListPrice: NOT NULL -> 0.00 fallback (defensive guard;
-- TEST 2 found 0 issues in THIS load, but the column is business-critical
-- enough to protect against a future reload introducing bad values)
CREATE TABLE silver.Product
(
    ProductID INT PRIMARY KEY,
    Name NVARCHAR(100),
    ProductNumber NVARCHAR(25),
    Color NVARCHAR(20) NOT NULL,
    Size NVARCHAR(5),
    Weight DECIMAL(8,2),
    ProductLine NCHAR(2),
    Class NCHAR(2),
    Style NCHAR(2),
    StandardCost MONEY NOT NULL,
    ListPrice MONEY NOT NULL,
    ProductSubcategoryID INT
);

CREATE TABLE silver.SalesTerritory
(
    TerritoryID INT PRIMARY KEY,
    Name NVARCHAR(50),
    CountryRegionCode NVARCHAR(10),
    [Group] NVARCHAR(50),
    SalesYTD MONEY,
    SalesLastYear MONEY,
    CostYTD MONEY,
    CostLastYear MONEY
);

CREATE TABLE silver.CountryRegion
(
    CountryRegionCode NVARCHAR(10) PRIMARY KEY,
    Name NVARCHAR(50)
);

CREATE TABLE silver.StateProvince
(
    StateProvinceID INT PRIMARY KEY,
    StateProvinceCode NCHAR(3),
    CountryRegionCode NVARCHAR(10),
    Name NVARCHAR(50),
    TerritoryID INT
);

-- City/PostalCode: NOT NULL -> 'Unknown' fallback (defensive guard;
-- TEST 4 found 0 missing values in THIS load)
CREATE TABLE silver.Address
(
    AddressID INT PRIMARY KEY,
    AddressLine1 NVARCHAR(60),
    AddressLine2 NVARCHAR(60),
    City NVARCHAR(50) NOT NULL,
    StateProvinceID INT,
    PostalCode NVARCHAR(15) NOT NULL
);

-- FirstName/LastName: NOT NULL -> 'Unknown' fallback (defensive guard;
-- TEST 4 found 0 missing values in THIS load)
-- AdditionalContactInfo/Demographics: carried over as plain XML (bronze already
-- cast them, since the typed-XML schema binding from AdventureWorks2022 can't
-- cross databases)
CREATE TABLE silver.Person
(
    BusinessEntityID INT PRIMARY KEY,
    PersonType NCHAR(2),
    Title NVARCHAR(8),
    FirstName NVARCHAR(50) NOT NULL,
    MiddleName NVARCHAR(50),
    LastName NVARCHAR(50) NOT NULL,
    Suffix NVARCHAR(10),
    EmailPromotion INT,
    AdditionalContactInfo XML,
    Demographics XML
);

-- Demographics: carried over as plain XML, same reason as Person above
CREATE TABLE silver.Store
(
    BusinessEntityID INT PRIMARY KEY,
    Name NVARCHAR(100),
    SalesPersonID INT,
    Demographics XML
);

CREATE TABLE silver.Customer
(
    CustomerID INT PRIMARY KEY,
    PersonID INT,
    StoreID INT,
    TerritoryID INT,
    AccountNumber NVARCHAR(20)
);

-- CHECK constraints act as a defensive safety net. TEST 3 in Profiling.docx
-- found 0 rows with ShipDate/DueDate before OrderDate in THIS load, so no
-- WHERE filter is applied at load time -- but the constraints stay in place
-- to reject any such row a future reload might introduce.
CREATE TABLE silver.SalesOrderHeader
(
    SalesOrderID INT PRIMARY KEY,
    RevisionNumber TINYINT,
    OrderDate DATE,
    DueDate DATE,
    ShipDate DATE,
    Status TINYINT,
    OnlineOrderFlag BIT,
    SalesOrderNumber NVARCHAR(25),
    PurchaseOrderNumber NVARCHAR(25),
    AccountNumber NVARCHAR(20),
    CustomerID INT,
    SalesPersonID INT,
    TerritoryID INT,
    BillToAddressID INT,
    ShipToAddressID INT,
    ShipMethodID INT,
    CreditCardID INT,
    CreditCardApprovalCode VARCHAR(15),
    CurrencyRateID INT,
    SubTotal MONEY,
    TaxAmt MONEY,
    Freight MONEY,
    TotalDue MONEY,
    Comment NVARCHAR(128),
    CONSTRAINT CK_SalesOrderHeader_DueDate  CHECK (DueDate  IS NULL OR DueDate  >= OrderDate),
    CONSTRAINT CK_SalesOrderHeader_ShipDate CHECK (ShipDate IS NULL OR ShipDate >= OrderDate)
);

-- CHECK constraints act as a defensive safety net. TEST 2 in Profiling.docx
-- found 0 rows with non-positive OrderQty or negative UnitPrice in THIS load,
-- so no WHERE filter is applied at load time -- constraints stay in place
-- to reject any such row a future reload might introduce.
CREATE TABLE silver.SalesOrderDetail
(
    SalesOrderDetailID INT PRIMARY KEY,
    SalesOrderID INT,
    CarrierTrackingNumber NVARCHAR(25),
    OrderQty SMALLINT,
    ProductID INT,
    SpecialOfferID INT,
    UnitPrice MONEY,
    UnitPriceDiscount MONEY,
    LineTotal MONEY,
    CONSTRAINT CK_SalesOrderDetail_OrderQty  CHECK (OrderQty > 0),
    CONSTRAINT CK_SalesOrderDetail_UnitPrice CHECK (UnitPrice >= 0)
);
GO
CREATE TABLE silver.ShipMethod
(
    ShipMethodID INT PRIMARY KEY,
    Name NVARCHAR(50) NOT NULL,
    ShipBase MONEY,
    ShipRate MONEY
);

CREATE TABLE silver.CreditCard
(
    CreditCardID INT PRIMARY KEY,
    CardType NVARCHAR(50),
    CardNumber NVARCHAR(25),
    ExpMonth TINYINT,
    ExpYear SMALLINT
);


/*=========================================================
LOAD PRODUCT CATEGORY
=========================================================*/

INSERT INTO silver.ProductCategory (ProductCategoryID, Name)
SELECT DISTINCT
    ProductCategoryID,
    UPPER(TRIM(Name))
FROM bronze.ProductCategory;
GO

/*=========================================================
LOAD PRODUCT SUBCATEGORY
=========================================================*/

INSERT INTO silver.ProductSubcategory (ProductSubcategoryID, ProductCategoryID, Name)
SELECT DISTINCT
    ProductSubcategoryID,
    ProductCategoryID,
    UPPER(TRIM(Name))
FROM bronze.ProductSubcategory;
GO

/*=========================================================
LOAD PRODUCT
-- Color: NULL/blank -> 'Unknown'                (TEST 4: 248 rows found)
-- ListPrice: NULL or negative -> 0.00            (defensive; TEST 2 found 0)
-- StandardCost: negative -> 0.00                 (defensive; TEST 2 found 0)
=========================================================*/

INSERT INTO silver.Product
(
    ProductID, Name, ProductNumber, Color,
    Size, Weight, ProductLine, Class, Style,
    StandardCost, ListPrice, ProductSubcategoryID
)
SELECT DISTINCT
    ProductID,
    TRIM(Name) AS Name,
    TRIM(ProductNumber) AS ProductNumber,
    CASE
        WHEN Color IS NULL OR TRIM(Color) = ''
        THEN 'Unknown'
        ELSE UPPER(TRIM(Color))
    END AS Color,
    Size,
    Weight,
    ProductLine,
    Class,
    Style,
    CASE WHEN StandardCost < 0 THEN 0.00 ELSE StandardCost END AS StandardCost,
    CASE WHEN ListPrice IS NULL OR ListPrice < 0 THEN 0.00 ELSE ListPrice END AS ListPrice,
    ProductSubcategoryID
FROM bronze.[Product];
GO

/*=========================================================
LOAD SALES TERRITORY
=========================================================*/

INSERT INTO silver.SalesTerritory
(
    TerritoryID, Name, CountryRegionCode, [Group],
    SalesYTD, SalesLastYear, CostYTD, CostLastYear
)
SELECT DISTINCT
    TerritoryID,
    TRIM(Name) AS Name,
    UPPER(TRIM(CountryRegionCode)) AS CountryRegionCode,
    UPPER(TRIM([Group])) AS [Group],
    SalesYTD,
    SalesLastYear,
    CostYTD,
    CostLastYear
FROM bronze.SalesTerritory;
GO 
/*==================================*/
/*=========================================================
LOAD SHIP METHOD
=========================================================*/

INSERT INTO silver.ShipMethod (ShipMethodID, Name, ShipBase, ShipRate)
SELECT DISTINCT
    ShipMethodID,
    TRIM(Name) AS Name,
    ShipBase,
    ShipRate
FROM bronze.ShipMethod;
GO

/*=========================================================
LOAD CREDIT CARD
=========================================================*/

INSERT INTO silver.CreditCard (CreditCardID, CardType, CardNumber, ExpMonth, ExpYear)
SELECT DISTINCT
    CreditCardID,
    TRIM(CardType) AS CardType,
    CardNumber,
    ExpMonth,
    ExpYear
FROM bronze.CreditCard;
GO

/*=========================================================
LOAD COUNTRY REGION
=========================================================*/

INSERT INTO silver.CountryRegion (CountryRegionCode, Name)
SELECT DISTINCT
    UPPER(TRIM(CountryRegionCode)),
    TRIM(Name)
FROM bronze.CountryRegion;
GO

/*=========================================================
LOAD STATE PROVINCE
=========================================================*/

INSERT INTO silver.StateProvince
(
    StateProvinceID, StateProvinceCode, CountryRegionCode, Name, TerritoryID
)
SELECT DISTINCT
    StateProvinceID,
    UPPER(TRIM(StateProvinceCode)),
    UPPER(TRIM(CountryRegionCode)),
    TRIM(Name),
    TerritoryID
FROM bronze.StateProvince;
GO

/*=========================================================
LOAD ADDRESS
-- City/PostalCode: NULL/blank -> 'Unknown'      (defensive; TEST 4 found 0)
=========================================================*/

INSERT INTO silver.Address
(
    AddressID, AddressLine1, AddressLine2, City, StateProvinceID, PostalCode
)
SELECT DISTINCT
    AddressID,
    TRIM(AddressLine1) AS AddressLine1,
    TRIM(AddressLine2) AS AddressLine2,
    CASE WHEN City IS NULL OR TRIM(City) = '' THEN 'Unknown' ELSE TRIM(City) END AS City,
    StateProvinceID,
    CASE WHEN PostalCode IS NULL OR TRIM(PostalCode) = '' THEN 'Unknown' ELSE TRIM(PostalCode) END AS PostalCode
FROM bronze.[Address];
GO

/*=========================================================
LOAD PERSON
-- FirstName/LastName: NULL/blank -> 'Unknown'   (defensive; TEST 4 found 0)
-- AdditionalContactInfo/Demographics: carried over unchanged (already
-- plain XML in bronze after the schema-collection cast in 01a)
-- NOTE: no DISTINCT here -- XML columns are not comparable in SQL Server,
-- PRIMARY KEY on BusinessEntityID is the guard against duplicates instead
=========================================================*/

INSERT INTO silver.Person
(
    BusinessEntityID, PersonType, Title, FirstName,
    MiddleName, LastName, Suffix, EmailPromotion,
    AdditionalContactInfo, Demographics
)
SELECT
    BusinessEntityID,
    UPPER(TRIM(PersonType)) AS PersonType,
    UPPER(TRIM(Title)) AS Title,
    CASE WHEN FirstName IS NULL OR TRIM(FirstName) = '' THEN 'Unknown' ELSE TRIM(FirstName) END AS FirstName,
    TRIM(MiddleName) AS MiddleName,
    CASE WHEN LastName IS NULL OR TRIM(LastName) = '' THEN 'Unknown' ELSE TRIM(LastName) END AS LastName,
    UPPER(TRIM(Suffix)) AS Suffix,
    EmailPromotion,
    AdditionalContactInfo,
    Demographics
FROM bronze.Person;
GO

/*=========================================================
LOAD STORE
=========================================================*/

INSERT INTO silver.Store (BusinessEntityID, Name, SalesPersonID, Demographics)
SELECT
    BusinessEntityID,
    TRIM(Name) AS Name,
    SalesPersonID,
    Demographics
FROM bronze.Store;
GO

/*=========================================================
LOAD CUSTOMER
=========================================================*/

INSERT INTO silver.Customer (CustomerID, PersonID, StoreID, TerritoryID, AccountNumber)
SELECT DISTINCT
    CustomerID,
    PersonID,
    StoreID,
    TerritoryID,
    TRIM(AccountNumber) AS AccountNumber
FROM bronze.Customer;
GO

/*=========================================================
/*=========================================================
LOAD SALES ORDER HEADER
No rows are filtered during loading.
CHECK constraints enforce the business rules for future loads.
=========================================================*/
=========================================================*/

INSERT INTO silver.SalesOrderHeader
(
    SalesOrderID, RevisionNumber, OrderDate, DueDate, ShipDate,
    Status, OnlineOrderFlag, SalesOrderNumber, PurchaseOrderNumber,
    AccountNumber, CustomerID, SalesPersonID, TerritoryID,
    BillToAddressID, ShipToAddressID, ShipMethodID, CreditCardID,
    CreditCardApprovalCode, CurrencyRateID, SubTotal, TaxAmt,
    Freight, TotalDue, Comment
)
SELECT DISTINCT
    SalesOrderID,
    RevisionNumber,
    CAST(OrderDate AS DATE),
    CAST(DueDate AS DATE),
    CAST(ShipDate AS DATE),
    Status,
    OnlineOrderFlag,
    TRIM(SalesOrderNumber),
    TRIM(PurchaseOrderNumber),
    TRIM(AccountNumber),
    CustomerID,
    SalesPersonID,
    TerritoryID,
    BillToAddressID,
    ShipToAddressID,
    ShipMethodID,
    CreditCardID,
    TRIM(CreditCardApprovalCode),
    CurrencyRateID,
    SubTotal,
    TaxAmt,
    Freight,
    TotalDue,
    TRIM(Comment)
FROM bronze.SalesOrderHeader

GO

/*=========================================================
LOAD SALES ORDER DETAIL
No rows are filtered during loading.
CHECK constraints protect future loads.
-- guard. TEST 2 found 0 such rows in THIS load, so this WHERE clause does
-- not remove any rows currently -- it only protects a future reload.
=========================================================*/

INSERT INTO silver.SalesOrderDetail
(
    SalesOrderDetailID, SalesOrderID, CarrierTrackingNumber, OrderQty,
    ProductID, SpecialOfferID, UnitPrice, UnitPriceDiscount, LineTotal
)
SELECT DISTINCT
    SalesOrderDetailID,
    SalesOrderID,
    TRIM(CarrierTrackingNumber),
    OrderQty,
    ProductID,
    SpecialOfferID,
    UnitPrice,
    UnitPriceDiscount,
    LineTotal
FROM bronze.SalesOrderDetail

GO

/*=========================================================
                SILVER LAYER VALIDATION
=========================================================*/

-- Row count comparison. Per Profiling.docx, every table except Product
-- (Color fallback doesn't drop rows, just fills them) is expected to show
-- SilverRows = BronzeRows exactly, since profiling found 0 rows that
-- warranted exclusion in this load. Any mismatch should be investigated.
SELECT 'ProductCategory' AS TableName,
    (SELECT COUNT(*) FROM bronze.ProductCategory) AS BronzeRows,
    (SELECT COUNT(*) FROM silver.ProductCategory) AS SilverRows
UNION ALL
SELECT 'ProductSubcategory',
    (SELECT COUNT(*) FROM bronze.ProductSubcategory),
    (SELECT COUNT(*) FROM silver.ProductSubcategory)
UNION ALL
SELECT 'Product',
    (SELECT COUNT(*) FROM bronze.[Product]),
    (SELECT COUNT(*) FROM silver.Product)
UNION ALL
SELECT 'SalesTerritory',
    (SELECT COUNT(*) FROM bronze.SalesTerritory),
    (SELECT COUNT(*) FROM silver.SalesTerritory)
UNION ALL
SELECT 'CountryRegion',
    (SELECT COUNT(*) FROM bronze.CountryRegion),
    (SELECT COUNT(*) FROM silver.CountryRegion)
UNION ALL
SELECT 'StateProvince',
    (SELECT COUNT(*) FROM bronze.StateProvince),
    (SELECT COUNT(*) FROM silver.StateProvince)
UNION ALL
SELECT 'Address',
    (SELECT COUNT(*) FROM bronze.[Address]),
    (SELECT COUNT(*) FROM silver.Address)
UNION ALL
SELECT 'Person',
    (SELECT COUNT(*) FROM bronze.Person),
    (SELECT COUNT(*) FROM silver.Person)
UNION ALL
SELECT 'Store',
    (SELECT COUNT(*) FROM bronze.Store),
    (SELECT COUNT(*) FROM silver.Store)
UNION ALL
SELECT 'Customer',
    (SELECT COUNT(*) FROM bronze.Customer),
    (SELECT COUNT(*) FROM silver.Customer)
UNION ALL
SELECT 'SalesOrderHeader',
    (SELECT COUNT(*) FROM bronze.SalesOrderHeader),
    (SELECT COUNT(*) FROM silver.SalesOrderHeader)
UNION ALL
SELECT 'SalesOrderDetail',
    (SELECT COUNT(*) FROM bronze.SalesOrderDetail),
    (SELECT COUNT(*) FROM silver.SalesOrderDetail);
GO

/*=========================================================
REFERENTIAL INTEGRITY CHECKS
-- Per Profiling.docx TEST 6, all of these are expected to return 0.
=========================================================*/

SELECT COUNT(*) AS ProductsWithoutSubcategory
FROM silver.Product WHERE ProductSubcategoryID IS NULL;

SELECT COUNT(*) AS CustomersWithoutTerritory
FROM silver.Customer WHERE TerritoryID IS NULL;

SELECT COUNT(*) AS OrdersWithoutCustomer
FROM silver.SalesOrderHeader h
LEFT JOIN silver.Customer c ON h.CustomerID = c.CustomerID
WHERE c.CustomerID IS NULL;

SELECT COUNT(*) AS OrderDetailsWithoutProduct
FROM silver.SalesOrderDetail d
LEFT JOIN silver.Product p ON d.ProductID = p.ProductID
WHERE p.ProductID IS NULL;

SELECT COUNT(*) AS OrdersWithoutTerritory
FROM silver.SalesOrderHeader h
LEFT JOIN silver.SalesTerritory t ON h.TerritoryID = t.TerritoryID
WHERE h.TerritoryID IS NOT NULL AND t.TerritoryID IS NULL;

SELECT COUNT(*) AS CustomersWithoutPerson
FROM silver.Customer c
LEFT JOIN silver.Person p ON c.PersonID = p.BusinessEntityID
WHERE c.PersonID IS NOT NULL AND p.BusinessEntityID IS NULL;
GO

/*=========================================================
SAMPLE DATA
=========================================================*/

SELECT TOP 10 * FROM silver.Product;
SELECT TOP 10 * FROM silver.Customer;
SELECT TOP 10 * FROM silver.SalesOrderHeader;
SELECT TOP 10 * FROM silver.SalesOrderDetail;
GO
