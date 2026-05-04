-- Oracle XE veri yükleme sonrası dönüşüm scripti
-- Bu script, CSV'ler DBeaver/SQL*Loader ile import edildikten sonra çalıştırılmalıdır.

-- Beklenen import hedefleri:
-- 1) TARIFFS.csv       -> tariffs (tariff_id, name, monthly_fee, data_limit_mb, minute_limit, sms_limit)
-- 2) CUSTOMERS.csv     -> customers (customer_id, name, city, signup_date, tariff_id)
--    - signup_date alanını DBeaver tarafında DATE map'lerken DD/MM/YYYY seç.
-- 3) MONTHLY_STATS.csv -> monthly_stats_stage (id, customer_id, data_usage, minute_usage, sms_usage, payment_status)

-- 1) Ham monthly stats verisini uygulama tablosuna taşı
-- Aynı customer_id için birden fazla stage kaydı varsa veri bütünlüğünü korumak için işlemi durdur.
DECLARE
    v_duplicate_customer_count NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO v_duplicate_customer_count
      FROM (
          SELECT s.customer_id
            FROM monthly_stats_stage s
           GROUP BY s.customer_id
          HAVING COUNT(*) > 1
      );

    IF v_duplicate_customer_count > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'monthly_stats_stage tablosunda duplicate customer_id kaydi var. '
            || 'Duzeltmeden DATA_LOAD_TRANSFORM.sql calistirilamaz.'
        );
    END IF;
END;
/

MERGE INTO monthly_usage mu
USING (
    SELECT
        s.id AS usage_id,
        s.customer_id,
        s.data_usage AS data_usage_mb,
        s.minute_usage,
        s.sms_usage
    FROM monthly_stats_stage s
) src
ON (mu.customer_id = src.customer_id)
WHEN MATCHED THEN
    UPDATE SET
        mu.usage_id      = src.usage_id,
        mu.data_usage_mb = src.data_usage_mb,
        mu.minute_usage  = src.minute_usage,
        mu.sms_usage     = src.sms_usage
WHEN NOT MATCHED THEN
    INSERT (usage_id, customer_id, data_usage_mb, minute_usage, sms_usage)
    VALUES (src.usage_id, src.customer_id, src.data_usage_mb, src.minute_usage, src.sms_usage);

-- 2) payment verisini tarifeden türetip payments tablosuna yükle
MERGE INTO payments p
USING (
    SELECT
        s.id AS payment_id,
        s.customer_id,
        t.monthly_fee AS amount_due,
        s.payment_status
    FROM monthly_stats_stage s
    JOIN customers c
        ON c.customer_id = s.customer_id
    JOIN tariffs t
        ON t.tariff_id = c.tariff_id
) src
ON (p.payment_id = src.payment_id)
WHEN MATCHED THEN
    UPDATE SET
        p.customer_id = src.customer_id,
        p.amount_due = src.amount_due,
        p.payment_status = src.payment_status
WHEN NOT MATCHED THEN
    INSERT (payment_id, customer_id, amount_due, payment_status, payment_date)
    VALUES (src.payment_id, src.customer_id, src.amount_due, src.payment_status, NULL);

COMMIT;
