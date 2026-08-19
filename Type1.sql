--Run this block to create the database and schema
create database Workshop_GCOEARA_2026;
use database Workshop_GCOEARA_2026;
create schema Learning_SCD;
use schema Learning_SCD;

----------------------------------------------------------------------------------------------------------------------------------------------
--Now lets create our facts and dimension tables

-- The SALES_REP table is our dimension table for sales representatives.
CREATE OR REPLACE TABLE sales_rep (
    sales_rep_id INT PRIMARY KEY,
    sales_rep_name VARCHAR(255)
);

-- The CUSTOMERS table is our second dimension table. It links a customer
-- to their assigned sales representative.
CREATE OR REPLACE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(255),
    sales_rep_id INT
);

-- The SALES table is our fact table. It records every sales transaction.
-- This table will only have a customer_id, demonstrating why we need
-- to join it to the dimension table to get sales rep information.
CREATE OR REPLACE TABLE sales (
    transaction_id INT PRIMARY KEY,
    customer_id INT,
    sale_amount FLOAT,
    transaction_date DATE
);


--------------------------------------------------------------------------------------------------------------------------------------------

--now lets load some sample data

-- Insert initial sales representatives
INSERT INTO sales_rep (sales_rep_id, sales_rep_name)
VALUES
(1, 'Ajit Thorat'),
(2, 'Rashi Joshi'),
(3, 'Priya Patil');

-- Insert initial customer data with their assigned sales rep
INSERT INTO customers (customer_id, customer_name, sales_rep_id)
VALUES
(101, 'Innovate Solutions Ltd.', 1),
(102, 'TechMantra Pvt. Ltd.', 1),
(103, 'Global Connect Inc.', 2);

-- Insert initial sales transactions
INSERT INTO sales (transaction_id, customer_id, sale_amount, transaction_date)
VALUES
(1001, 101, 250, '2024-01-10'),
(1002, 102, 500, '2024-01-12'),
(1003, 103, 1200, '2024-01-15'),
(1004, 101, 310, '2024-02-05'),
(1005, 102, 750, '2024-02-18'),
(1006, 103, 6000, '2024-02-25'),
(1007, 101, 450, '2024-03-01'),
(1008, 102, 150, '2024-03-08'),
(1009, 103, 32000, '2024-03-14'),
(1010, 101, 190, '2024-03-20'),
(1011, 102, 800, '2024-03-25'),
(1012, 103, 28000, '2024-03-28'),
(1013, 101, 500, '2024-03-29'),
(1014, 102, 900, '2024-03-30'),
(1015, 103, 41000, '2024-03-30');

------------------------------------------------------------------------------------------------------------------------------------------------------


--- Current Sales Rep Assignment
SELECT
    c.customer_id,
    c.customer_name,
    c.sales_rep_id AS current_sales_rep_id,
    sr.sales_rep_name AS current_sales_rep_name
FROM customers c
JOIN sales_rep sr ON c.sales_rep_id = sr.sales_rep_id
ORDER BY c.customer_id;
-----------------------------------------------------------------------------------------------------
-- lets also check how the bonus calculations are looking for our sales rep
SELECT
    sr.sales_rep_name,
    SUM(s.sale_amount) AS total_sales,
    SUM(s.sale_amount)*0.1 as Bonus
FROM sales s
JOIN customers c
    ON s.customer_id = c.customer_id
JOIN sales_rep sr
    ON c.sales_rep_id = sr.sales_rep_id
GROUP BY sr.sales_rep_name
ORDER BY sr.sales_rep_name;



-- Our company does some quarterly reassignments. Let's imagine we've received a file with the changes 
-- lets's suppose Ajit has left. And Priya was assigned Global connect and innovate and Rashi was assigned to the new customer and techmantra

CREATE OR REPLACE TRANSIENT TABLE customer_reassignment_stage (
    customer_id INTEGER,
    customer_name VARCHAR(255),
    sales_rep_id INTEGER
);

INSERT INTO customer_reassignment_stage (customer_id, customer_name, sales_rep_id)
VALUES
    (101, 'Innovate Solutions Ltd.', 3),
    (102, 'TechMantra Pvt. Ltd.', 2),
    (103, 'Global Connect Inc.', 3),
    (104, 'Fusion Dynamics', 2);
-------------------------------------------------------------------------------------------------------------------------------------


Now, 
-- Let's update our customer dimension table

MERGE INTO customers AS target
USING customer_reassignment_stage AS source
ON target.customer_id = source.customer_id
WHEN MATCHED THEN
    -- This is the core of SCD Type 1: Overwriting the data
    UPDATE SET target.sales_rep_id = source.sales_rep_id
WHEN NOT MATCHED THEN
    -- This handles new customers from the staging table that don't exist yet
    -- in our main customers table.
    INSERT (customer_id, customer_name, sales_rep_id)
    VALUES (source.customer_id, source.customer_name, source.sales_rep_id);
    
---------------------------------------------------------------------------------------------------------------------------------------

--It's bonus disbursment day. Let's reward our sales rep with the bonus for the sales they brought for us.


SELECT
    sr.sales_rep_name,
    SUM(s.sale_amount) AS total_sales
FROM sales s
JOIN customers c
    ON s.customer_id = c.customer_id
JOIN sales_rep sr
    ON c.sales_rep_id = sr.sales_rep_id
GROUP BY sr.sales_rep_name
ORDER BY sr.sales_rep_name;



----------------------------------------------------------------------------------------------------------------------------------

-- Well , that was a bit unfair to Ajit and Rashi :( 


---------- this is the a new line