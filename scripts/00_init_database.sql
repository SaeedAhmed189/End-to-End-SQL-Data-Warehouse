/* ==============================================================================
   Project: AdventureWorks Data Warehouse
   Description: Foundation script to create the database and Medallion schemas.
   ============================================================================== */

USE master;
GO

-- 1. Create the Database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'AdventureWorks_DW')
BEGIN
    CREATE DATABASE [AdventureWorks_DW];
    PRINT 'SUCCESS: Database [AdventureWorks_DW] created.';
END
ELSE
BEGIN
    PRINT 'INFO: Database [AdventureWorks_DW] already exists.';
END
GO

-- 2. Switch context to the newly created database
USE [AdventureWorks_DW];
GO

-- 3. Create the Bronze Schema (Raw Data Layer)
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'bronze')
BEGIN
    EXEC('CREATE SCHEMA [bronze]');
    PRINT 'SUCCESS: Schema [bronze] created.';
END
ELSE
BEGIN
    PRINT 'INFO: Schema [bronze] already exists.';
END
GO

-- 4. Create the Silver Schema (Cleansed & Conformed Data Layer)
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'silver')
BEGIN
    EXEC('CREATE SCHEMA [silver]');
    PRINT 'SUCCESS: Schema [silver] created.';
END
ELSE
BEGIN
    PRINT 'INFO: Schema [silver] already exists.';
END
GO

-- 5. Create the Gold Schema (Business & Analytics Data Layer)
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'gold')
BEGIN
    EXEC('CREATE SCHEMA [gold]');
    PRINT 'SUCCESS: Schema [gold] created.';
END
ELSE
BEGIN
    PRINT 'INFO: Schema [gold] already exists.';
END
GO