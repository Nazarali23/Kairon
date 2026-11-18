# 🤖 Kairon: Yapay Zeka Destekli Otonom IoT Masa Robotu ve Siber-Fiziksel Ekosistem

[![ESP32-S3](https://img.shields.io/badge/Hardware-ESP32--S3%208MB%20PSRAM-orange?logo=espressif)](sketch_oct30a/)
[![Python](https://img.shields.io/badge/PC%20Agent-Python%203.12-blue?logo=python)](pc-python/)
[![Flutter](https://img.shields.io/badge/Mobile%20%26%20Web-Flutter%203.x-02569B?logo=flutter)](mobil-flutter/)
[![Supabase](https://img.shields.io/badge/Cloud-Supabase%20%2B%20PostgreSQL-3ECF8E?logo=supabase)](supabase_init.sql)
[![Groq](https://img.shields.io/badge/LLM%20%26%20STT-Groq%20Qwen%20%2B%20Whisper-F55036)](https://groq.com)

**Kairon**, standart bir masaüstü asistanından öte fiziksel ortamı sensörleriyle izleyen, bulut tabanlı vektör hafızasıyla öğrenen, mobil ve web arayüzünden gerçek zamanlı telemetri sunan ve sesli komutlarla kullanıcının bilgisayarında otonom işlemler gerçekleştirebilen uçtan uca bir **IoT ve Siber-Fiziksel Sistem (Cyber-Physical System)** projesidir.

---

## 🏛️ Ekosistem Mimarisi ve Veri Akışı

```text
                     ┌─────────────────────────────────────────┐
                     │          Kullanıcı (Ses / Fiziksel)      │
                     └────────────────────┬────────────────────┘
                                          │ Ses Komutları (Mikrofon) / Hareket
                                          ▼
                     ┌─────────────────────────────────────────┐
                     │          Kairon Robotu (ESP32-S3)       │
                     │  - INMP441 I2S Mic -> Groq Whisper STT  │
                     │  - Groq LLM (Karakter + Niyet Çıkarımı) │
                     │  - ST7789 TFT Akışkan Göz Animasyonu    │
                     │  - Çift HC-SR04 Sonar + PIR Sensör      │
                     │  - Pan/Tilt MG90S Kafa Takip Servoları  │
                     └───────┬─────────────────────────▲───────┘
                             │                         │
     1. HMAC İmzalı Komut    │                         │ 4. robot_state.pending_say
        ve Sensör Logları    │                         │    (Sonuç Seslendirme)
                             ▼                         │
┌─────────────────────────────────────────────────────────────────────────────┐
│                       BULUT OMURGASI (Supabase)                             │
│                                                                             │
│  - pc_commands: İmzalı görev kuyruğu (HMAC, Nonce, Zaman Damgası)           │
│  - pc_agent_state: PC ajanı çevrimiçi / canlılık durumu (Heartbeat)          │
│  - robot_state: Modlar, göz rengi, ses seviyesi, pending_say (id=1)        │
│  - sensor_logs: Postür mesafesi (cm), PIR hareket alarmları, uyku analizleri │
│  - app_inbox: PC ajanından telefona gönderilen belge özetleri              │
└──────────────▲───────────────────────────────────────────────┬──────────────┘
               │                                               │
               │ Yoklama / Sahiplenme / Güncelleme             │ Realtime Akış
               ▼                                               ▼
┌──────────────────────────────┐               ┌──────────────────────────────┐
│  KaironAgent (Windows / Py)  │               │   KaironMobile (Flutter)     │
│                              │               │                              │
│ - HMAC-SHA256 Doğrulayıcı    │               │ - 6 Akıllı Çalışma Modu      │
│ - PathGuard & İzinli Dizinler│               │ - fl_chart IoT Telemetrisi   │
│ - Otonom Dosya Düzenleme     │               │ - Pomodoro & Postür Uyarısı  │
│ - Masaüstü Onay Penceresi    │               │ - Anlık Bekçi Güvenlik Alarmı│
│ - SQLite Geri Alma (Journal) │               │ - Belge Özetleri Okuma       │
│ - Görsel İmleç Koreografisi  │               │ - Web & Android Desteği      │
└──────────────────────────────┘               └──────────────────────────────┘
```

---

## 📦 Proje Bileşenleri

### 1. 🤖 Robot Firmware (`sketch_oct30a`)
ESP32-S3 tabanlı ana kontrol birimi. Donanım seviyesinde FreeRTOS görevleri (`faceTask`, `servoTask`, `cloudTask`, `sonarTask`) çalıştırır.
- **Ekran:** 2.8" SPI TFT (240x320) ST7789, parametrik göz ifadeleri ve duygu animasyonları.
- **Ses:** INMP441 I2S mikrofon + MAX98357A I2S amfi + Google Translate TTS robotik efekt motoru.
- **Sensör Füzyonu:** PIR (GPIO 2) ile varlık algılama; sol (Trig 42, Echo 41) ve sağ (Trig 40, Echo 39) ultrasonik sensörlerle kafa takip ve postür mesafesi ölçümü.
- **Güvenlik Koruması:** `secrets.h`, bulut algoritmaları ve ses kütüphaneleri repodan dışlanmış olup yalnızca açık donanım tanımları (`Config.h`, `Console.h`, `sketch_oct30a.ino`) repoda paylaşılır.
- 👉 Ayrıntılar için: [sketch_oct30a/README.md](sketch_oct30a/README.md)

### 2. 💻 KaironAgent (`pc-python`)
Windows bilgisayarında arka planda çalışan ve robottan gelen imzalı komutları güvenle icra eden masaüstü otomasyon ajanı.
- **Python 3.12 + Asyncio:** `httpx` üzerinden Supabase komut kuyruğunu dinler.
- **Tavizsiz Güvenlik (Bölüm 13):** HMAC-SHA256 imzası, replay koruması (SQLite nonce), dosya silme yasağı, izinli kök dizinler (Masaüstü, İndirilenler, Belgeler) ve PathGuard denetimi.
- **Dinamik Ekran Ölçeği Algılama:** Windows API üzerinden DPI ölçeğini (%100, %125, %150) otomatik tespit eder.
- **Akıllı Planlama:** Groq Qwen modeli ile görev ayrıştırma, otomatik klasör adlandırma ve SQLite tabanlı geri alma (undo) günlüğü.
- 👉 Ayrıntılar için: [pc-python/README.md](pc-python/README.md)

### 3. 📱 KaironMobile (`mobil-flutter`)
Robotu internet üzerinden izlemeyi, modlarını değiştirmeyi ve sensör verilerini grafiklerle analiz etmeyi sağlayan Material 3 Siber Koyu temalı mobil/web uygulaması.
- **6 Akıllı Mod:** Standart Asistan, Derin Odak (Pomodoro & 35cm Postür Uyarısı), Bekçi (Alan Güvenliği & Hareket Alarmı), Uyku (Gece Hareket Analizi), Sağlık & Refakatçi, Siber Ofis.
- **IoT Telemetrisi (`fl_chart`):** Canlı postür mesafesi grafiği, saatlik doluluk ve hareketlilik dağılımı.
- **Siber Ofis Özet Kutusu:** PC ajanının Word ve PDF dosyalarından çıkardığı özetleri listeleme ve robota seslendirme.
- 👉 Ayrıntılar için: [mobil-flutter/README.md](mobil-flutter/README.md)

### 4. ☁️ Supabase Veritabanı (`supabase_init.sql`)
PostgreSQL veritabanı üzerinde çalışan merkezi iletişim omurgası.
- RLS (Row Level Security) ile korunan `pc_commands`, `pc_agent_state`, `sensor_logs` ve `app_inbox` tabloları.
- Supabase Realtime abonelikleri ile cihazlar arası milisaniyelik senkronizasyon.

---

## 🚀 Hızlı Başlangıç

### Adım 1: Veritabanını Kurun
1. Supabase projenizde **SQL Editor** sekmesini açın.
2. [supabase_init.sql](supabase_init.sql) dosyasının içeriğini yapıştırın ve **Run** butonuna basın.

### Adım 2: PC Ajanını Başlatın
```bash
cd pc-python

# 1. HMAC anahtarını üretin
.\.venv\Scripts\python scripts/gen_secret.py

# 2. Anahtarları Windows Keyring'e güvenle kaydedin
.\.venv\Scripts\python scripts/set_keys.py

# 3. Ajanı başlatın
.\.venv\Scripts\python -m kaironagent
```

### Adım 3: Mobil / Web Uygulamasını Başlatın
```bash
cd mobil-flutter

# Web üzerinde test etmek için:
flutter run -d chrome

# Android telefonda test etmek için:
flutter run
```
*(Supabase URL ve Anon Key bilginizi [mobil-flutter/lib/core/config.dart](mobil-flutter/lib/core/config.dart) dosyasına ekleyin.)*

### Adım 4: ESP32 Robot Güncellemesi
[esp32_v0_patch.md](esp32_v0_patch.md) dosyasındaki küçük kod parçalarını Arduino IDE projenize (`secrets.h`, `Config.h`, `Cloud.h`, `Console.h`) ekleyip karta yükleyin.

---

## 🛡️ Güvenlik İlkeleri
1. **İmzasız İşlem Yapılmaz:** Robot dışından veya sahte anahtarla gelen komutlar anında reddedilir.
2. **Kritik Kod Gizliliği:** Özel algoritmalar ve API anahtarları `.gitignore` koruması altındadır, açık repoya dahil edilmez.
3. **Masaüstü Güvenliği:** PC ajanı sistem dizinlerine (Windows, AppData vb.) asla dokunamaz; silme yapmaz; taşınan her dosya `undo` ile eski konumuna döndürülebilir.
4. **Kullanıcı Önceliği:** Fareye dokunulduğu veya acil durdurma kısayolu (`Ctrl+Alt+Esc`) basıldığı anda ajan durur.

---

## 📄 Lisans
Bu proje Nazarali tarafından geliştirilmektedir. Tüm hakları saklıdır.
