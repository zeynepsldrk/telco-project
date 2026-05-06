-- ============================================================
-- TELCO PROJECT - TABLE CREATION SCRIPTS
-- Developer: Zeynep Sıla Durak
-- Date: 2026-05-06
-- Database: Oracle XE 21c
-- ============================================================

-- ------------------------------------------------------------
-- DROP existing tables (run if re-creating from scratch)
-- ------------------------------------------------------------
-- DROP TABLE monthly_usage;
-- DROP TABLE payments;
-- DROP TABLE customers;
-- DROP TABLE tariffs;
-- DROP TABLE cities;

-- ------------------------------------------------------------
-- 1. CITIES Table
-- Stores unique city names derived from the customers CSV.
-- City names are stored in uppercase to match the source data.
-- A surrogate primary key (city_id) is used so that customers
-- reference cities by ID rather than by the raw string value,
-- which avoids data anomalies if a city name is ever corrected.
-- ------------------------------------------------------------
CREATE TABLE cities (
    city_id   NUMBER PRIMARY KEY,
    city_name VARCHAR2(100) NOT NULL,
    CONSTRAINT uq_city_name UNIQUE (city_name)
);

CREATE INDEX idx_cities_name ON cities(city_name);

-- ------------------------------------------------------------
-- 2. TARIFFS Table
-- Maps directly to tariff.csv columns.
-- TARIFF_ID comes from the CSV and is used as the primary key.
-- DATA_LIMIT, MINUTE_LIMIT and SMS_LIMIT store the monthly
-- quota values; a value of 0 means the package has no
-- allowance for that resource (e.g. Kurumsal SMS has 0 MB data).
-- ------------------------------------------------------------
CREATE TABLE tariffs (
    tariff_id      NUMBER PRIMARY KEY,           -- CSV: TARIFF_ID
    tariff_name    VARCHAR2(150) NOT NULL,        -- CSV: NAME
    monthly_fee    NUMBER(10,2)  NOT NULL,        -- CSV: MONTHLY_FEE
    data_limit_mb  NUMBER(10,2)  NOT NULL,        -- CSV: DATA_LIMIT
    minutes_limit  NUMBER(8,2)   NOT NULL,        -- CSV: MINUTE_LIMIT
    sms_limit      NUMBER(8,2)   NOT NULL,        -- CSV: SMS_LIMIT
    CONSTRAINT uq_tariff_name UNIQUE (tariff_name),
    CONSTRAINT chk_data_limit   CHECK (data_limit_mb  >= 0),
    CONSTRAINT chk_minutes      CHECK (minutes_limit  >= 0),
    CONSTRAINT chk_sms          CHECK (sms_limit      >= 0),
    CONSTRAINT chk_monthly_fee  CHECK (monthly_fee    >= 0)
);

CREATE INDEX idx_tariffs_name ON tariffs(tariff_name);

-- ------------------------------------------------------------
-- 3. CUSTOMERS Table
-- Maps to customer.csv. The source data provides a single NAME
-- column rather than separate first/last name fields, so we
-- store it as a single full_name column to preserve fidelity.
-- CITY is resolved to a foreign key via the cities lookup table.
-- SIGNUP_DATE is stored as DATE; source format is DD/MM/YYYY.
-- ------------------------------------------------------------
CREATE TABLE customers (
    customer_id   NUMBER PRIMARY KEY,            -- CSV: CUSTOMER_ID
    full_name     VARCHAR2(200) NOT NULL,         -- CSV: NAME
    city_id       NUMBER        NOT NULL,         -- CSV: CITY (resolved)
    signup_date   DATE          NOT NULL,         -- CSV: SIGNUP_DATE
    tariff_id     NUMBER        NOT NULL,         -- CSV: TARIFF_ID
    CONSTRAINT fk_cust_city   FOREIGN KEY (city_id)   REFERENCES cities(city_id),
    CONSTRAINT fk_cust_tariff FOREIGN KEY (tariff_id) REFERENCES tariffs(tariff_id)
);

CREATE INDEX idx_cust_city      ON customers(city_id);
CREATE INDEX idx_cust_tariff    ON customers(tariff_id);
CREATE INDEX idx_cust_signup    ON customers(signup_date);

-- ------------------------------------------------------------
-- 4. MONTHLY_USAGE Table
-- Maps to monthly_stats.csv usage columns.
-- The ID column from the CSV is used directly as the primary key.
-- RECORD_MONTH is populated as the first day of the current
-- billing month (TRUNC(SYSDATE,'MM')) since the CSV does not
-- include a month column — the file represents this month only.
-- ------------------------------------------------------------
CREATE TABLE monthly_usage (
    usage_id       NUMBER PRIMARY KEY,           -- CSV: ID
    customer_id    NUMBER        NOT NULL,        -- CSV: CUSTOMER_ID
    record_month   DATE          NOT NULL,        -- Derived: current month
    used_data_mb   NUMBER(10,2)  DEFAULT 0 NOT NULL,  -- CSV: DATA_USAGE
    used_minutes   NUMBER(8,2)   DEFAULT 0 NOT NULL,  -- CSV: MINUTE_USAGE
    used_sms       NUMBER(8,2)   DEFAULT 0 NOT NULL,  -- CSV: SMS_USAGE
    CONSTRAINT fk_usage_cust  FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT uq_usage_month UNIQUE (customer_id, record_month),
    CONSTRAINT chk_used_data  CHECK (used_data_mb  >= 0),
    CONSTRAINT chk_used_min   CHECK (used_minutes  >= 0),
    CONSTRAINT chk_used_sms   CHECK (used_sms      >= 0)
);

CREATE INDEX idx_usage_customer ON monthly_usage(customer_id);
CREATE INDEX idx_usage_month    ON monthly_usage(record_month);

-- ------------------------------------------------------------
-- 5. PAYMENTS Table
-- Derived from the PAYMENT_STATUS column in monthly_stats.csv.
-- Each monthly_usage record has exactly one payment record,
-- so we use the same ID as the primary key for traceability.
-- BILLING_MONTH mirrors RECORD_MONTH from monthly_usage.
-- AMOUNT is looked up from the tariffs table via the customer.
-- ------------------------------------------------------------
CREATE TABLE payments (
    payment_id    NUMBER PRIMARY KEY,            -- Same as usage_id
    customer_id   NUMBER        NOT NULL,        -- CSV: CUSTOMER_ID
    tariff_id     NUMBER        NOT NULL,        -- Derived from customers
    billing_month DATE          NOT NULL,        -- Current billing month
    amount        NUMBER(10,2)  NOT NULL,        -- From tariffs.monthly_fee
    status        VARCHAR2(20)  DEFAULT 'UNPAID' NOT NULL,  -- CSV: PAYMENT_STATUS
    payment_date  DATE,
    CONSTRAINT fk_pay_cust   FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_pay_tariff FOREIGN KEY (tariff_id)   REFERENCES tariffs(tariff_id),
    CONSTRAINT uq_pay_month  UNIQUE (customer_id, billing_month),
    CONSTRAINT chk_pay_amt   CHECK (amount >= 0),
    CONSTRAINT chk_pay_stat  CHECK (status IN ('PAID','UNPAID','PENDING','OVERDUE'))
);

CREATE INDEX idx_pay_customer ON payments(customer_id);
CREATE INDEX idx_pay_status   ON payments(status);
CREATE INDEX idx_pay_tariff   ON payments(tariff_id);

-- ============================================================
-- END OF TABLE CREATION SCRIPTS
-- ============================================================