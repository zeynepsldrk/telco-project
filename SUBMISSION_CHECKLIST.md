# Submission Checklist

Bu dosya, teslim öncesi tüm gereksinimlerin tek ekrandan kontrol edilmesi için hazırlanmıştır.

## A) Zorunlu Dosyalar

- [x] `TABLE_CREATION_SCRIPTS.sql` mevcut
- [x] `SOLUTIONS.sql` mevcut
- [x] Oracle XE uyumlu veri tipleri ve syntax kullanıldı

## B) Şema ve Modelleme

- [x] Tablolar oluşturuldu (`tariffs`, `customers`, `monthly_usage`, `payments`)
- [x] PK, FK, NOT NULL, UNIQUE, CHECK constraint'leri eklendi
- [x] Performans için index'ler eklendi
- [x] CSV import için `monthly_stats_stage` staging tablosu eklendi

## C) Fonksiyonel SQL Soruları

- [x] 1.1 tamamlandı
- [x] 1.2 tamamlandı
- [x] 2.1 tamamlandı
- [x] 3.1 tamamlandı
- [x] 3.2 tamamlandı
- [x] 4.1 tamamlandı
- [x] 4.2 tamamlandı
- [x] 5.1 tamamlandı
- [x] 5.2 tamamlandı
- [x] 6.1 tamamlandı
- [x] 6.2 tamamlandı

## D) Değerlendirme Kuralları

- [x] Her sorgu için en az 3 cümle açıklama var
- [x] Her sorgu için örnek çıktı formatı var
- [x] Her sorgu için sample output satırları eklendi
- [x] Oracle'a uygun satır kısıtlama yaklaşımı kullanıldı (`FETCH FIRST`)

## E) Operasyonel Gereksinimler

- [x] `docker-compose.yml` mevcut (Oracle XE 21c)
- [x] Volume ile veri kalıcılığı var
- [x] Init script ile otomatik tablo oluşturma var
- [x] CSV import sonrası dönüşüm scripti var (`DATA_LOAD_TRANSFORM.sql`)
- [x] Reproducible setup adımları `README.md` içinde belgelendi

## F) Manuel Olarak Doğrulanacaklar

- [ ] Docker container local makinede başarılı şekilde ayağa kaldırıldı (`docker compose up -d`)
- [ ] DBeaver ile Oracle XE bağlantısı kuruldu ve test edildi
- [ ] CSV import sırasıyla yüklendi (`tariffs`, `customers`, `monthly_stats_stage`)
- [ ] `DATA_LOAD_TRANSFORM.sql` çalıştırıldı
- [ ] Sorgular DBeaver/SQL*Plus üzerinde çalıştırılıp doğrulandı
- [ ] Son hali kendi GitHub repository'ne push edildi
- [ ] README'ye ekran görüntüleri eklendi (opsiyonel ama güçlü öneri)

## G) Hızlı Teslim Komutları

```bash
docker compose up -d
```

```sql
@TABLE_CREATION_SCRIPTS.sql
@DATA_LOAD_TRANSFORM.sql
@SOLUTIONS.sql
```
