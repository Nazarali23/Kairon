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
                     │  - Groq LLM (6 Karakter + Niyet Analizi)│
                     │  - ST7789 TFT Gözler & Dahili QR Ekranı │
                     │  - Çift HC-SR04 Sonar + PIR Sensör      │
                     │  - Pan/Tilt MG90S Kafa Takip Servoları  │
                     │  - Geçici Donanım Test Konsolu          │
                     └───────┬─────────────────────────▲───────┘
                             │                         │
     1. HMAC İmzalı Komut    │                         │ 4. robot_state.pending_say
        ve Sensör Logları    │                         │    veya console_output
                             ▼                         │
┌─────────────────────────────────────────────────────────────────────────────┐
│                       BULUT OMURGASI (Supabase)                             │
│                                                                             │
│  - pairing_sessions: Güvenli QR & 6 Haneli PIN ile Cihaz Sahiplenme         │
│  - pc_commands: İmzalı görev kuyruğu (HMAC, Nonce, Zaman Damgası)           │
│  - pc_agent_state: PC ajanı çevrimiçi / canlılık durumu (Heartbeat)          │
│  - robot_state: Çoklu modlar, kişilik, geçici console_cmd/output (id=1)     │
│  - followups: Saatli, tekrarlı ve tek seferlik kullanıcı hatırlatıcıları    │
│  - sensor_logs: Postür mesafesi (cm), PIR hareket alarmları, uyku analizleri │
│  - app_inbox: PC ajanından telefona gönderilen belge özetleri              │
└──────────────▲───────────────────────────────────────────────┬──────────────┘
               │                                               │
               │ Yoklama / Sahiplenme / Güncelleme             │ Realtime Akış
               ▼                                               ▼
┌──────────────────────────────┐               ┌──────────────────────────────┐
│  KaironAgent (Windows / Py)  │               │   KaironMobile (Flutter)     │
│                              │               │                              │
│ - HMAC-SHA256 Doğrulayıcı    │               │ - Çoklu Eşzamanlı Mod Seçimi │
│ - PathGuard & İzinli Dizinler│               │ - 6 Farklı Robot Kişilik Modu│
│ - Otonom Dosya Düzenleme     │               │ - Kamera ile QR Tarama / PIN │
│ - Masaüstü Onay Penceresi    │               │ - Kairon IDE Test Konsolu    │
│ - SQLite Geri Alma (Journal) │               │ - Saatli Hatırlatıcı Yönetimi│
│ - QR & PIN Eşleşme Arayüzü   │               │ - Web & Android Desteği      │
└──────────────────────────────┘               └──────────────────────────────┘
```

---

## 🚀 Öne Çıkan Yeni Özellikler (V2)

1. **🔐 Çok Kullanıcılı Cihaz İzolasyonu & QR/PIN Eşleştirme:**
   - Robot (TFT ekranı) ve PC Ajanı açılışta geçici 6 haneli PIN ve QR kod üretir.
   - Kullanıcı mobil uygulamadan kamerayla QR tarayarak ya da PIN girerek cihazı kendi hesabına bağlar (`claimDevice`).
   - Veritabanındaki tüm anılar, hatırlatıcılar ve komutlar sadece eşleşen kullanıcıya izoledir.
2. **🔄 Eşzamanlı Çoklu Mod Aktivasyonu:**
   - Kullanıcı dilediği modları aynı anda etkinleştirebilir (örn: *Siber Ofis* + *Derin Odak*, veya *Asistan* + *Bekçi*).
3. **🎭 6 Farklı Robot Karakteri & Konuşma Üslubu:**
   - `Memory.h` motorundaki 6 kişilik mobilden anında seçilebilir:
     - **Şakacı (Komik):** Mizah dolu, eğlenceli yanıtlar.
     - **Ciddi:** Resmi, net ve kısa üslup.
     - **Zeki & Bilimsel:** Analitik ve detaylı açıklamalar.
     - **Soğuk:** Az ve öz konuşan minimalist tarz.
     - **Sevimli & Duygusal:** Sıcakkanlı, empatik yaklaşım.
     - **Otomatik (Dinamik):** Ortam koşullarına ve zamana göre uyarlanan dinamik karakter.
4. **💻 Kairon IDE Test Konsolu (Geçici Bellek Oturumu):**
   - Donanım komutları (`/sonar`, `/brain`, `/kafa`, `/time`, `/say`, `/restart`) mobilden doğrudan çalıştırılabilir.
   - Çıktılar IDE terminali gibi anlık izlenir; veritabanında satır birikmez (`robot_state.console_cmd` ve `console_output` üzerinde geçici oturum).
5. **⏰ Saatli & Tekrarlı Hatırlatıcılar (`followups`):**
   - Belirli saat ve tarihte (örn: 12:30'da evden çıkmamı söyle) robota hatırlatma ekleme.
   - Tek seferlik, günlük veya haftalık tekrar seçenekleri.
   - Tamamlanan hatırlatıcıları işaretleme ve silme.
6. **🔊 Ses & Ekran Kontrolleri:**
   - Hoparlör ses seviyesi slider'ı (%0 - %100).
   - ST7789 ekran durumu ve parlaklık ayarları.

---

## 📦 Proje Bileşenleri

### 1. 🤖 Robot Firmware (`sketch_oct30a`)
ESP32-S3 tabanlı ana kontrol birimi. Donanım seviyesinde FreeRTOS görevleri (`faceTask`, `servoTask`, `cloudTask`, `sonarTask`) çalıştırır.
- **Ekran:** 2.8" SPI TFT (240x320) ST7789, parametrik göz ifadeleri, duygu animasyonları ve dahili QR ekranı.
- **Ses:** INMP441 I2S mikrofon + MAX98357A I2S amfi + Google Translate TTS robotik efekt motoru.
- **Sensör Füzyonu:** PIR (GPIO 2) ile varlık algılama; çift ultrasonik sensörle kafa takip ve postür mesafesi ölçümü.
- **Güvenlik Koruması:** `secrets.h`, bulut algoritmaları ve ses kütüphaneleri repodan dışlanmış olup yalnızca açık donanım tanımları (`Config.h`, `Console.h`, `sketch_oct30a.ino`) repoda paylaşılır.
- 👉 Ayrıntılar için: [sketch_oct30a/README.md](sketch_oct30a/README.md)

### 2. 💻 KaironAgent (`pc-python`)
Windows bilgisayarında arka planda çalışan ve robottan gelen imzalı komutları güvenle icra eden masaüstü otomasyon ajanı.
- **Python 3.12 + Asyncio:** `httpx` üzerinden Supabase komut kuyruğunu dinler.
- **Tavizsiz Güvenlik:** HMAC-SHA256 imzası, replay koruması (SQLite nonce), dosya silme yasağı, izinli kök dizinler (Masaüstü, İndirilenler, Belgeler) ve PathGuard denetimi.
- **Dinamik Ekran Ölçeği Algılama:** Windows API üzerinden DPI ölçeğini (%100, %125, %150) otomatik tespit eder.
- **Akıllı Planlama:** Groq Qwen modeli ile görev ayrıştırma, otomatik klasör adlandırma ve SQLite tabanlı geri alma (undo) günlüğü.
- 👉 Ayrıntılar için: [pc-python/README.md](pc-python/README.md)

### 3. 📱 KaironMobile (`mobil-flutter`)
Robotu internet üzerinden izlemeyi, modlarını değiştirmeyi ve sensör verilerini grafiklerle analiz etmeyi sağlayan Material 3 Siber Koyu temalı mobil/web uygulaması.
- **Kamera ile QR Tarama & PIN:** Cihazı saniyeler içinde hesaba bağlama.
- **Çoklu Akıllı Modlar:** Eşzamanlı çalıştırılabilen 6 mod.
- **Kairon IDE Konsolu:** Donanım testlerini doğrudan cep telefonundan yapma.
- **IoT Telemetrisi (`fl_chart`):** Canlı postür mesafesi grafiği, saatlik doluluk ve hareketlilik dağılımı.
- **Hatırlatıcılar & Alarmlar:** Tam saatinde seslendirilen bildirimler.

---

## 🛠️ Kurulum Adımları

### 1. Veritabanı (Supabase)
Supabase projenizin SQL editöründe aşağıdaki sırayla scriptleri çalıştırın:
1. `supabase_init.sql` (Temel tablolar ve yapılar)
2. `supabase_multiuser_isolation.sql` (Çok kullanıcılı izolasyon ve cihaz eşleşmesi)
3. `supabase_v2_features.sql` (Konsol, çoklu mod ve hatırlatıcı sütunları)

### 2. PC Ajanı (`pc-python`)
```powershell
cd pc-python
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python app.py
```

### 3. Mobil Uygulama (`mobil-flutter`)
```powershell
cd mobil-flutter
flutter pub get
flutter run -d chrome  # veya android cihazınız
```
