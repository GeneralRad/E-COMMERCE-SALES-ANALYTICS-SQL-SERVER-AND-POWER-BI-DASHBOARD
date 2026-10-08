USE ECommerceAnalytics;
GO

SELECT TOP 10 *
FROM dbo.Products;

SELECT COUNT(*) AS TotalProducts
FROM dbo.Products;



USE ECommerceAnalytics;
GO

SELECT 
    'Customers - customer_id' AS KeyColumn,
    COUNT(*) AS TotalRows,
    COUNT(customer_id) AS NonNullValues,
    COUNT(DISTINCT customer_id) AS DistinctValues
FROM dbo.Customers



USE ECommerceAnalytics;
GO

SELECT
    COUNT(*) AS TotalCustomerRecords,
    COUNT(customer_unique_id) AS NonNullUniqueIDs,
    COUNT(DISTINCT customer_unique_id) AS ActualUniqueCustomers
FROM dbo.Customers;


SELECT TOP 20
    customer_unique_id,
    COUNT(*) AS CustomerRecords
FROM dbo.Customers
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
ORDER BY CustomerRecords DESC;



USE ECommerceAnalytics;
GO

SELECT 'Orphan Orders' AS CheckName, COUNT(*) AS ProblemRows
FROM dbo.Orders o
LEFT JOIN dbo.Customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL

SELECT 'Orphan Products', COUNT(*)
FROM dbo.[Order items] oi
LEFT JOIN dbo.Products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL

SELECT 'Orphan Sellers', COUNT(*)
FROM dbo.[Order items] oi
LEFT JOIN dbo.Seller s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;


USE ECommerceAnalytics;
GO

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
        100.0 * COUNT(DISTINCT CASE
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



    USE ECommerceAnalytics;
GO

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




    USE ECommerceAnalytics;
GO

WITH MonthlySales AS
(
    SELECT
        YEAR(o.order_purchase_timestamp) AS OrderYear,
        MONTH(o.order_purchase_timestamp) AS OrderMonth,
        FORMAT(o.order_purchase_timestamp, 'yyyy-MM') AS YearMonth,
        SUM(oi.price) AS MonthlyRevenue
    FROM dbo.Orders AS o
    INNER JOIN dbo.[Order items] AS oi
        ON o.order_id = oi.order_id
    GROUP BY
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp),
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




USE ECommerceAnalytics;
GO

SELECT TOP 10
    p.product_category_name AS ProductCategory,
    SUM(oi.price) AS TotalRevenue,
    COUNT(DISTINCT oi.order_id) AS TotalOrders,
    COUNT(*) AS ItemsSold
FROM dbo.Products AS p
INNER JOIN dbo.[Order items] AS oi
    ON p.product_id = oi.product_id
WHERE p.product_category_name IS NOT NULL
GROUP BY p.product_category_name
ORDER BY TotalRevenue DESC;






USE ECommerceAnalytics;
GO

WITH CustomerOrderCount AS
(
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS OrderCount
    FROM dbo.Customers AS c
    INNER JOIN dbo.Orders AS o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
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
ORDER BY NumberOfCustomers DESC;




USE ECommerceAnalytics;
GO

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



    USE ECommerceAnalytics;
GO

WITH CustomerRevenue AS
(
    SELECT
        c.customer_unique_id,
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
    COUNT(*) AS CustomersWithOrders,
    SUM(TotalRevenue) AS TotalRevenue,
    AVG(TotalRevenue) AS AverageRevenuePerCustomer,
    MAX(TotalRevenue) AS HighestCustomerRevenue,
    MIN(TotalRevenue) AS LowestCustomerRevenue
FROM CustomerRevenue;


USE ECommerceAnalytics;
GO

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


    USE ECommerceAnalytics;
GO

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




    USE ECommerceAnalytics;
GO

SELECT TOP 10
    s.seller_id,
    COUNT(*) AS ItemsSold,
    COUNT(DISTINCT oi.order_id) AS TotalOrders,
    SUM(oi.price) AS TotalRevenue,
    AVG(oi.price) AS AverageItemPrice
FROM dbo.Seller AS s
INNER JOIN dbo.[Order items] AS oi
    ON s.seller_id = oi.seller_id
GROUP BY
    s.seller_id
ORDER BY
    ItemsSold DESC;

    USE ECommerceAnalytics;
GO

SELECT
    order_status AS OrderStatus,
    COUNT(*) AS TotalOrders,
    CAST(
        100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.Orders)
        AS DECIMAL(5,2)
    ) AS PercentageOfOrders
FROM dbo.Orders
GROUP BY order_status
ORDER BY TotalOrders DESC;
USE ECommerceAnalytics;
GO

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

  USE ECommerceAnalytics;
GO

SELECT
    payment_type AS PaymentMethod,
    COUNT(*) AS PaymentTransactions,
    SUM(payment_value) AS TotalPaymentValue,
    AVG(payment_value) AS AveragePaymentValue,
    AVG(CAST(payment_installments AS DECIMAL(10,2))) AS AverageInstallments
FROM dbo.[Order payment]
GROUP BY payment_type
ORDER BY TotalPaymentValue DESC;

USE ECommerceAnalytics;
GO

SELECT
    COUNT(*) AS TotalReviews,
    AVG(CAST(review_score AS DECIMAL(10,2))) AS AverageReviewScore,
    SUM(CASE WHEN review_score >= 4 THEN 1 ELSE 0 END) AS PositiveReviews,
    SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) AS LowScoreReviews
FROM dbo.[Order review];

SELECT @@SERVERNAME AS ServerName;