# 🤖 Kairon — Yapay Zeka Destekli Otonom IoT Masa Asistanı ve Siber-Fiziksel Ekosistem

**Kairon**, standart bir sesli asistandan farklı olarak fiziksel ortamı sensörleriyle algılayan, bulut tabanlı vektör hafızasıyla öğrenen, mobil uygulama üzerinden gerçek zamanlı telemetri sunan ve sesli komutlarla bilgisayarınızda otonom işlemler yapabilen uçtan uca bir **IoT ve Siber-Fiziksel Sistem** projesidir.

### 🌟 Temel Bileşenler
* **🧠 Kairon Firmware (ESP32-S3):** Parametrik TFT yüz animasyonu, 2 eksenli servo kafa takibi, çift HC-SR04 ultrasonik + PIR sensör füzyonu, Groq STT/LLM ve vektör hafıza (Gemini Embedding).
* **📱 KaironMobile (Flutter):** Gerçek zamanlı IoT sensör grafikleri (postür mesafesi, oda hareketliliği, uyku analizi), 6 farklı Akıllı Mod yönetimi (Odak/Pomodoro, Bekçi, Uyku, Refakatçi, Siber Ofis) ve uzaktan kontrol paneli.
* **💻 KaironAgent (Windows Python Ajanı):** Robottan gelen HMAC-SHA256 imzalı sesli komutları doğrulayarak dosya düzenleme, belge özetleyip telefona gönderme ve geri alınabilir (journaled) masaüstü otomasyonu yapan güvenli arka plan servisi.
* **☁️ Bulut Omurgası (Supabase):** PostgreSQL + pgvector tabanlı uzun süreli hafıza, `sensor_logs` telemetri akışı ve cihazlar arası gerçek zamanlı durum senkronizasyonu.
