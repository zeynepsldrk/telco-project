-- Oracle XE 21c uyumlu tablo, constraint ve index scriptleri
-- CSV import sırasında tipi korumak için staging tabloları da tanımlanır.

-- Güvenli yeniden çalıştırma için önce child, sonra parent tabloları sil.
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE payments CASCADE CONSTRAINTS';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE monthly_stats_stage CASCADE CONSTRAINTS';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE monthly_usage CASCADE CONSTRAINTS';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE customers CASCADE CONSTRAINTS';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE tariffs CASCADE CONSTRAINTS';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

CREATE TABLE tariffs (
    tariff_id      NUMBER(10)      CONSTRAINT pk_tariffs PRIMARY KEY,
    name           VARCHAR2(100)   CONSTRAINT nn_tariffs_name NOT NULL,
    monthly_fee    NUMBER(10,2)    CONSTRAINT nn_tariffs_fee NOT NULL,
    data_limit_mb  NUMBER(10,2)    CONSTRAINT nn_tariffs_data_limit NOT NULL,
    minute_limit   NUMBER(10)      CONSTRAINT nn_tariffs_minute_limit NOT NULL,
    sms_limit      NUMBER(10)      CONSTRAINT nn_tariffs_sms_limit NOT NULL,
    CONSTRAINT uq_tariffs_name UNIQUE (name),
    CONSTRAINT ck_tariffs_monthly_fee_nonneg CHECK (monthly_fee >= 0),
    CONSTRAINT ck_tariffs_data_limit_nonneg CHECK (data_limit_mb >= 0),
    CONSTRAINT ck_tariffs_minute_limit_nonneg CHECK (minute_limit >= 0),
    CONSTRAINT ck_tariffs_sms_limit_nonneg CHECK (sms_limit >= 0)
);

CREATE TABLE customers (
    customer_id    NUMBER(10)      CONSTRAINT pk_customers PRIMARY KEY,
    name           VARCHAR2(100)   CONSTRAINT nn_customers_name NOT NULL,
    city           VARCHAR2(50)    CONSTRAINT nn_customers_city NOT NULL,
    signup_date    DATE            CONSTRAINT nn_customers_signup_date NOT NULL,
    tariff_id      NUMBER(10)      CONSTRAINT nn_customers_tariff_id NOT NULL,
    CONSTRAINT fk_customers_tariff
        FOREIGN KEY (tariff_id) REFERENCES tariffs (tariff_id)
);

CREATE TABLE monthly_usage (
    usage_id       NUMBER(10)      CONSTRAINT pk_monthly_usage PRIMARY KEY,
    customer_id    NUMBER(10)      CONSTRAINT nn_monthly_usage_customer_id NOT NULL,
    data_usage_mb  NUMBER(10,2)    CONSTRAINT nn_monthly_usage_data NOT NULL,
    minute_usage   NUMBER(10)      CONSTRAINT nn_monthly_usage_minute NOT NULL,
    sms_usage      NUMBER(10)      CONSTRAINT nn_monthly_usage_sms NOT NULL,
    CONSTRAINT uq_monthly_usage_customer UNIQUE (customer_id),
    CONSTRAINT fk_monthly_usage_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
    CONSTRAINT ck_monthly_usage_data_nonneg CHECK (data_usage_mb >= 0),
    CONSTRAINT ck_monthly_usage_minute_nonneg CHECK (minute_usage >= 0),
    CONSTRAINT ck_monthly_usage_sms_nonneg CHECK (sms_usage >= 0)
);

-- MONTHLY_STATS.csv dosyasını doğrudan almak için staging tablo.
-- Bu tablo ham import içindir, uygulama sorgularında kullanılmaz.
CREATE TABLE monthly_stats_stage (
    id             NUMBER(10)     CONSTRAINT pk_monthly_stats_stage PRIMARY KEY,
    customer_id    NUMBER(10)     CONSTRAINT nn_stage_customer_id NOT NULL,
    data_usage     NUMBER(10,2)   CONSTRAINT nn_stage_data_usage NOT NULL,
    minute_usage   NUMBER(10)     CONSTRAINT nn_stage_minute_usage NOT NULL,
    sms_usage      NUMBER(10)     CONSTRAINT nn_stage_sms_usage NOT NULL,
    payment_status VARCHAR2(10)   CONSTRAINT nn_stage_payment_status NOT NULL,
    CONSTRAINT fk_stage_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
    CONSTRAINT ck_stage_payment_status CHECK (payment_status IN ('PAID', 'LATE', 'UNPAID')),
    CONSTRAINT ck_stage_data_nonneg CHECK (data_usage >= 0),
    CONSTRAINT ck_stage_minute_nonneg CHECK (minute_usage >= 0),
    CONSTRAINT ck_stage_sms_nonneg CHECK (sms_usage >= 0)
);

CREATE TABLE payments (
    payment_id      NUMBER(10)     CONSTRAINT pk_payments PRIMARY KEY,
    customer_id     NUMBER(10)     CONSTRAINT nn_payments_customer_id NOT NULL,
    amount_due      NUMBER(10,2)   CONSTRAINT nn_payments_amount_due NOT NULL,
    payment_status  VARCHAR2(10)   CONSTRAINT nn_payments_status NOT NULL,
    payment_date    DATE,
    CONSTRAINT fk_payments_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
    CONSTRAINT ck_payments_amount_nonneg CHECK (amount_due >= 0),
    CONSTRAINT ck_payments_status CHECK (payment_status IN ('PAID', 'LATE', 'UNPAID'))
);

-- Sorgu performansı için indexler
CREATE INDEX ix_customers_tariff_id ON customers (tariff_id);
CREATE INDEX ix_customers_signup_date ON customers (signup_date);
CREATE INDEX ix_customers_city ON customers (city);

CREATE INDEX ix_monthly_usage_customer_id ON monthly_usage (customer_id);
CREATE INDEX ix_monthly_stats_stage_customer_id ON monthly_stats_stage (customer_id);

CREATE INDEX ix_payments_customer_id ON payments (customer_id);
CREATE INDEX ix_payments_status ON payments (payment_status);
CREATE INDEX ix_payments_customer_status ON payments (customer_id, payment_status);

-- Not:
-- monthly_stats_stage -> monthly_usage/payments aktarımı
-- DATA_LOAD_TRANSFORM.sql dosyasında yapılır.
