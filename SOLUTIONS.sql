-- ============================================================
-- TELCO PROJECT - SOLUTIONS
-- Developer: Zeynep Sıla Durak
-- Date: 2026-05-06
-- Database: Oracle XE 21c
-- ============================================================

-- ============================================================
-- QUESTION 1: Tariff-Based Customer Queries
-- ============================================================

-- ------------------------------------------------------------
-- 1.1 List customers subscribed to 'Kobiye Destek' tariff
-- ------------------------------------------------------------
/*
  APPROACH:
  We join the customers table with the tariffs table using the tariff_id
  foreign key to filter only the customers whose tariff name is 'Kobiye Destek'.
  The city name is also fetched by joining the cities table to make the output
  more readable and meaningful for business users.
  The result set includes customer ID, full name, city, and their
  subscription (signup) date, ordered alphabetically by full name.
*/
SELECT
    c.customer_id,
    c.full_name,
    ci.city_name,
    c.signup_date,
    t.tariff_name
FROM
    customers c
    JOIN cities  ci ON c.city_id   = ci.city_id
    JOIN tariffs t  ON c.tariff_id = t.tariff_id
WHERE
    t.tariff_name = 'Kobiye Destek'
ORDER BY
    c.full_name;

-- Simplified version (no redundant join):
SELECT
    c.customer_id,
    c.full_name,
    ci.city_name,
    c.signup_date
FROM
    customers c
    JOIN tariffs t  ON c.tariff_id = t.tariff_id
    JOIN cities  ci ON c.city_id   = ci.city_id
WHERE
    t.tariff_name = 'Kobiye Destek'
ORDER BY
    c.full_name;

-- ------------------------------------------------------------
-- 1.2 Find the NEWEST customer who subscribed to 'Kobiye Destek'
-- ------------------------------------------------------------
/*
  APPROACH:
  To identify the newest subscriber, we need the maximum signup_date among
  all customers on the 'Kobiye Destek' tariff. We use a subquery in the WHERE
  clause that retrieves the MAX(signup_date) for that tariff group.
  In the rare case where two customers signed up on the exact same latest date,
  this query will return all of them; this is intentional and correct behavior.
  No ROWNUM or FETCH FIRST is used to avoid accidentally hiding ties.
*/
SELECT
    c.customer_id,
    c.full_name,
    ci.city_name,
    c.signup_date
FROM
    customers c
    JOIN tariffs t  ON c.tariff_id = t.tariff_id
    JOIN cities  ci ON c.city_id   = ci.city_id
WHERE
    t.tariff_name = 'Kobiye Destek'
    AND c.signup_date = (
        SELECT MAX(c2.signup_date)
        FROM customers c2
        JOIN tariffs t2 ON c2.tariff_id = t2.tariff_id
        WHERE t2.tariff_name = 'Kobiye Destek'
    );

-- ============================================================
-- QUESTION 2: Tariff Distribution
-- ============================================================

-- ------------------------------------------------------------
-- 2.1 Find the distribution of tariffs among customers
-- ------------------------------------------------------------
/*
  APPROACH:
  We group all customers by their subscribed tariff and count the number of
  subscribers for each tariff using GROUP BY and COUNT(*). To express the
  proportion of each tariff relative to the entire customer base, we calculate
  a percentage using analytic SUM() OVER() which gives the grand total without
  a separate subquery, keeping the SQL clean and efficient.
  Results are ordered by subscriber count in descending order so the most
  popular tariff appears at the top.
*/
SELECT
    t.tariff_name,
    COUNT(c.customer_id)                                          AS subscriber_count,
    ROUND(
        COUNT(c.customer_id) * 100.0
        / SUM(COUNT(c.customer_id)) OVER (),
        2
    )                                                             AS percentage_pct
FROM
    customers c
    JOIN tariffs t ON c.tariff_id = t.tariff_id
GROUP BY
    t.tariff_name
ORDER BY
    subscriber_count DESC;

-- ============================================================
-- QUESTION 3: Customer Signup Analysis
-- ============================================================

-- ------------------------------------------------------------
-- 3.1 Identify the EARLIEST customers to sign up
-- ------------------------------------------------------------
/*
  APPROACH:
  The hint explicitly warns that the earliest customers may NOT have the lowest
  customer_id values — this means we cannot rely on ID ordering. Instead, we
  must rank customers by their actual signup_date column. We use DENSE_RANK()
  OVER (ORDER BY signup_date ASC) to correctly handle ties: all customers who
  signed up on the very first date receive rank 1 and are all included.
  Using MIN(signup_date) in a subquery would also work, but the DENSE_RANK
  approach is more flexible if we later want to extend to top-N earliest batches.
*/
SELECT
    c.customer_id,
    c.full_name,
    ci.city_name,
    t.tariff_name,
    c.signup_date
FROM (
    SELECT
        customer_id,
        full_name,
        city_id,
        tariff_id,
        signup_date,
        DENSE_RANK() OVER (ORDER BY signup_date ASC) AS signup_rank
    FROM customers
) c
JOIN cities  ci ON c.city_id   = ci.city_id
JOIN tariffs t  ON c.tariff_id = t.tariff_id
WHERE
    c.signup_rank = 1
ORDER BY
    c.signup_date;

-- ------------------------------------------------------------
-- 3.2 Distribution of earliest customers across cities
-- ------------------------------------------------------------
/*
  APPROACH:
  Building on the earliest-customer set identified in 3.1, we now aggregate
  those customers by city to understand the geographic distribution of the
  founding customer base. We reuse the same DENSE_RANK() logic inside a CTE
  (Common Table Expression) for readability and to avoid repeating the subquery.
  The total count for each city is computed with COUNT(*) inside the GROUP BY,
  and an additional overall total row is added using ROLLUP to give a grand sum.
*/
WITH earliest_customers AS (
    SELECT
        c.customer_id,
        c.city_id,
        DENSE_RANK() OVER (ORDER BY c.signup_date ASC) AS signup_rank
    FROM customers c
)
SELECT
    ci.city_name,
    COUNT(ec.customer_id) AS customer_count
FROM
    earliest_customers ec
    JOIN cities ci ON ec.city_id = ci.city_id
WHERE
    ec.signup_rank = 1
GROUP BY
    ROLLUP(ci.city_name)
ORDER BY
    customer_count DESC NULLS LAST;

-- ============================================================
-- QUESTION 4: Missing Monthly Records
-- ============================================================

-- ------------------------------------------------------------
-- 4.1 Identify customer IDs whose monthly record is missing
-- ------------------------------------------------------------
/*
  APPROACH:
  The monthly_usage table should contain exactly one record per customer for
  the current billing month. To find customers whose records are absent, we
  use a LEFT JOIN from customers to monthly_usage filtered to the current month
  and select only the rows where the join found no match (usage_id IS NULL).
  This is the standard "anti-join" pattern in SQL and is more efficient than
  a NOT IN subquery, especially when the subquery might return NULLs which
  could cause NOT IN to return no rows at all.
  We define "this month" dynamically using TRUNC(SYSDATE, 'MM') so the query
  remains valid across month boundaries without manual updates.
*/
SELECT
    c.customer_id,
    c.full_name,
    ci.city_name,
    t.tariff_name
FROM
    customers c
    LEFT JOIN monthly_usage mu
        ON  c.customer_id  = mu.customer_id
        AND mu.record_month = TRUNC(SYSDATE, 'MM')
    JOIN cities  ci ON c.city_id   = ci.city_id
    JOIN tariffs t  ON c.tariff_id = t.tariff_id
WHERE
    mu.usage_id IS NULL
ORDER BY
    c.customer_id;

-- ------------------------------------------------------------
-- 4.2 Distribution of missing customers across cities
-- ------------------------------------------------------------
/*
  APPROACH:
  We extend the anti-join from 4.1 by grouping the results by city. This
  reveals which geographic areas are most affected by the insertion error,
  which is important information for diagnosing whether the issue is
  systemic (e.g., a specific regional data pipeline failed) or random.
  The percentage column helps quantify each city's share of the missing records
  relative to the total number of affected customers across all cities.
*/
SELECT
    ci.city_name,
    COUNT(c.customer_id)                                          AS missing_count,
    ROUND(
        COUNT(c.customer_id) * 100.0
        / SUM(COUNT(c.customer_id)) OVER (),
        2
    )                                                             AS percentage_pct
FROM
    customers c
    LEFT JOIN monthly_usage mu
        ON  c.customer_id  = mu.customer_id
        AND mu.record_month = TRUNC(SYSDATE, 'MM')
    JOIN cities ci ON c.city_id = ci.city_id
WHERE
    mu.usage_id IS NULL
GROUP BY
    ci.city_name
ORDER BY
    missing_count DESC;

-- ============================================================
-- QUESTION 5: Usage Analysis
-- ============================================================

-- ------------------------------------------------------------
-- 5.1 Customers who have used at least 75% of their DATA limit
-- ------------------------------------------------------------
/*
  APPROACH:
  We calculate the data usage ratio by dividing used_data_mb by the tariff's
  data_limit_mb for each customer's current-month usage record. The 75%
  threshold is expressed as 0.75 to avoid integer division pitfalls in SQL.
  A CASE WHEN guard against division by zero is included for tariffs that
  might theoretically have a 0 MB data limit (unlimited flag edge case).
  The result includes the actual usage and limit figures to make the output
  immediately interpretable by business stakeholders without further lookups.
*/
SELECT
    c.customer_id,
    c.full_name,
    ci.city_name,
    t.tariff_name,
    t.data_limit_mb,
    mu.used_data_mb,
    ROUND(
        CASE WHEN t.data_limit_mb = 0 THEN 0
             ELSE mu.used_data_mb / t.data_limit_mb * 100
        END,
        2
    )                                                              AS data_usage_pct
FROM
    customers c
    JOIN tariffs       t  ON c.tariff_id    = t.tariff_id
    JOIN cities        ci ON c.city_id      = ci.city_id
    JOIN monthly_usage mu ON c.customer_id  = mu.customer_id
                          AND mu.record_month = TRUNC(SYSDATE, 'MM')
WHERE
    t.data_limit_mb > 0
    AND mu.used_data_mb / t.data_limit_mb >= 0.75
ORDER BY
    data_usage_pct DESC;

-- ------------------------------------------------------------
-- 5.2 Customers who exhausted ALL package limits (data + minutes + SMS)
-- ------------------------------------------------------------
/*
  APPROACH:
  A customer is considered to have "completely exhausted" their package only
  when all three limits — data, voice minutes, and SMS — are fully consumed
  (used value >= limit value). We apply all three conditions simultaneously
  in the WHERE clause joined with AND, so only customers who breach every
  single limit are returned.
  This is a stricter superset of question 5.1 and provides a list of customers
  who are most likely to be experiencing service interruptions or throttling,
  making it actionable for customer support teams.
*/
SELECT
    c.customer_id,
    c.full_name,
    ci.city_name,
    t.tariff_name,
    -- Data
    t.data_limit_mb,
    mu.used_data_mb,
    -- Minutes
    t.minutes_limit,
    mu.used_minutes,
    -- SMS
    t.sms_limit,
    mu.used_sms
FROM
    customers c
    JOIN tariffs       t  ON c.tariff_id    = t.tariff_id
    JOIN cities        ci ON c.city_id      = ci.city_id
    JOIN monthly_usage mu ON c.customer_id  = mu.customer_id
                          AND mu.record_month = TRUNC(SYSDATE, 'MM')
WHERE
    mu.used_data_mb  >= t.data_limit_mb
    AND mu.used_minutes >= t.minutes_limit
    AND mu.used_sms     >= t.sms_limit
ORDER BY
    c.customer_id;

-- ============================================================
-- QUESTION 6: Payment Analysis
-- ============================================================

-- ------------------------------------------------------------
-- 6.1 Find customers who have UNPAID fees
-- ------------------------------------------------------------
/*
  APPROACH:
  We filter the payments table for records where the status column holds the
  value 'UNPAID' or 'OVERDUE', both of which represent outstanding balances
  that the customer has not yet settled. Joining back to customers and cities
  enriches the result with contact details needed by the collections team.
  The billing_month column is included so that stakeholders can see exactly
  which period is outstanding, enabling proper aging-of-receivables analysis.
*/
SELECT
    c.customer_id,
    c.full_name,
    ci.city_name,
    t.tariff_name,
    p.billing_month,
    p.amount,
    p.status
FROM
    payments p
    JOIN customers c ON p.customer_id = c.customer_id
    JOIN tariffs   t ON p.tariff_id   = t.tariff_id
    JOIN cities   ci ON c.city_id     = ci.city_id
WHERE
    p.status IN ('UNPAID', 'OVERDUE')
ORDER BY
    p.billing_month DESC, c.customer_id;

-- ------------------------------------------------------------
-- 6.2 Distribution of payment statuses across different tariffs
-- ------------------------------------------------------------
/*
  APPROACH:
  This cross-tabulation query shows how payment statuses (PAID, UNPAID,
  PENDING, OVERDUE) are distributed across each tariff plan. We use
  conditional aggregation — COUNT(CASE WHEN status = 'X' THEN 1 END) —
  to produce a pivot-style report in a single pass over the payments table,
  which is far more efficient than multiple subqueries or UNION-based approaches.
  The total_records column provides the row count per tariff for context, and
  a paid_rate percentage column gives a quick quality metric showing what
  fraction of a tariff's bills have been settled.
*/
SELECT
    t.tariff_name,
    COUNT(p.payment_id)                                                   AS total_records,
    COUNT(CASE WHEN p.status = 'PAID'    THEN 1 END)                     AS paid_count,
    COUNT(CASE WHEN p.status = 'UNPAID'  THEN 1 END)                     AS unpaid_count,
    COUNT(CASE WHEN p.status = 'PENDING' THEN 1 END)                     AS pending_count,
    COUNT(CASE WHEN p.status = 'OVERDUE' THEN 1 END)                     AS overdue_count,
    ROUND(
        COUNT(CASE WHEN p.status = 'PAID' THEN 1 END) * 100.0
        / NULLIF(COUNT(p.payment_id), 0),
        2
    )                                                                     AS paid_rate_pct
FROM
    payments p
    JOIN tariffs t ON p.tariff_id = t.tariff_id
GROUP BY
    t.tariff_name
ORDER BY
    total_records DESC;

-- ============================================================
-- END OF SOLUTIONS
-- ============================================================