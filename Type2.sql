use database WORKSHOP_GCOEARA_2026;

CREATE OR REPLACE SCHEMA LEARNING_SCD_TYPE_2;


CREATE OR REPLACE TABLE sales_rep (
    sales_rep_id INT PRIMARY KEY,
    sales_rep_name VARCHAR(255)
);

CREATE OR REPLACE TABLE sales (
    transaction_id INT PRIMARY KEY,
    customer_id INT,
    sale_amount FLOAT,
    transaction_date DATE
);

-- The CUSTOMERS table for SCD Type 2 is a dimension that tracks history.
-- It must have these additional columns to implement the logic correctly.
CREATE OR REPLACE TABLE customers_dim_scd2 (
    customer_id INT,
    customer_name VARCHAR(255),
    sales_rep_id INT,
    effective_start_date DATE,
    effective_end_date DATE,
    is_current BOOLEAN
);

---------------------------------------------------------------------------------------------------

--let's insert some data 


INSERT INTO sales_rep (sales_rep_id, sales_rep_name)
VALUES
(1, 'Ajit Thorat'),
(2, 'Rashi Joshi'),
(3, 'Priya Patil');

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

INSERT INTO customers_dim_scd2 (
    customer_id,
    customer_name,
    sales_rep_id,
    effective_start_date,
    effective_end_date,
    is_current
)
VALUES
    (101, 'Innovate Solutions Ltd.', 1, '2024-01-01'::DATE, '9999-12-31'::DATE, TRUE),
    (102, 'TechMantra Pvt. Ltd.', 1, '2024-01-01'::DATE, '9999-12-31'::DATE, TRUE),
    (103, 'Global Connect Inc.', 2, '2024-01-01'::DATE, '9999-12-31'::DATE, TRUE);

SELECT * FROM customers_dim_scd2 ORDER BY customer_id;



--------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE OR REPLACE TRANSIENT TABLE customer_reassignment_stage (
    customer_id INTEGER,
    customer_name VARCHAR(255),
    sales_rep_id INTEGER,
    change_date DATE
);

-- Insert the reassignment data. We are adding a change_date to mark
-- when the reassignment took place.
INSERT INTO customer_reassignment_stage (customer_id, customer_name, sales_rep_id, change_date)
VALUES
    (101, 'Innovate Solutions Ltd.', 3, '2024-03-31'), -- Innovate Solutions moves from Ajit (1) to Priya (3)
    (102, 'TechMantra Pvt. Ltd.', 2, '2024-03-31'), -- TechMantra moves from Ajit (1) to Rashi (2)
    (103, 'Global Connect Inc.', 3, '2024-03-31'), -- Global Connect moves from Rashi (2) to Priya (3)
    (104, 'Fusion Dynamics', 2, '2024-03-31'); -- A new customer is added

----------------------------------------------------------------------------------------------------------------------------------------

MERGE INTO customers_dim_scd2 AS target
USING customer_reassignment_stage AS source
ON target.customer_id = source.customer_id
WHEN MATCHED AND target.is_current = TRUE THEN
    -- This condition handles records that have changed.
    -- We are updating the old record to "expire" it.
    -- We set the effective_end_date to the day before the change.
    UPDATE SET
        target.effective_end_date = DATEADD('day', -1, source.change_date),
        target.is_current = FALSE

WHEN NOT MATCHED THEN
    -- This condition handles brand new customers.
    -- We simply insert the new record with a full effective date range.
    INSERT (customer_id, customer_name, sales_rep_id, effective_start_date, effective_end_date, is_current)
    VALUES (
        source.customer_id,
        source.customer_name,
        source.sales_rep_id,
        source.change_date,
        '9999-12-31'::DATE,
        TRUE
    );

------------------------------------------------------------------------------------------------------
INSERT INTO customers_dim_scd2 (
    customer_id,
    customer_name,
    sales_rep_id,
    effective_start_date,
    effective_end_date,
    is_current
)
SELECT
    source.customer_id,
    source.customer_name,
    source.sales_rep_id,
    source.change_date AS effective_start_date,
    '9999-12-31'::DATE AS effective_end_date,
    TRUE AS is_current
FROM customer_reassignment_stage source
JOIN customers_dim_scd2 target
ON source.customer_id = target.customer_id
WHERE target.is_current = FALSE;


--------------------------------------------------------------------------------------------------------------------------

SELECT
    customer_id,
    customer_name,
    sales_rep_id,
    effective_start_date,
    effective_end_date,
    is_current
FROM customers_dim_scd2
ORDER BY customer_id, effective_start_date;



SELECT
    sr.sales_rep_name,
    SUM(s.sale_amount) AS total_sales
FROM sales s
JOIN customers_dim_scd2 c
    ON s.customer_id = c.customer_id
-- This is the crucial part: we are joining on both the customer_id AND the date range
-- of the transaction. This is what makes the calculation accurate!
    AND s.transaction_date BETWEEN c.effective_start_date AND c.effective_end_date
JOIN sales_rep sr
    ON c.sales_rep_id = sr.sales_rep_id
GROUP BY sr.sales_rep_name
ORDER BY sr.sales_rep_name;


-------------------------------------------------------------------------------------------------------------------------


INSERT INTO sales (transaction_id, customer_id, sale_amount, transaction_date)
VALUES
    (1016, 101, 300, '2024-04-01'), -- Innovate Solutions sale after reassignment
    (1017, 102, 500, '2024-04-01'), -- TechMantra sale after reassignment
    (1018, 103, 750, '2024-04-01'),  -- Global Connect sale after reassignment
    (1019, 104, 1200, '2024-04-02'); -- Fusion Dynamics sale after initial load



SELECT
    sr.sales_rep_name,
    SUM(s.sale_amount) AS total_sales
FROM sales s
JOIN customers_dim_scd2 c
    ON s.customer_id = c.customer_id
-- This is the crucial part: we are joining on both the customer_id AND the date range
-- of the transaction. This is what makes the calculation accurate!
    AND s.transaction_date BETWEEN c.effective_start_date AND c.effective_end_date
JOIN sales_rep sr
    ON c.sales_rep_id = sr.sales_rep_id
GROUP BY sr.sales_rep_name
ORDER BY sr.sales_rep_name;


