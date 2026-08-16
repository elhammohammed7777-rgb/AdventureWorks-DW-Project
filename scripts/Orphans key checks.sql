-- ===============================================
-- Gold Layer Data Quality: Orphan Key Checks
-- Validates every Foreign Key in gold.FactSales
-- against its corresponding Dimension Surrogate Key
-- ===============================================
USE AdventureWorks_DW;
GO

--------------------------------------------------
-- 1. Customer (SK_Customer)
--------------------------------------------------
SELECT 'DimCustomer' AS DimensionChecked, f.SK_Customer AS OrphanKeyValue
FROM gold.FactSales f
LEFT JOIN gold.DimCustomer dc ON f.SK_Customer = dc.SK_Customer
WHERE dc.SK_Customer IS NULL;
GO

--------------------------------------------------
-- 2. Product (SK_Product)
--------------------------------------------------
SELECT 'DimProduct' AS DimensionChecked, f.SK_Product AS OrphanKeyValue
FROM gold.FactSales f
LEFT JOIN gold.DimProduct dp ON f.SK_Product = dp.SK_Product
WHERE dp.SK_Product IS NULL;
GO

--------------------------------------------------
-- 3. Geography (ShipGeographyKey)
--------------------------------------------------
SELECT 'DimGeography' AS DimensionChecked, f.ShipGeographyKey AS OrphanKeyValue
FROM gold.FactSales f
LEFT JOIN gold.DimGeography dg ON f.ShipGeographyKey = dg.SK_Geography
WHERE dg.SK_Geography IS NULL;
GO

--------------------------------------------------
-- 4. Ship Method (SK_ShipMethod)
--------------------------------------------------
SELECT 'DimShipMethod' AS DimensionChecked, f.SK_ShipMethod AS OrphanKeyValue
FROM gold.FactSales f
LEFT JOIN gold.DimShipMethod dsm ON f.SK_ShipMethod = dsm.SK_ShipMethod
WHERE dsm.SK_ShipMethod IS NULL;
GO

--------------------------------------------------
-- 5. Credit Card (SK_CreditCard)
-- Note: SK_CreditCard is legitimately NULL for
-- orders with no credit card on file (LEFT JOIN
-- in FactSales), so NULLs are excluded here —
-- only non-NULL values with no dimension match
-- count as orphans.
--------------------------------------------------
SELECT 'DimCreditCard' AS DimensionChecked, f.SK_CreditCard AS OrphanKeyValue
FROM gold.FactSales f
LEFT JOIN gold.DimCreditCard dcc ON f.SK_CreditCard = dcc.SK_CreditCard
WHERE f.SK_CreditCard IS NOT NULL
  AND dcc.SK_CreditCard IS NULL;
GO

--------------------------------------------------
-- 6. Date — Order Date (OrderDateKey)
--------------------------------------------------
SELECT 'DimDate (OrderDateKey)' AS DimensionChecked, f.OrderDateKey AS OrphanKeyValue
FROM gold.FactSales f
LEFT JOIN gold.DimDate dd ON f.OrderDateKey = dd.DateKey
WHERE dd.DateKey IS NULL;
GO

--------------------------------------------------
-- 7. Date — Due Date (DueDateKey)
--------------------------------------------------
SELECT 'DimDate (DueDateKey)' AS DimensionChecked, f.DueDateKey AS OrphanKeyValue
FROM gold.FactSales f
LEFT JOIN gold.DimDate dd ON f.DueDateKey = dd.DateKey
WHERE dd.DateKey IS NULL;
GO

--------------------------------------------------
-- 8. Date — Ship Date (ShipDateKey)
--------------------------------------------------
SELECT 'DimDate (ShipDateKey)' AS DimensionChecked, f.ShipDateKey AS OrphanKeyValue
FROM gold.FactSales f
LEFT JOIN gold.DimDate dd ON f.ShipDateKey = dd.DateKey
WHERE dd.DateKey IS NULL;
GO

--------------------------------------------------
-- 9. Summary Report — orphan row count per dimension
-- Run this to get one consolidated result set
-- instead of scrolling through each check above.
--------------------------------------------------
SELECT 'DimCustomer' AS DimensionChecked, COUNT(*) AS OrphanRowCount
FROM gold.FactSales f
LEFT JOIN gold.DimCustomer dc ON f.SK_Customer = dc.SK_Customer
WHERE dc.SK_Customer IS NULL

UNION ALL

SELECT 'DimProduct', COUNT(*)
FROM gold.FactSales f
LEFT JOIN gold.DimProduct dp ON f.SK_Product = dp.SK_Product
WHERE dp.SK_Product IS NULL

UNION ALL

SELECT 'DimGeography', COUNT(*)
FROM gold.FactSales f
LEFT JOIN gold.DimGeography dg ON f.ShipGeographyKey = dg.SK_Geography
WHERE dg.SK_Geography IS NULL

UNION ALL

SELECT 'DimShipMethod', COUNT(*)
FROM gold.FactSales f
LEFT JOIN gold.DimShipMethod dsm ON f.SK_ShipMethod = dsm.SK_ShipMethod
WHERE dsm.SK_ShipMethod IS NULL

UNION ALL

SELECT 'DimCreditCard', COUNT(*)
FROM gold.FactSales f
LEFT JOIN gold.DimCreditCard dcc ON f.SK_CreditCard = dcc.SK_CreditCard
WHERE f.SK_CreditCard IS NOT NULL
  AND dcc.SK_CreditCard IS NULL

UNION ALL

SELECT 'DimDate (OrderDateKey)', COUNT(*)
FROM gold.FactSales f
LEFT JOIN gold.DimDate dd ON f.OrderDateKey = dd.DateKey
WHERE dd.DateKey IS NULL

UNION ALL

SELECT 'DimDate (DueDateKey)', COUNT(*)
FROM gold.FactSales f
LEFT JOIN gold.DimDate dd ON f.DueDateKey = dd.DateKey
WHERE dd.DateKey IS NULL

UNION ALL

SELECT 'DimDate (ShipDateKey)', COUNT(*)
FROM gold.FactSales f
LEFT JOIN gold.DimDate dd ON f.ShipDateKey = dd.DateKey
WHERE dd.DateKey IS NULL;
GO