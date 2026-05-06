-- ============================================================
-- AUTO-SEED SCRIPT: Runs automatically when Docker container
-- initialises for the first time.
-- Connected as APP_USER (telco_user) by the entrypoint.
-- ============================================================

-- Cities
CREATE TABLE cities (
    city_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city_name VARCHAR2(100) NOT NULL,
    CONSTRAINT uq_city_name UNIQUE (city_name)
);

CREATE INDEX idx_cities_name ON cities(city_name);

-- Tariffs
CREATE TABLE tariffs (
    tariff_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tariff_name    VARCHAR2(150) NOT NULL,
    data_limit_mb  NUMBER(10,2)  NOT NULL,
    minutes_limit  NUMBER(8,2)   NOT NULL,
    sms_limit      NUMBER(8,2)   NOT NULL,
    monthly_fee    NUMBER(10,2)  NOT NULL,
    CONSTRAINT uq_tariff_name UNIQUE (tariff_name),
    CONSTRAINT chk_data_limit  CHECK (data_limit_mb  >= 0),
    CONSTRAINT chk_minutes     CHECK (minutes_limit  >= 0),
    CONSTRAINT chk_sms         CHECK (sms_limit      >= 0),
    CONSTRAINT chk_monthly_fee CHECK (monthly_fee    >= 0)
);

CREATE INDEX idx_tariffs_name ON tariffs(tariff_name);

-- Customers
CREATE TABLE customers (
    customer_id   NUMBER PRIMARY KEY,
    first_name    VARCHAR2(100) NOT NULL,
    last_name     VARCHAR2(100) NOT NULL,
    phone_number  VARCHAR2(20),
    email         VARCHAR2(200),
    city_id       NUMBER        NOT NULL,
    tariff_id     NUMBER        NOT NULL,
    signup_date   DATE          NOT NULL,
    CONSTRAINT fk_cust_city   FOREIGN KEY (city_id)   REFERENCES cities(city_id),
    CONSTRAINT fk_cust_tariff FOREIGN KEY (tariff_id) REFERENCES tariffs(tariff_id),
    CONSTRAINT uq_phone       UNIQUE (phone_number),
    CONSTRAINT uq_email       UNIQUE (email)
);

CREATE INDEX idx_cust_city   ON customers(city_id);
CREATE INDEX idx_cust_tariff ON customers(tariff_id);
CREATE INDEX idx_cust_signup ON customers(signup_date);

-- Monthly Usage
CREATE TABLE monthly_usage (
    usage_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id    NUMBER        NOT NULL,
    record_month   DATE          NOT NULL,
    used_data_mb   NUMBER(10,2)  DEFAULT 0 NOT NULL,
    used_minutes   NUMBER(8,2)   DEFAULT 0 NOT NULL,
    used_sms       NUMBER(8,2)   DEFAULT 0 NOT NULL,
    CONSTRAINT fk_usage_cust  FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT uq_usage_month UNIQUE (customer_id, record_month),
    CONSTRAINT chk_used_data  CHECK (used_data_mb  >= 0),
    CONSTRAINT chk_used_min   CHECK (used_minutes  >= 0),
    CONSTRAINT chk_used_sms   CHECK (used_sms      >= 0)
);

CREATE INDEX idx_usage_customer ON monthly_usage(customer_id);
CREATE INDEX idx_usage_month    ON monthly_usage(record_month);

-- Payments
CREATE TABLE payments (
    payment_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id   NUMBER        NOT NULL,
    tariff_id     NUMBER        NOT NULL,
    billing_month DATE          NOT NULL,
    amount        NUMBER(10,2)  NOT NULL,
    status        VARCHAR2(20)  DEFAULT 'UNPAID' NOT NULL,
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

COMMIT;