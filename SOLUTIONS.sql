-- Oracle XE uyumlu çözüm sorguları
-- Her çözüm altında en az 3 cümle Türkçe açıklama ve örnek çıktı formatı vardır.

-------------------------------------------------------------------------------
-- 1.1 'Kobiye Destek' tarifesine abone müşterileri listele
-------------------------------------------------------------------------------
SELECT
    c.customer_id,
    c.name,
    c.city,
    c.signup_date,
    t.name AS tariff_name
FROM customers c
JOIN tariffs t
    ON t.tariff_id = c.tariff_id
WHERE t.name = 'Kobiye Destek'
ORDER BY c.signup_date DESC, c.customer_id;

-- Bu sorgu, müşteriler ile tarifeler tablosunu birleştirerek yalnızca istenen tarife adını filtreler.
-- Burada doğrudan tarifenin metin adı üzerinden gidildiği için, id değişse bile sorgu mantığı bozulmaz.
-- Sonuçları kayıt tarihine göre sıralayarak en güncel müşteri hareketlerini üstte görebilirsin.
-- Örnek çıktı formatı: CUSTOMER_ID | NAME | CITY | SIGNUP_DATE | TARIFF_NAME
-- Örnek sonuç satırları:
-- 8295 | ... | ... | 05/04/2026 | Kobiye Destek
-- 8164 | ... | ... | 05/04/2026 | Kobiye Destek
-- 7156 | ... | ... | 05/04/2026 | Kobiye Destek

-------------------------------------------------------------------------------
-- 1.2 Bu tarifenin en yeni müşterisini bul
-------------------------------------------------------------------------------
SELECT
    c.customer_id,
    c.name,
    c.city,
    c.signup_date
FROM customers c
JOIN tariffs t
    ON t.tariff_id = c.tariff_id
WHERE t.name = 'Kobiye Destek'
ORDER BY c.signup_date DESC, c.customer_id DESC
FETCH FIRST 1 ROW ONLY;

-- Oracle'da LIMIT yerine FETCH FIRST kullanıldığı için syntax tamamen Oracle XE uyumludur.
-- Aynı tarihte birden fazla müşteri varsa deterministik sonuç için ikinci sıralama olarak customer_id DESC eklendi.
-- Böylece her çalıştırmada tek ve tutarlı bir "en yeni müşteri" kaydı elde edilir.
-- Örnek çıktı formatı: CUSTOMER_ID | NAME | CITY | SIGNUP_DATE
-- Örnek sonuç satırı:
-- 8295 | ... | ... | 05/04/2026

-------------------------------------------------------------------------------
-- 2.1 Tarifelerin müşteri dağılımını bul
-------------------------------------------------------------------------------
SELECT
    t.tariff_id,
    t.name AS tariff_name,
    COUNT(c.customer_id) AS customer_count
FROM tariffs t
LEFT JOIN customers c
    ON c.tariff_id = t.tariff_id
GROUP BY t.tariff_id, t.name
ORDER BY customer_count DESC, t.tariff_id;

-- LEFT JOIN kullanımı, hiç müşterisi olmayan tarifelerin de raporda görünmesini sağlar.
-- Dağılım bilgisi kampanya etkisini ve tarife popülaritesini ölçmek için temel bir metriktir.
-- Çıktının büyükten küçüğe sıralanması en yoğun tarifeleri hızlıca görmeyi kolaylaştırır.
-- Örnek çıktı formatı: TARIFF_ID | TARIFF_NAME | CUSTOMER_COUNT
-- Örnek sonuç satırları:
-- 2 | Kurumsal SMS | 2577
-- 1 | Genç Dinamik | 2527
-- 4 | Kobiye Destek | 2483
-- 3 | Çalışan GB | 2413

-------------------------------------------------------------------------------
-- 3.1 En erken kayıt olan müşterileri bul
-------------------------------------------------------------------------------
SELECT
    c.customer_id,
    c.name,
    c.city,
    c.signup_date
FROM customers c
WHERE c.signup_date = (
    SELECT MIN(c2.signup_date)
    FROM customers c2
)
ORDER BY c.customer_id;

-- Bu sorgu özellikle "en düşük ID en erken kayıt demek değildir" kuralına uygun olacak şekilde yazıldı.
-- Önce minimum signup_date bulunur, sonra bu tarihe sahip tüm müşteriler döndürülür.
-- Böylece tek kişiye değil, aynı gün kayıt olan tüm en erken müşterilere doğru sonuç alınır.
-- Örnek çıktı formatı: CUSTOMER_ID | NAME | CITY | SIGNUP_DATE
-- Örnek sonuç satırları:
-- 233 | ... | ... | 07/04/2025
-- 414 | ... | ... | 07/04/2025
-- 587 | ... | ... | 07/04/2025

-------------------------------------------------------------------------------
-- 3.2 Bu müşterilerin şehirlere göre dağılımını bul
-------------------------------------------------------------------------------
SELECT
    c.city,
    COUNT(*) AS customer_count
FROM customers c
WHERE c.signup_date = (
    SELECT MIN(c2.signup_date)
    FROM customers c2
)
GROUP BY c.city
ORDER BY customer_count DESC, c.city;

-- Burada 3.1'deki en erken kayıtlı müşteri kümesi alınır ve şehir bazında gruplanır.
-- Aynı gün çok farklı şehirlerden kayıt varsa dağılım çıktısı bunu net şekilde gösterir.
-- Pazarlama veya bölgesel kampanya analizlerinde başlangıç penetrasyonunu anlamak için değerlidir.
-- Örnek çıktı formatı: CITY | CUSTOMER_COUNT
-- Örnek sonuç satırları:
-- ANTALYA   | 2
-- GAZİANTEP | 2
-- SAKARYA   | 2

-------------------------------------------------------------------------------
-- 4.1 Aylık kaydı eksik olan müşterilerin ID'lerini bul
-------------------------------------------------------------------------------
SELECT
    c.customer_id
FROM customers c
LEFT JOIN monthly_usage mu
    ON mu.customer_id = c.customer_id
WHERE mu.customer_id IS NULL
ORDER BY c.customer_id;

-- LEFT JOIN + IS NULL paterni, child tabloda karşılığı olmayan parent kayıtlarını bulmanın standart yoludur.
-- Bu sorgu veri kalite kontrolü için kritik olup, eksik yüklenmiş kullanım satırlarını yakalar.
-- Özellikle ETL sonrası kontrol listesinde ilk çalıştırılacak doğrulama sorgularından biridir.
-- Örnek çıktı formatı: CUSTOMER_ID
-- Örnek sonuç satırları:
-- 6
-- 10
-- 31
-- 39
-- 45

-------------------------------------------------------------------------------
-- 4.2 Eksik kayıtlı müşterilerin şehirlere göre dağılımı
-------------------------------------------------------------------------------
SELECT
    c.city,
    COUNT(*) AS missing_count
FROM customers c
LEFT JOIN monthly_usage mu
    ON mu.customer_id = c.customer_id
WHERE mu.customer_id IS NULL
GROUP BY c.city
ORDER BY missing_count DESC, c.city;

-- Bu rapor, eksik aylık kullanım kayıtlarının hangi şehirlerde yoğunlaştığını çıkarır.
-- Tek tek müşteri listesi yerine toplu dağılım sunarak operasyonel önceliklendirme sağlar.
-- Örneğin belirli şehirlerde sürekli eksik kayıt görünmesi, kaynak sistem ya da entegrasyon sorunu işareti olabilir.
-- Örnek çıktı formatı: CITY | MISSING_COUNT
-- Örnek sonuç satırları:
-- OSMANİYE  | 3
-- BİTLİS    | 2
-- DENİZLİ   | 2

-------------------------------------------------------------------------------
-- 5.1 Data limitinin %75'ini kullanan müşterileri bul
-------------------------------------------------------------------------------
SELECT
    c.customer_id,
    c.name,
    t.name AS tariff_name,
    mu.data_usage_mb,
    t.data_limit_mb,
    ROUND((mu.data_usage_mb / NULLIF(t.data_limit_mb, 0)) * 100, 2) AS data_usage_pct
FROM customers c
JOIN tariffs t
    ON t.tariff_id = c.tariff_id
JOIN monthly_usage mu
    ON mu.customer_id = c.customer_id
WHERE t.data_limit_mb > 0
  AND mu.data_usage_mb >= (t.data_limit_mb * 0.75)
ORDER BY data_usage_pct DESC, c.customer_id;

-- NULLIF ile sıfıra bölme riski ortadan kaldırılır ve sorgu güvenli hale gelir.
-- data_limit_mb = 0 olan tarifeler doğal olarak dışarıda bırakılarak yanlış pozitifler engellenir.
-- Sonuçta limitine yaklaşan müşteriler tespit edilir ve proaktif paket önerisi yapılabilir.
-- Örnek çıktı formatı: CUSTOMER_ID | NAME | TARIFF_NAME | DATA_USAGE_MB | DATA_LIMIT_MB | DATA_USAGE_PCT
-- Örnek sonuç satırları:
-- 311  | ... | Çalışan GB    | 20476.18 | 20480 | 99.98
-- 5623 | ... | Kobiye Destek | 20476.27 | 20480 | 99.98
-- 666  | ... | Genç Dinamik  | 10234.05 | 10240 | 99.94

-------------------------------------------------------------------------------
-- 5.2 Tüm paket limitlerini (data + dakika + SMS) tamamen tüketenler
-------------------------------------------------------------------------------
SELECT
    c.customer_id,
    c.name,
    t.name AS tariff_name,
    mu.data_usage_mb,
    mu.minute_usage,
    mu.sms_usage
FROM customers c
JOIN tariffs t
    ON t.tariff_id = c.tariff_id
JOIN monthly_usage mu
    ON mu.customer_id = c.customer_id
WHERE mu.data_usage_mb >= t.data_limit_mb
  AND mu.minute_usage >= t.minute_limit
  AND mu.sms_usage >= t.sms_limit
ORDER BY c.customer_id;

-- Bu sorgu üç farklı kaynağı tek koşul kümesinde birleştirerek "tam tüketim" müşterisini yakalar.
-- Eşit veya üzerinde kullanım kabul edildiği için limit aşımı yapan müşteriler de dahil edilir.
-- Ürün ekipleri bu listeyi üst paket önerisi veya ek paket kampanyası için kullanabilir.
-- Örnek çıktı formatı: CUSTOMER_ID | NAME | TARIFF_NAME | DATA_USAGE_MB | MINUTE_USAGE | SMS_USAGE
-- Örnek sonuç:
-- Bu veri setinde tüm limitleri aynı anda tüketen müşteri bulunmamıştır (0 satır).

-------------------------------------------------------------------------------
-- 6.1 Ödenmemiş ücreti olan müşterileri bul
-------------------------------------------------------------------------------
SELECT
    c.customer_id,
    c.name,
    c.city,
    p.amount_due,
    p.payment_status
FROM payments p
JOIN customers c
    ON c.customer_id = p.customer_id
WHERE p.payment_status IN ('UNPAID', 'LATE')
ORDER BY p.amount_due DESC, c.customer_id;

-- Ödeme riski açısından hem UNPAID hem LATE durumları birlikte ele alınır.
-- Tutara göre azalan sıralama, tahsilat ekibinin yüksek bakiyeli müşterileri önce görmesini sağlar.
-- Şehir bilgisini dahil etmek, bölgesel tahsilat raporlarıyla entegrasyonu kolaylaştırır.
-- Örnek çıktı formatı: CUSTOMER_ID | NAME | CITY | AMOUNT_DUE | PAYMENT_STATUS
-- Örnek sonuç satırları:
-- 19 | ... | ... | 1000 | UNPAID
-- 22 | ... | ... | 1000 | UNPAID
-- 77 | ... | ... | 1000 | LATE

-------------------------------------------------------------------------------
-- 6.2 Tüm tarifelerde ödeme durumlarının dağılımı
-------------------------------------------------------------------------------
SELECT
    t.name AS tariff_name,
    p.payment_status,
    COUNT(*) AS customer_count
FROM payments p
JOIN customers c
    ON c.customer_id = p.customer_id
JOIN tariffs t
    ON t.tariff_id = c.tariff_id
GROUP BY t.name, p.payment_status
ORDER BY t.name, p.payment_status;

-- Bu sorgu, ödeme davranışını tarife kırılımında göstererek riskli ürün segmentlerini görünür yapar.
-- GROUP BY iki boyutlu kurulduğu için her tarife için PAID/LATE/UNPAID dağılımı ayrı satırlarda gelir.
-- Finans ve ürün ekipleri bu çıktıyı birlikte okuyarak fiyatlama veya hatırlatma stratejisini güncelleyebilir.
-- Örnek çıktı formatı: TARIFF_NAME | PAYMENT_STATUS | CUSTOMER_COUNT
-- Örnek sonuç satırları:
-- Genç Dinamik  | PAID   | 1792
-- Genç Dinamik  | LATE   | 372
-- Genç Dinamik  | UNPAID | 352
-- Kurumsal SMS  | PAID   | 1796
-- Kobiye Destek | UNPAID | 360
