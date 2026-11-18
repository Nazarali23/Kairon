# Kairon Robot (ESP32-S3 Donanım & Firmware)

Masaüstü robot asistanı **Kairon**'un ESP32-S3 mikrokontrolcüsü üzerinde çalışan gömülü yazılım (firmware) ve donanım yapılandırması.

---

## 🔒 Güvenlik ve Gizlilik Uyarısı
> **ÖNEMLİ:** Bu klasördeki bulut bağlantıları, yapay zeka istemleri, DSP ses sürücüleri ve özellikle `secrets.h` (WiFi, Groq, Gemini ve Supabase anahtarları) güvenlik ve fikri mülkiyet gereği `.gitignore` ile korunmaktadır ve **asla GitHub'a gönderilmez.**
>
> Açık kaynaklı repoda yalnızca donanım pin/konfigürasyon tanımları (`Config.h`), seri ve uzaktan konsol motoru (`Console.h`) ve ana döngü taslağı (`sketch_oct30a.ino`) yer alır.

---

## 🛠️ Donanım Mimarisi ve Pin Şeması

| Bileşen | Model / Tip | Bağlantı / Arayüz | Pinler (GPIO) |
| :--- | :--- | :--- | :--- |
| **MCU** | ESP32-S3 (8MB PSRAM) | USB-C Dev Module | - |
| **Ekran** | 2.8" SPI TFT (240x320) | ST7789 (SPI 20 MHz) | DC: 9, CS: 10, MOSI: 11, CLK: 12, RST: 13 |
| **Mikrofon** | INMP441 | I2S (16 kHz, Mono) | SCK: 4, WS: 5, SD: 6 |
| **Hoparlör** | MAX98357A + 3W Hoparlör | I2S (24 kHz, Mono) | BCLK: 15, LRC: 16, DOUT: 7 |
| **Pan Servo** | MG90S (Yatay Kafa) | PWM (Smooth-Damp 10ms) | GPIO 18 (0° Sağ, 100° Merkez, 180° Sol) |
| **Tilt Servo** | MG90S (Dikey Kafa) | PWM (Smooth-Damp 10ms) | GPIO 17 (60° Aşağı, 90° Merkez, 160° Yukarı) |
| **PIR Sensör** | HC-SR501 (Varlık Algılama) | Dijital Giriş | GPIO 2 |
| **Sol Sonar** | HC-SR04 (Mesafe / Takip) | Ultrasonik | Trig: 42, Echo: 41 |
| **Sağ Sonar** | HC-SR04 (Mesafe / Takip) | Ultrasonik | Trig: 40, Echo: 39 |

---

## ⚙️ Arduino IDE Derleme Ayarları
- **Board:** `ESP32S3 Dev Module`
- **CPU Frequency:** 240MHz (WiFi)
- **Flash Mode:** QIO 80MHz
- **Flash Size:** 8MB / 16MB
- **PSRAM:** `OPI PSRAM` (Etkinleştirilmiş olmalıdır)
- **Upload Speed:** 921600
- **USB CDC On Boot:** Enabled
- **Port:** COM5 (veya atanan port)

---

## 💻 Merkezi Konsol Komutları (`Console.h`)
Komutlar hem USB Seri Monitör üzerinden (115200 Baud) hem de Kairon Mobile uygulamasındaki **Kairon IDE Test Konsolu** üzerinden veritabanını şişirmeden geçici bellekte çalıştırılabilir:

- `/sonar` : Ultrasonik sensör mesafe ölçüm değerlerini ve kullanıcı algılama durumunu döker.
- `/sonar test` : Sensör self-test prosedürünü çalıştırır.
- `/brain` : LLM karar motoru, bellek durumu ve konuşma geçmişini gösterir.
- `/mem` : Bulut ve yerel RAM hafızasında kayıtlı anıları listeler.
- `/days` : Kayıtlı özel günleri ve periyodik hatırlatıcıları döker.
- `/time` : Robotun donanım sistem saatini verir.
- `/kafa <evet|hayir|uyu|sol|sag>` : Servoları doğrudan önceden tanımlanmış jest pozisyonuna hareket ettirir.
- `/say <metin>` : TTS motoru üzerinden robota yerel konuşma yaptırır (Hoparlör testi).
- `/style <komik|ciddi|zeki|soguk|sevimli|otomatik>` : Karakter ve konuşma tarzını ayarlar.
- `/vol <0.0 - 1.0>` : Hoparlör çıkış ses seviyesini ayarlar.
- `/qr` / `/pair` : ST7789 ekranında eşleştirme QR matrisini ve 6 haneli PIN kodunu açar / kapatır.
- `/owner` : Cihaza bağlı sahip kullanıcının UUID kimliğini doğrular.
- `/restart` : ESP32 mikrokontrolcüsünü yazılımsal olarak yeniden başlatır.
