/* =====================================================
   E-COMMERCE SALES ANALYTICS
   Database: ECommerceAnalytics
   ===================================================== */


/* =====================================================
   01. DATA QUALITY & INTEGRITY
   ===================================================== */

/* Table row counts */
USE ECommerceAnalytics;
GO

SELECT 
    t.name AS TableName,
    SUM(p.rows) AS [RowCount]
FROM sys.tables AS t
INNER JOIN sys.partitions AS p
    ON t.object_id = p.object_id
WHERE p.index_id IN (0, 1)
GROUP BY t.name
ORDER BY t.name;

/* Key-column audit */
SELECT 
    'Customers - customer_id' AS KeyColumn,
    COUNT(*) AS TotalRows,
    COUNT(customer_id) AS NonNullValues,
    COUNT(DISTINCT customer_id) AS DistinctValues
FROM dbo.Customers

UNION ALL

SELECT 
    'Orders - order_id',
    COUNT(*),
    COUNT(order_id),
    COUNT(DISTINCT order_id)
FROM dbo.Orders

UNION ALL

SELECT 
    'Orders - customer_id',
    COUNT(*),
    COUNT(customer_id),
    COUNT(DISTINCT customer_id)
FROM dbo.Orders

UNION ALL

SELECT 
    'Order items - order_id',
    COUNT(*),
    COUNT(order_id),
    COUNT(DISTINCT order_id)
FROM dbo.[Order items]

UNION ALL

SELECT 
    'Order items - product_id',
    COUNT(*),
    COUNT(product_id),
    COUNT(DISTINCT product_id)
FROM dbo.[Order items]

UNION ALL

SELECT 
    'Order items - seller_id',
    COUNT(*),
    COUNT(seller_id),
    COUNT(DISTINCT seller_id)
FROM dbo.[Order items]

UNION ALL

SELECT 
    'Order payment - order_id',
    COUNT(*),
    COUNT(order_id),
    COUNT(DISTINCT order_id)
FROM dbo.[Order payment]

UNION ALL

SELECT 
    'Order review - order_id',
    COUNT(*),
    COUNT(order_id),
    COUNT(DISTINCT order_id)
FROM dbo.[Order review]

UNION ALL

SELECT 
    'Products - product_id',
    COUNT(*),
    COUNT(product_id),
    COUNT(DISTINCT product_id)
FROM dbo.Products

UNION ALL

SELECT 
    'Seller - seller_id',
    COUNT(*),
    COUNT(seller_id),
    COUNT(DISTINCT seller_id)
FROM dbo.Seller;

/* Customer identity audit */
SELECT
    COUNT(*) AS TotalCustomerRecords,
    COUNT(customer_unique_id) AS NonNullUniqueIDs,
    COUNT(DISTINCT customer_unique_id) AS ActualUniqueCustomers
FROM dbo.Customers;
/* Orphan-record audit */
SELECT 
    'Orphan Orders' AS CheckName,
    COUNT(*) AS ProblemRows
FROM dbo.Orders AS o
LEFT JOIN dbo.Customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL

SELECT 
    'Orphan Products',
    COUNT(*)
FROM dbo.[Order items] AS oi
LEFT JOIN dbo.Products AS p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL

SELECT 
    'Orphan Sellers',
    COUNT(*)
FROM dbo.[Order items] AS oi
LEFT JOIN dbo.Seller AS s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

/* =====================================================
   02. EXECUTIVE KPIs
   ===================================================== */

   SELECT
    COUNT(DISTINCT o.order_id) AS TotalOrders,
    COUNT(DISTINCT c.customer_unique_id) AS UniqueCustomers,
    SUM(oi.price) AS TotalRevenue,
    SUM(oi.freight_value) AS TotalFreightCost,
    SUM(oi.price) / COUNT(DISTINCT o.order_id) AS AverageOrderValue,
    COUNT(DISTINCT CASE
        WHEN o.order_status = 'delivered'
        THEN o.order_id
    END) AS DeliveredOrders,
    CAST(
        100.0 *
        COUNT(DISTINCT CASE
            WHEN o.order_status = 'delivered'
            THEN o.order_id
        END)
        / COUNT(DISTINCT o.order_id)
        AS DECIMAL(5,2)
    ) AS DeliveredOrderPercentage
FROM dbo.Orders AS o
INNER JOIN dbo.Customers AS c
    ON o.customer_id = c.customer_id
INNER JOIN dbo.[Order items] AS oi
    ON o.order_id = oi.order_id;
/* Total Orders */
/* Unique Customers */
/* Total Revenue */
/* Total Freight Cost */
/* Average Order Value */
/* Delivered Orders */
/* Delivered Order % */


/* =====================================================
   03. REVENUE PERFORMANCE
   ===================================================== */

/* Monthly Revenue */
-- Monthly revenue, orders, and unique customers

SELECT
    YEAR(o.order_purchase_timestamp) AS OrderYear,
    MONTH(o.order_purchase_timestamp) AS OrderMonth,
    FORMAT(o.order_purchase_timestamp, 'yyyy-MM') AS YearMonth,
    SUM(oi.price) AS MonthlyRevenue,
    COUNT(DISTINCT o.order_id) AS TotalOrders,
    COUNT(DISTINCT c.customer_unique_id) AS UniqueCustomers
FROM dbo.Orders AS o
INNER JOIN dbo.[Order items] AS oi
    ON o.order_id = oi.order_id
INNER JOIN dbo.Customers AS c
    ON o.customer_id = c.customer_id
GROUP BY
    YEAR(o.order_purchase_timestamp),
    MONTH(o.order_purchase_timestamp),
    FORMAT(o.order_purchase_timestamp, 'yyyy-MM')
ORDER BY
    OrderYear,
    OrderMonth;
/* Highest and Lowest Revenue Month */
-- Identify the highest- and lowest-revenue months

WITH MonthlySales AS
(
    SELECT
        FORMAT(o.order_purchase_timestamp, 'yyyy-MM') AS YearMonth,
        SUM(oi.price) AS MonthlyRevenue
    FROM dbo.Orders AS o
    INNER JOIN dbo.[Order items] AS oi
        ON o.order_id = oi.order_id
    GROUP BY
        FORMAT(o.order_purchase_timestamp, 'yyyy-MM')
)
SELECT
    'Highest Revenue Month' AS Metric,
    YearMonth,
    MonthlyRevenue
FROM MonthlySales
WHERE MonthlyRevenue =
(
    SELECT MAX(MonthlyRevenue)
    FROM MonthlySales
)

UNION ALL

SELECT
    'Lowest Revenue Month',
    YearMonth,
    MonthlyRevenue
FROM MonthlySales
WHERE MonthlyRevenue =
(
    SELECT MIN(MonthlyRevenue)
    FROM MonthlySales
);



/* =====================================================
   04. PRODUCT & CATEGORY PERFORMANCE
   ===================================================== */

/* Top 10 Categories by Revenue */
-- Top 10 product categories by revenue

SELECT TOP 10
    p.product_category_name AS ProductCategory,
    SUM(oi.price) AS TotalRevenue,
    COUNT(DISTINCT oi.order_id) AS TotalOrders,
    COUNT(*) AS ItemsSold
FROM dbo.Products AS p
INNER JOIN dbo.[Order items] AS oi
    ON p.product_id = oi.product_id
WHERE p.product_category_name IS NOT NULL
GROUP BY
    p.product_category_name
ORDER BY
    TotalRevenue DESC;

/* =====================================================
   05. CUSTOMER BEHAVIOR
   ===================================================== */

/* One-Time vs Repeat Customers */
-- Classify customers by purchase frequency

WITH CustomerOrderCount AS
(
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS OrderCount
    FROM dbo.Customers AS c
    INNER JOIN dbo.Orders AS o
        ON c.customer_id = o.customer_id
    GROUP BY
        c.customer_unique_id
)
SELECT
    CASE
        WHEN OrderCount = 1 THEN 'One-Time Customer'
        ELSE 'Repeat Customer'
    END AS CustomerType,
    COUNT(*) AS NumberOfCustomers
FROM CustomerOrderCount
GROUP BY
    CASE
        WHEN OrderCount = 1 THEN 'One-Time Customer'
        ELSE 'Repeat Customer'
    END
ORDER BY
    NumberOfCustomers DESC;
/* Top 10 Customers by Revenue */
-- Top 10 customers by revenue

SELECT TOP 10
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS TotalOrders,
    SUM(oi.price) AS TotalRevenue,
    AVG(oi.price) AS AverageItemValue
FROM dbo.Customers AS c
INNER JOIN dbo.Orders AS o
    ON c.customer_id = o.customer_id
INNER JOIN dbo.[Order items] AS oi
    ON o.order_id = oi.order_id
GROUP BY
    c.customer_unique_id
ORDER BY
    TotalRevenue DESC;
/* Average Revenue per Customer */

/* Revenue: Repeat vs One-Time */
-- Revenue contribution from one-time and repeat customers

WITH CustomerOrders AS
(
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS TotalOrders,
        SUM(oi.price) AS TotalRevenue
    FROM dbo.Customers AS c
    INNER JOIN dbo.Orders AS o
        ON c.customer_id = o.customer_id
    INNER JOIN dbo.[Order items] AS oi
        ON o.order_id = oi.order_id
    GROUP BY
        c.customer_unique_id
)
SELECT
    CASE
        WHEN TotalOrders = 1 THEN 'One-Time Customer'
        ELSE 'Repeat Customer'
    END AS CustomerType,
    COUNT(*) AS NumberOfCustomers,
    SUM(TotalRevenue) AS TotalRevenue,
    AVG(TotalRevenue) AS AverageRevenuePerCustomer
FROM CustomerOrders
GROUP BY
    CASE
        WHEN TotalOrders = 1 THEN 'One-Time Customer'
        ELSE 'Repeat Customer'
    END
ORDER BY
    TotalRevenue DESC;

/* =====================================================
   06. SELLER PERFORMANCE
   ===================================================== */

/* Top 10 Sellers by Revenue */
-- Top 10 sellers by revenue

SELECT TOP 10
    s.seller_id,
    COUNT(DISTINCT oi.order_id) AS TotalOrders,
    COUNT(*) AS ItemsSold,
    SUM(oi.price) AS TotalRevenue,
    AVG(oi.price) AS AverageItemPrice
FROM dbo.Seller AS s
INNER JOIN dbo.[Order items] AS oi
    ON s.seller_id = oi.seller_id
GROUP BY
    s.seller_id
ORDER BY
    TotalRevenue DESC;

/* =====================================================
   07. ORDER PERFORMANCE
   ===================================================== */

/* Order Status Distribution */
-- Order status distribution

SELECT
    order_status AS OrderStatus,
    COUNT(*) AS TotalOrders,
    CAST(
        100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.Orders)
        AS DECIMAL(5,2)
    ) AS PercentageOfOrders
FROM dbo.Orders
GROUP BY
    order_status
ORDER BY
    TotalOrders DESC;

/* =====================================================
   08. DELIVERY PERFORMANCE
   ===================================================== */

/* Average Delivery Days */
/* On-Time Delivery Rate */
/* Late Orders */
-- Delivery performance: speed and on-time rate

SELECT
    COUNT(*) AS DeliveredOrders,

    AVG(
        DATEDIFF(
            DAY,
            order_purchase_timestamp,
            order_delivered_customer_date
        )
    ) AS AverageDeliveryDays,

    SUM(
        CASE
            WHEN order_delivered_customer_date <= order_estimated_delivery_date
            THEN 1
            ELSE 0
        END
    ) AS OnTimeOrders,

    SUM(
        CASE
            WHEN order_delivered_customer_date > order_estimated_delivery_date
            THEN 1
            ELSE 0
        END
    ) AS LateOrders,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN order_delivered_customer_date <= order_estimated_delivery_date
                THEN 1
                ELSE 0
            END
        ) / COUNT(*)
        AS DECIMAL(5,2)
    ) AS OnTimeDeliveryRate

FROM dbo.Orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

/* =====================================================
   09. PAYMENT PERFORMANCE
   ===================================================== */

/* Payment Method */
/* Payment Value */
/* Average Installments */
-- Payment method performance

SELECT
    payment_type AS PaymentMethod,
    COUNT(*) AS PaymentTransactions,
    SUM(payment_value) AS TotalPaymentValue,
    AVG(payment_value) AS AveragePaymentValue,
    AVG(CAST(payment_installments AS DECIMAL(10,2))) AS AverageInstallments
FROM dbo.[Order payment]
GROUP BY
    payment_type
ORDER BY
    TotalPaymentValue DESC;

/* =====================================================
   10. CUSTOMER SATISFACTION
   ===================================================== */

/* Total Reviews */
/* Average Review Score */
/* Positive Reviews */
/* Low-Score Reviews */
-- Customer review performance

SELECT
    COUNT(*) AS TotalReviews,
    AVG(CAST(review_score AS DECIMAL(10,2))) AS AverageReviewScore,
    SUM(
        CASE
            WHEN review_score >= 4 THEN 1
            ELSE 0
        END
    ) AS PositiveReviews,
    SUM(
        CASE
            WHEN review_score <= 2 THEN 1
            ELSE 0
        END
    ) AS LowScoreReviews
FROM dbo.[Order review];