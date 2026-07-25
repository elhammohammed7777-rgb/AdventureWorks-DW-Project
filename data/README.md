# Data Source

## Source

AdventureWorks2022.bak is the official Microsoft sample database and is not included in this repository due to file size. Restore the database locally before running the ETL pipeline.

Source:
AdventureWorks2022.bak (Microsoft SQL Server Sample Database)

## Data Acquisition

- Database restored from: AdventureWorks2022.bak
- SQL Server Version: SQL Server 2022
- Extraction Date: July 2026

## Bronze Layer Scope

The Bronze layer contains raw copies of the required OLTP tables only.

Tables extracted:

- Sales.SalesOrderHeader
- Sales.SalesOrderDetail
- Production.Product
- Production.ProductSubcategory
- Production.ProductCategory
- Sales.Customer
- Person.Person
- Sales.Store
- Person.Address
- Person.StateProvince
- Person.CountryRegion
- Purchasing.ShipMethod
- Sales.CreditCard

## Data Scope

- Sales domain only.

## Notes

The Bronze layer is a 1:1 copy of the selected source tables.
No transformations, filtering, or business logic were applied during ingestion.
All transformations are implemented in the Silver and Gold layers.