CREATE DATABASE db_inventory;
USE db_inventory;

-- 1. Create table
-- Store
CREATE TABLE Store(
	StoreId INT AUTO_INCREMENT PRIMARY KEY,
    StoreName TEXT
);

-- Vendor
CREATE TABLE Vendor(
	VendorId INT AUTO_INCREMENT PRIMARY KEY,
    VendorName TEXT
);

-- Price
CREATE TABLE Price(
	ProductId INT AUTO_INCREMENT PRIMARY KEY,
    ProductName TEXT,
    SalesPrice DECIMAL(10,2),
    Size TEXT,
    Volume TEXT,
	Classification INT,
    PurchasePrice DECIMAL(10,2),
    VendorId INT,
    FOREIGN KEY (VendorId) REFERENCES Vendor(VendorId)
);

-- Begin
CREATE TABLE Begin(
    StoreId INT,
    ProductId INT,
    onHand INT,
    startDate DATE,
    FOREIGN KEY (StoreId) REFERENCES Store(StoreId),
    FOREIGN KEY (ProductId) REFERENCES Price(ProductId)
);

-- Sales
CREATE TABLE Sales(
    StoreId INT,
    ProductId INT,
    SalesQuantity INT,
    SalesDate TEXT,
    ExciseTax DECIMAL(10,2),
    VendorId INT,
    FOREIGN KEY (StoreId) REFERENCES Store(StoreId),
    FOREIGN KEY (VendorId) REFERENCES Vendor(VendorId),
    FOREIGN KEY (ProductId) REFERENCES Price(ProductId)
);

-- Purchase
CREATE TABLE Purchase(
    StoreId INT,
    ProductId INT,
    VendorId INT,
    PONumber INT,
    PODate TEXT,
    ReceivingDate TEXT,
    InvoiceDate TEXT,
    PayDate TEXT,
    PurchaseQuantity INT,
    FOREIGN KEY (StoreId) REFERENCES Store(StoreId),
    FOREIGN KEY (VendorId) REFERENCES Vendor(VendorId),
    FOREIGN KEY (ProductId) REFERENCES Price(ProductId)
);

-- Summary
CREATE TABLE Summary(
    Date DATE,
    StoreId INT,
    ProductId INT,
    TotalSalesQuantity INT,
    TotalRevenue DECIMAL(10,2),
    TotalCOGS DECIMAL(10,2),
    TotalProfit DECIMAL(10,2),
    TotalPurchaseQuantity INT,
    TotalPurchaseCost DECIMAL(10,2),
    FOREIGN KEY (StoreId) REFERENCES Store(StoreId),
    FOREIGN KEY (ProductId) REFERENCES Price(ProductId)
);

-- 2. Load data
-- Store
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/StoreName.csv'
INTO TABLE Store
FIELDS TERMINATED BY ';'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Vendor
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/VendorName.csv'
INTO TABLE Vendor
FIELDS TERMINATED BY ';'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Price
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/2017PurchasePricesDec.csv'
INTO TABLE Price
FIELDS TERMINATED BY ';'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Begin
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/BegInvFINAL12312016.csv'
INTO TABLE Begin
FIELDS TERMINATED BY ';'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Sales
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/SalesFINAL12312016.csv'
INTO TABLE Sales
FIELDS TERMINATED BY ';'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Purchase
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/PurchasesFINAL12312016.csv'
INTO TABLE Purchase
FIELDS TERMINATED BY ';'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 3. Create summary for sales and purchase data
-- Repeat every end of month
CREATE TABLE Summary_Feb16 AS
SELECT 
    Date,
    StoreId,
    ProductId,
    SUM(TotalSalesQuantity) AS TotalSalesQuantity,
    SUM(TotalRevenue) AS TotalRevenue,
    SUM(TotalCOGS) AS TotalCOGS,
    SUM(TotalProfit) AS TotalProfit,
    SUM(TotalPurchaseQuantity) AS TotalPurchaseQuantity,
    SUM(TotalPurchaseCost) AS TotalPurchaseCost
FROM (

    -- Sales
    SELECT 
        DATE(s.SalesDate) AS Date,
        s.StoreId,
        s.ProductId,
        SUM(s.SalesQuantity) AS TotalSalesQuantity,
        SUM(s.SalesQuantity * p.SalesPrice) AS TotalRevenue,
        SUM(s.SalesQuantity * p.PurchasePrice) AS TotalCOGS,
        SUM(s.SalesQuantity * p.SalesPrice)
        - SUM(s.SalesQuantity * p.PurchasePrice) AS TotalProfit,
        0 AS TotalPurchaseQuantity,
        0 AS TotalPurchaseCost
    FROM Sales s
    JOIN Price p ON s.ProductId = p.ProductId
    WHERE s.SalesDate >= '2016-02-01'
      AND s.SalesDate < '2016-03-01'
    GROUP BY DATE(s.SalesDate), s.StoreId, s.ProductId

    UNION ALL

    -- Purchase Quantity
    SELECT 
        DATE(c.ReceivingDate),
        c.StoreId,
        c.ProductId,
        0,
        0,
        0,
        0,
        SUM(c.PurchaseQuantity),
        0
    FROM Purchase c
    WHERE c.ReceivingDate >= '2016-02-01'
      AND c.ReceivingDate < '2016-03-01'
    GROUP BY DATE(c.ReceivingDate), c.StoreId, c.ProductId

    UNION ALL

    -- Purchase Cost
    SELECT 
        DATE(c.PayDate),
        c.StoreId,
        c.ProductId,
        0,
        0,
        0,
        0,
        0,
        SUM(c.PurchaseQuantity * p.PurchasePrice)
    FROM Purchase c
    JOIN Price p ON c.ProductId = p.ProductId
    WHERE c.PayDate >= '2016-02-01'
      AND c.PayDate < '2016-03-01'
    GROUP BY DATE(c.PayDate), c.StoreId, c.ProductId

) t
GROUP BY Date, StoreId, ProductId;

-- 4. Insert into master summary data
INSERT INTO Summary (Date, StoreId, ProductId, TotalSalesQuantity, TotalRevenue, TotalCOGS, TotalProfit, TotalPurchaseQuantity, TotalPurchaseCost)
SELECT * FROM Summary_Jan16;

INSERT INTO Summary (Date, StoreId, ProductId, TotalSalesQuantity, TotalRevenue, TotalCOGS, TotalProfit, TotalPurchaseQuantity, TotalPurchaseCost)
SELECT * FROM Summary_Feb16;
