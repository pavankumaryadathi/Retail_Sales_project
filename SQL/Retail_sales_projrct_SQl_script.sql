CREATE DATABASE IF NOT EXISTS retail_sales_db;
USE retail_sales_db;
SET FOREIGN_KEY_CHECKS=0;
DROP TABLE IF EXISTS Order_Details; DROP TABLE IF EXISTS Orders; DROP TABLE IF EXISTS Products; DROP TABLE IF EXISTS Stores; DROP TABLE IF EXISTS Customers;
SET FOREIGN_KEY_CHECKS=1;
CREATE TABLE Customers (Customer_ID INT PRIMARY KEY, Customer_Name VARCHAR(100) NOT NULL, Gender VARCHAR(10), Age INT, City VARCHAR(60), State VARCHAR(60), Signup_Date DATE);
CREATE TABLE Products (Product_ID INT PRIMARY KEY, Product_Name VARCHAR(120) NOT NULL, Category VARCHAR(60), Sub_Category VARCHAR(60), Unit_Cost DECIMAL(12,2), Unit_Price DECIMAL(12,2));
CREATE TABLE Stores (Store_ID INT PRIMARY KEY, Store_Name VARCHAR(120) NOT NULL, City VARCHAR(60), State VARCHAR(60), Region VARCHAR(20));
CREATE TABLE Orders (Order_ID INT PRIMARY KEY, Customer_ID INT NOT NULL, Store_ID INT NOT NULL, Order_Date DATE, Payment_Mode VARCHAR(30), Order_Status VARCHAR(20), FOREIGN KEY (Customer_ID) REFERENCES Customers(Customer_ID), FOREIGN KEY (Store_ID) REFERENCES Stores(Store_ID));
CREATE TABLE Order_Details (Order_Detail_ID INT PRIMARY KEY, Order_ID INT NOT NULL, Product_ID INT NOT NULL, Quantity INT NOT NULL, Discount DECIMAL(5,2) NOT NULL DEFAULT 0, Unit_Price DECIMAL(12,2) NOT NULL, FOREIGN KEY (Order_ID) REFERENCES Orders(Order_ID), FOREIGN KEY (Product_ID) REFERENCES Products(Product_ID));
CREATE INDEX idx_orders_date ON Orders(Order_Date);
CREATE INDEX idx_orders_customer ON Orders(Customer_ID);
CREATE INDEX idx_orders_store ON Orders(Store_ID);
CREATE INDEX idx_details_product ON Order_Details(Product_ID);
-- Keep the five CSVs in the MySQL client's working directory. Enable LOCAL INFILE if needed.
LOAD DATA LOCAL INFILE 'E:\Retail_sales_projrct_Dataset/Customers.csv' INTO TABLE Customers FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS (Customer_ID, Customer_Name, Gender, Age, City, State, Signup_Date);
LOAD DATA LOCAL INFILE 'E:\Retail_sales_projrct_Dataset/Products.csv' INTO TABLE Products FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS (Product_ID, Product_Name, Category, Sub_Category, Unit_Cost, Unit_Price);
LOAD DATA LOCAL INFILE 'E:\Retail_sales_projrct_Dataset/Stores.csv' INTO TABLE Stores FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS (Store_ID, Store_Name, City, State, Region);
LOAD DATA LOCAL INFILE 'E:\Retail_sales_projrct_Dataset/Orders.csv' INTO TABLE Orders FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS (Order_ID, Customer_ID, Store_ID, Order_Date, Payment_Mode, Order_Status);
LOAD DATA LOCAL INFILE 'E:\Retail_sales_projrct_Dataset/Order_Details.csv' INTO TABLE Order_Details FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS (Order_Detail_ID, Order_ID, Product_ID, Quantity, Discount, Unit_Price);

SELECT 'Customers' table_name,COUNT(*) row_count FROM Customers UNION ALL SELECT 'Products',COUNT(*) FROM Products UNION ALL SELECT 'Stores',COUNT(*) FROM Stores UNION ALL SELECT 'Orders',COUNT(*) FROM Orders UNION ALL SELECT 'Order_Details',COUNT(*) FROM Order_Details;
LOAD DATA LOCAL INFILE
'E:\Retail_sales_projrct_Dataset/Customers.csv'
INTO TABLE Customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
LOAD DATA LOCAL INFILE
'E:\Retail_sales_projrct_Dataset/stores.csv'
INTO TABLE Customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Q1: Check total row counts across all 5 core tables
SELECT 'Customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'Products', COUNT(*) FROM products
UNION ALL SELECT 'Stores', COUNT(*) FROM stores
UNION ALL SELECT 'Orders', COUNT(*) FROM orders
UNION ALL SELECT 'Order_Details', COUNT(*) FROM order_details;

-- Q2: Check for duplicate primary keys in Order_Details
SELECT Order_Detail_ID, COUNT(*) AS duplicate_count
FROM order_details
GROUP BY Order_Detail_ID
HAVING COUNT(*) > 1;

-- Q3: Audit orphaned foreign keys (Orders without valid Customers or Stores)
SELECT o.Order_ID, o.Customer_ID, o.Store_ID
FROM orders o
LEFT JOIN customers c ON o.Customer_ID = c.Customer_ID
LEFT JOIN stores s ON o.Store_ID = s.Store_ID
WHERE c.Customer_ID IS NULL OR s.Store_ID IS NULL;

-- Q4: Audit invalid quantities, negative prices, or out-of-range discounts
SELECT *
FROM order_details
WHERE Quantity <= 0 OR Unit_Price <= 0 OR Discount < 0 OR Discount > 1;

-- Q5: Identify price variance between catalog Unit_Price and transaction Unit_Price
SELECT 
    od.Product_ID,
    p.Product_Name,
    p.Unit_Price AS catalog_price,
    ROUND(AVG(od.Unit_Price), 2) AS avg_sold_price,
    ROUND(AVG(od.Unit_Price - p.Unit_Price), 2) AS price_diff
FROM order_details od
JOIN products p ON od.Product_ID = p.Product_ID
GROUP BY od.Product_ID, p.Product_Name, p.Unit_Price
HAVING ABS(price_diff) > 100
ORDER BY ABS(price_diff) DESC;

-- Q6: Create Master Analytical View for Power BI & downstream reporting
CREATE OR REPLACE VIEW vw_retail_sales AS
SELECT 
    od.Order_Detail_ID,
    o.Order_ID,
    o.Order_Date,
    YEAR(o.Order_Date) AS order_year,
    MONTH(o.Order_Date) AS order_month,
    DATE_FORMAT(o.Order_Date, '%Y-%m') AS year_month_key,
    o.Order_Status,
    o.Payment_Mode,
    c.Customer_ID,
    c.Customer_Name,
    c.Gender,
    c.Age,
    CASE 
        WHEN c.Age BETWEEN 18 AND 25 THEN '18-25'
        WHEN c.Age BETWEEN 26 AND 35 THEN '26-35'
        WHEN c.Age BETWEEN 36 AND 45 THEN '36-45'
        ELSE '46+'
    END AS age_group,
    s.Store_ID,
    s.Store_Name,
    s.City AS store_city,
    s.State AS store_state,
    s.Region,
    p.Product_ID,
    p.Product_Name,
    p.Category,
    p.Sub_Category,
    od.Quantity,
    od.Discount,
    od.Unit_Price AS selling_price,
    p.Unit_Cost,
    ROUND(od.Quantity * od.Unit_Price, 2) AS gross_sales,
    ROUND(od.Quantity * od.Unit_Price * (1 - od.Discount), 2) AS net_revenue,
    ROUND(od.Quantity * p.Unit_Cost, 2) AS total_cost,
    ROUND((od.Quantity * od.Unit_Price * (1 - od.Discount)) - (od.Quantity * p.Unit_Cost), 2) AS gross_profit
FROM order_details od
JOIN orders o ON od.Order_ID = o.Order_ID
JOIN products p ON od.Product_ID = p.Product_ID
JOIN stores s ON o.Store_ID = s.Store_ID
JOIN customers c ON o.Customer_ID = c.Customer_ID;
-- Q7: Executive KPI summary for Completed Orders
SELECT 
    COUNT(DISTINCT Order_ID) AS completed_orders,
    SUM(Quantity) AS total_units_sold,
    ROUND(SUM(net_revenue), 2) AS total_net_revenue,
    ROUND(SUM(gross_profit), 2) AS total_gross_profit,
    ROUND((SUM(gross_profit) / SUM(net_revenue)) * 100, 2) AS profit_margin_pct,
    ROUND(SUM(net_revenue) / COUNT(DISTINCT Order_ID), 2) AS avg_order_value
FROM vw_retail_sales
WHERE Order_Status = 'Completed';

-- Q8: Order status breakdown (Completed vs Returned vs Cancelled)
SELECT 
    Order_Status,
    COUNT(DISTINCT Order_ID) AS order_count,
    ROUND(COUNT(DISTINCT Order_ID) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS pct_share
FROM orders
GROUP BY Order_Status
ORDER BY order_count DESC;

-- Q9: Year-over-Year (YoY) revenue and profit growth (2023–2025)
WITH yearly_sales AS (
    SELECT 
        order_year,
        ROUND(SUM(net_revenue), 2) AS revenue,
        ROUND(SUM(gross_profit), 2) AS profit
    FROM vw_retail_sales
    WHERE Order_Status = 'Completed'
    GROUP BY order_year
)
SELECT 
    order_year,
    revenue,
    profit,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY order_year)) / LAG(revenue) OVER (ORDER BY order_year) * 100, 2) AS yoy_revenue_growth_pct
FROM yearly_sales;

-- Q10: Monthly revenue trend with 3-month moving average
WITH monthly_rev AS (
    SELECT 
        year_month_key,
        ROUND(SUM(net_revenue), 2) AS monthly_revenue
    FROM vw_retail_sales
    WHERE Order_Status = 'Completed'
    GROUP BY year_month_key
)
SELECT 
    year_month_key,
    monthly_revenue,
    ROUND(AVG(monthly_revenue) OVER (ORDER BY year_month_key ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS rolling_3m_avg
FROM monthly_rev;

-- Q11: Payment mode adoption and average ticket size
SELECT 
    Payment_Mode,
    COUNT(DISTINCT Order_ID) AS total_orders,
    ROUND(SUM(net_revenue), 2) AS net_revenue,
    ROUND(SUM(net_revenue) / COUNT(DISTINCT Order_ID), 2) AS avg_ticket_size
FROM vw_retail_sales
WHERE Order_Status = 'Completed'
GROUP BY Payment_Mode
ORDER BY total_orders DESC;
-- -- -------------------------------------------------------
-- Q12: Revenue, profit margin, and discount rate by Product Category
SELECT 
    Category,
    SUM(Quantity) AS units_sold,
    ROUND(SUM(net_revenue), 2) AS net_revenue,
    ROUND(SUM(gross_profit), 2) AS gross_profit,
    ROUND((SUM(gross_profit) / SUM(net_revenue)) * 100, 2) AS margin_pct,
    ROUND(AVG(Discount) * 100, 2) AS avg_discount_pct
FROM vw_retail_sales
WHERE Order_Status = 'Completed'
GROUP BY Category
ORDER BY net_revenue DESC;

-- Q13: Top 3 Sub-Categories within each Category using DENSE_RANK
WITH subcat_sales AS (
    SELECT 
        Category,
        Sub_Category,
        ROUND(SUM(net_revenue), 2) AS net_revenue,
        DENSE_RANK() OVER (PARTITION BY Category ORDER BY SUM(net_revenue) DESC) AS rnk
    FROM vw_retail_sales
    WHERE Order_Status = 'Completed'
    GROUP BY Category, Sub_Category
)
SELECT Category, Sub_Category, net_revenue, rnk
FROM subcat_sales
WHERE rnk <= 3;

-- Q14: Regional performance & revenue per store efficiency
SELECT 
    Region,
    COUNT(DISTINCT Store_ID) AS active_stores,
    COUNT(DISTINCT Order_ID) AS total_orders,
    ROUND(SUM(net_revenue), 2) AS net_revenue,
    ROUND(SUM(net_revenue) / COUNT(DISTINCT Store_ID), 2) AS avg_revenue_per_store
FROM vw_retail_sales
WHERE Order_Status = 'Completed'
GROUP BY Region
ORDER BY net_revenue DESC;

-- Q15: Top 10 Stores by Net Revenue and Profit Margin
SELECT 
    Store_Name,
    store_city,
    Region,
    SUM(Quantity) AS units_sold,
    ROUND(SUM(net_revenue), 2) AS net_revenue,
    ROUND((SUM(gross_profit) / SUM(net_revenue)) * 100, 2) AS margin_pct
FROM vw_retail_sales
WHERE Order_Status = 'Completed'
GROUP BY Store_Name, store_city, Region
ORDER BY net_revenue DESC
LIMIT 10;

-- Q16: Customer spend & category preference by Age Group
SELECT 
    age_group,
    COUNT(DISTINCT Customer_ID) AS unique_buyers,
    COUNT(DISTINCT Order_ID) AS total_orders,
    ROUND(SUM(net_revenue), 2) AS total_spend,
    ROUND(SUM(net_revenue) / COUNT(DISTINCT Customer_ID), 2) AS avg_spend_per_customer
FROM vw_retail_sales
WHERE Order_Status = 'Completed'
GROUP BY age_group
ORDER BY total_spend DESC;

-- Q17: Discount tier impact on unit volume and profitability
SELECT 
    CASE 
        WHEN Discount = 0 THEN '0% (Full Price)'
        WHEN Discount <= 0.10 THEN '1% - 10%'
        ELSE '11% - 20%'
    END AS discount_tier,
    COUNT(*) AS line_items,
    ROUND(AVG(Quantity), 2) AS avg_units_per_line,
    ROUND((SUM(gross_profit) / SUM(net_revenue)) * 100, 2) AS margin_pct
FROM vw_retail_sales
WHERE Order_Status = 'Completed'
GROUP BY discount_tier
ORDER BY margin_pct DESC;

-- --------------------------------------------

-- Q18: ABC Inventory Classification based on cumulative revenue contribution
WITH sku_revenue AS (
    SELECT 
        Product_ID,
        Product_Name,
        Category,
        SUM(Quantity) AS total_units,
        SUM(net_revenue) AS revenue
    FROM vw_retail_sales
    WHERE Order_Status = 'Completed'
    GROUP BY Product_ID, Product_Name, Category
),
cumulative_calc AS (
    SELECT 
        *,
        SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER () AS cum_rev_pct
    FROM sku_revenue
)
SELECT 
    Product_ID,
    Product_Name,
    Category,
    total_units,
    ROUND(revenue, 2) AS revenue,
    CASE 
        WHEN cum_rev_pct <= 0.70 THEN 'Class A (High Priority)'
        WHEN cum_rev_pct <= 0.90 THEN 'Class B (Medium Priority)'
        ELSE 'Class C (Low Priority)'
    END AS abc_class
FROM cumulative_calc;

-- Q19: High-Velocity & High-Volatility SKUs (Stockout Risk Quadrant)
WITH monthly_sku_demand AS (
    SELECT 
        Product_ID,
        Product_Name,
        Category,
        year_month_key,
        SUM(Quantity) AS monthly_units
    FROM vw_retail_sales
    WHERE Order_Status = 'Completed'
    GROUP BY Product_ID, Product_Name, Category, year_month_key
)
SELECT 
    Product_ID,
    Product_Name,
    Category,
    ROUND(AVG(monthly_units), 2) AS avg_monthly_velocity,
    ROUND(STDDEV(monthly_units), 2) AS demand_volatility,
    ROUND(STDDEV(monthly_units) / NULLIF(AVG(monthly_units), 0), 2) AS coeff_of_variation
FROM monthly_sku_demand
GROUP BY Product_ID, Product_Name, Category
HAVING avg_monthly_velocity >= 5
ORDER BY demand_volatility DESC
LIMIT 20;

-- Q20: Store-Category pairs with highest Order Cancellation Rates (proxy for fulfillment/stockout friction)
SELECT 
    s.Store_Name,
    s.Region,
    p.Category,
    COUNT(DISTINCT o.Order_ID) AS total_orders,
    COUNT(DISTINCT CASE WHEN o.Order_Status = 'Cancelled' THEN o.Order_ID END) AS cancelled_orders,
    ROUND(COUNT(DISTINCT CASE WHEN o.Order_Status = 'Cancelled' THEN o.Order_ID END) * 100.0 / COUNT(DISTINCT o.Order_ID), 2) AS cancellation_rate_pct
FROM orders o
JOIN order_details od ON o.Order_ID = od.Order_ID
JOIN products p ON od.Product_ID = p.Product_ID
JOIN stores s ON o.Store_ID = s.Store_ID
GROUP BY s.Store_Name, s.Region, p.Category
HAVING total_orders >= 50
ORDER BY cancellation_rate_pct DESC
LIMIT 15;

-- Q21: Month-over-Month demand surge detector (>40% spike alerts for safety stock rebalancing)
WITH monthly_cat_units AS (
    SELECT 
        Category,
        year_month_key,
        SUM(Quantity) AS units_sold
    FROM vw_retail_sales
    WHERE Order_Status = 'Completed'
    GROUP BY Category, year_month_key
),
mom_spikes AS (
    SELECT 
        Category,
        year_month_key,
        units_sold,
        LAG(units_sold) OVER (PARTITION BY Category ORDER BY year_month_key) AS prev_month_units
    FROM monthly_cat_units
)
SELECT 
    Category,
    year_month_key,
    prev_month_units,
    units_sold,
    ROUND((units_sold - prev_month_units) * 100.0 / prev_month_units, 2) AS mom_surge_pct
FROM mom_spikes
WHERE prev_month_units IS NOT NULL
  AND ((units_sold - prev_month_units) * 100.0 / prev_month_units) > 40
ORDER BY mom_surge_pct DESC;