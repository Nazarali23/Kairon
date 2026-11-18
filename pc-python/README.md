# KaironAgent (PC Ajanı)

ESP32-S3 tabanlı masaüstü robot asistanı **Kairon** için Windows bilgisayar tarafında çalışan otonom yürütme, görev otomasyonu ve görsel masaüstü arayüzü (GUI).

---

## 🎯 Amaç ve Genel Bakış
Kairon robotu kullanıcının sesli komutlarını (Groq Whisper STT + Groq LLM) dinler, niyeti çıkarır ve güvenli imzalı bir komut olarak Supabase kuyruğuna (`pc_commands`) yazar. Bilgisayarda çalışan **KaironAgent** bu komutları yakalar, doğrular, yerel güvenlik politikasından geçirir, gerekirse masaüstü onay penceresi açar ve işlemi Python standart kütüphaneleriyle atomik olarak yürütür. Sonuç veya durum bilgisi robotun seslendirmesi için `robot_state.pending_say` alanına iletilir.

---

## 🖥️ Görsel Masaüstü Uygulama Arayüzü (GUI)
KaironAgent artık arka planda gizli kalmak yerine masaüstünde modern bir koyu siber arayüz ile açılır:
1. **Canlı Bağlantı ve Kalp Atışı:** Supabase bağlantısını ve online durumunu yeşil/kırmızı ışıkla anlık gösterir.
2. **Cihaz Eşleştirme (QR & PIN Kartı):**
   - Bilgisayar henüz bir kullanıcıya bağlanmadıysa pencerede taranabilir **QR Kod** ve **6 Haneli PIN** gösterilir.
   - Telefonunuzdan QR taranıp onaylandığında pencere anında yeşil `[✓] Yetkilendirilmiş Hesaba Bağlı` durumuna geçer.
3. **Canlı Görev ve Olay Günlüğü:**
   - Robottan veya telefondan gelen görevler, dosya taşıma süreçleri ve kalp atışı hareketleri IDE terminali gibi anlık akar.
4. **Windows Sistem Tepsisi (System Tray):**
   - "Tepsiye Küçült" seçeneğiyle görev çubuğuna gizlenir, simgeye tıklandığında anında öne gelir.
5. **Test Komutu Gönder Butonu:**
   - Donanım olmadan da sistemin doğru çalıştığını denemek için tek tıkla test görevi tetikler.

---

## 🚀 Başlatma Yöntemleri

### Yöntem 1: Çift Tıklayarak Başlatma
`pc-python/start_agent.bat` dosyasına çift tıklayarak doğrudan masaüstü uygulamasını açabilirsiniz.

### Yöntem 2: PowerShell / Komut Satırından Başlatma
```powershell
cd pc-python
.\.venv\Scripts\python.exe run_agent.py
```

*(İsteğe bağlı olarak sadece konsol/servis çıktısı almak isterseniz `python run_agent.py --headless` parametresini kullanabilirsiniz.)*

---

## 🏛️ Mimari Akış

```text
[Kullanıcı (Ses / Mobil)] ──► [Kairon Robotu (ESP32-S3)]
                                     │
                                     │ 1. STT + Süzgeç + Niyet Çıkarımı
                                     │ 2. HMAC-SHA256 İmzalı Komut
                                     ▼
                        [Supabase: pc_commands] ◄──── Yoklama (2-8 sn) ────┐
                                     ▲                                     │
                                     │ Durum/Sonuç                         ▼
                                     └──────────────────────── [KaironAgent GUI (Python)]
                                                                  │ (Doğrula -> Planla -> Çalıştır)
                                                                  ▼
                                                     [robot_state.pending_say]
                                                                  │
                                                                  ▼
                                                      [Kairon Sonucu Seslendirir]
```

---

## 🛡️ Güvenlik İlkeleri (Tavizsiz Güvenlik)
1. **İmzalı Komut Doğrulaması:** Her komut `HMAC-SHA256` ile imzalanır. Replay saldırılarına karşı `nonce` (SQLite) ve 90 saniyelik zaman damgası (`ts`) kontrol edilir.
2. **Kısıtlı ve İzinli Dizinler (PathGuard):** Yalnızca `Masaüstü`, `İndirilenler` ve `Belgeler` kök dizinlerinde işlem yapılabilir. Sistem, AppData, Program Files, Windows dizinlerine erişim kesinlikle yasaktır.
3. **Silme İşlemi Yok:** Hiçbir dosya kalıcı silinmez. Geri alma günlüğü (SQLite Journal) tutulur, taşınan dosyalar eski konumlarına döndürülebilir.
4. **Çakışma Güvenliği:** Hedef klasörde aynı isimde dosya varsa üzerine yazılmaz; otomatik ` (2)` eki verilir.
5. **Dinamik Ekran Ölçeği:** Windows API üzerinden DPI ölçeğini (%100, %125, %150) otomatik tespit eder.
