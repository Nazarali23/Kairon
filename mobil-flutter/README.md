# KaironMobile (Robot Durum, Modlar ve IoT Telemetri)

ESP32-S3 tabanlı masaüstü robot asistanı **Kairon** için uzaktan kontrol, IoT sensör analizi ve PC ajanı entegrasyonu sağlayan modern Flutter mobil/web uygulaması.

---

## 🎯 Amaç ve Genel Bakış
Kairon robotunu yerel ağ sınırlaması olmadan, internet/mobil veri üzerinden anlık olarak izlemek, 6 farklı akıllı çalışma moduna geçirmek, ultrasonik ve PIR sensörlerinden gelen telemetri verilerini grafiklerle (Mikroişlemciler dersi IoT isterlerine uygun biçimde) analiz etmek ve PC Ajanından gönderilen belge özetlerini okumak için geliştirilmektedir.

---

## 🏛️ Mimari Akış

```text
[Kairon ESP32-S3] ──(PIR, Mesafe, Olaylar)──► [Supabase: sensor_logs]
       ▲                                                    │
       │ (robot_state: active_mode, ayarlar, pending_say)   ▼ (Realtime / REST)
[Supabase: robot_state] ◄──────(Mod Seçimi, Kumanda)──── [KaironMobile (Flutter)]
                                                            ▲
[KaironAgent (PC)] ──────(Belge Özetleri, PC Durumu)───────► [Supabase: app_inbox]
```

---

## 🤖 6 Akıllı Mod (`active_mode`)
1. **Standart Asistan (`normal`):** Genel sohbet, soru-cevap ve hafıza. Sensörler 5 dakikada bir periyodik log atar.
2. **Derin Odak & Ergonomi (`focus`):**
   - Uygulamada Pomodoro zamanlayıcı (25 dk çalışma / 5 dk mola).
   - Ultrasonik mesafe takibi: 30 saniye boyunca mesafe < 35 cm ise (kamburlaşma/ekrana yaklaşma) robot sesli uyarır ve `posture_warn` logu oluşturur.
3. **Bekçi / Alan Güvenliği (`guard`):**
   - PIR hareket algılarsa veya mesafe ani düşerse robot başını o yöne çevirir, caydırıcı sesli ikaz verir ve `intrusion` alarmı kaydeder.
   - Uygulama Realtime üzerinden anlık kırmızı alarm uyarısı gösterir.
4. **Gece ve Uyku Analizi (`sleep`):**
   - Robot ekranı saat moduna veya düşük parlaklığa geçer, sesler susturulur.
   - Gece boyu PIR tetiklenmeleri sessizce sayılır ve `sleep_move` olarak loglanır. Sabah hareketlilik grafiği çizilir.
5. **Sağlık & Refakatçi (`care`):**
   - İlaç ve su saatlerini sesli hatırlatır (`followups`).
   - Belirli süre PIR hareketi algılanmazsa `inactivity` uyarısı oluşturur.
6. **Siber Ofis (`office`):**
   - Bilgisayarın (KaironAgent) çevrimiçi ve meşgul durumunu gösterir.
   - PC ajanının özetlediği dosyalar `app_inbox` üzerinden okunabilir ve robota seslendirilebilir.

---

## 📊 IoT Telemetri ve Grafikler (`fl_chart`)
- **Postür ve Ekran Mesafesi Grafiği (LineChart):** Zamana bağlı mesafe (cm) ve 35 cm eşik çizgisi.
- **Aktivite ve Doluluk Dağılımı (BarChart):** Saatlik masa başı çalışma ve gece hareketlilik yoğunluğu.
- **Olay Günlüğü:** Postür uyarıları, hareket alarmları ve Pomodoro tamamlanma geçmişi.
- **Demo / Simülasyon Verisi:** Laboratuvar veya ders sunumunda grafiklerin zengin görünmesi için tek tıkla 24 saatlik gerçekçi geçmiş veri yükleme özelliği.

---

## 📦 Teknoloji Yığını
- **Flutter:** 3.x / Dart 3
- **Tasarım:** Material 3, Siber Koyu Tema (Cyberpunk / Modern Dark UI)
- **Durum Yönetimi:** `StatefulWidget` & `Provider`
- **Veritabanı & Gerçek Zamanlı Akış:** `supabase_flutter` (REST + Realtime Stream)
- **Grafik Motoru:** `fl_chart`
- **Tarih & Biçimlendirme:** `intl`

---

## 📂 Dizin Yapısı Planı
```text
mobil-flutter/
├── pubspec.yaml
├── README.md
├── .env.example
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── config.dart              # Supabase URL & Anon Key
│   │   ├── theme.dart               # Koyu tema ve mod renk paletleri
│   │   └── constants.dart           # Mod sabitleri, ikonlar, açıklamalar
│   ├── models/
│   │   ├── robot_state_model.dart   # robot_state satır modeli
│   │   ├── sensor_log_model.dart    # sensor_logs telemetri modeli
│   │   ├── inbox_item_model.dart    # app_inbox özet ve bildirim modeli
│   │   └── memory_model.dart        # memories & followups modeli
│   ├── services/
│   │   └── supabase_service.dart    # Supabase CRUD ve Realtime akışları
│   └── features/
│       ├── dashboard/               # Ana panel, çevrimiçi rozeti, hızlı konuştur
│       ├── modes/                   # 6 mod seçimi ve Pomodoro kontrolleri
│       ├── telemetry/               # fl_chart grafikleri ve olay listesi
│       ├── office_inbox/            # PC ajanından gelen belge özetleri
│       └── settings/                # Ses, TTS hızı, göz rengi ve yüz stili
```

---

## 🚀 Yol Haritası (Aşamalar)
- **V0 (İskelet & Bağlantı):** Supabase tabloları (`sensor_logs`, `app_inbox`), Flutter iskeleti, tema ve `robot_state` anlık okuma.
- **V1 (Kumanda & Akıllı Modlar):** Dashboard (çevrimiçi rozeti, `pending_say` metin gönderme) ve 6 mod geçiş arayüzü.
- **V2 (IoT Telemetri & Grafikler):** `fl_chart` ile canlı postür mesafesi, saatlik hareketlilik grafiği ve test telemetri veri üreticisi.
- **V3 (Siber Ofis & Gelen Kutusu):** PC ajanı özet kutusu (`app_inbox`), detay okuma, robota seslendirme ve bekçi modu alarmları.
