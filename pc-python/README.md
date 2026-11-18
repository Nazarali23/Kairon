# KaironAgent (PC Ajanı)

ESP32-S3 tabanlı masaüstü robot asistanı **Kairon** için Windows bilgisayar tarafında çalışan otonom yürütme ve otomasyon ajanı.

---

## 🎯 Amaç ve Genel Bakış
Kairon robotu kullanıcının sesli komutlarını (Groq Whisper STT + Groq LLM) dinler, niyeti çıkarır ve güvenli imzalı bir komut olarak Supabase kuyruğuna (`pc_commands`) yazar. Bilgisayarda çalışan **KaironAgent** bu komutları yakalar, doğrular, yerel güvenlik politikasından geçirir, gerekirse masaüstü onay penceresi açar ve işlemi Python standart kütüphaneleriyle atomik olarak yürütür. Sonuç veya durum bilgisi robotun seslendirmesi için `robot_state.pending_say` alanına iletilir.

---

## 🏛️ Mimari Akış

```text
[Kullanıcı (Ses)] ──► [Kairon Robotu (ESP32-S3)]
                            │
                            │ 1. STT + Süzgeç + Anahtar Kelime Kapısı
                            │ 2. LLM [[PC: ...]] etiketi
                            │ 3. HMAC-SHA256 İmzalı Komut
                            ▼
               [Supabase: pc_commands] ◄──── Yoklama (2-8 sn) ────┐
                            ▲                                     │
                            │ Durum/Sonuç                         ▼
                            └──────────────────────── [KaironAgent (Python)]
                                                         │ (Doğrula -> Planla -> Onayla -> Çalıştır)
                                                         ▼
                                            [robot_state.pending_say]
                                                         │
                                                         ▼
                                             [Kairon Sonucu Seslendirir]
```

---

## 🛡️ Güvenlik İlkeleri (Bölüm 13 - Tavizsiz)
1. **İmzalı Komut Doğrulaması:** Her komut `HMAC-SHA256` ile imzalanır. Robot ve PC arasında paylaşılan 32-baytlık gizli anahtar kullanılır. Replay saldırılarına karşı `nonce` (SQLite) ve 90 saniyelik zaman damgası (`ts`) kontrol edilir.
2. **Kısıtlı ve İzinli Dizinler (PathGuard):** Yalnızca `Masaüstü`, `İndirilenler` ve `Belgeler` kök dizinlerinde işlem yapılabilir. Sistem, AppData, Program Files, Windows dizinlerine erişim kesinlikle yasaktır. Symlink, Junction (reparse point), UNC ve `..` manipülasyonları engellenir.
3. **Silme İşlemi Yok (V1):** Hiçbir dosya kalıcı silinmez. Geri alma günlüğü (SQLite Journal) tutulur, taşınan dosyalar eski konumlarına döndürülebilir.
4. **Çakışma Güvenliği:** Hedef klasörde aynı isimde dosya varsa üzerine yazılmaz; otomatik ` (2)` eki verilir.
5. **Görsel İmleç Ayrımı (V3):** Fare imleci hareketi sadece görsel eşliktir (koreografi). Dosya taşıma işi asla imleç sürüklemesine emanet edilmez; Python `pathlib`/`shutil` ile güvenli şekilde yapılır. Kullanıcı fareye dokunduğu anda imleç hareketi iptal edilir.
6. **Güvenli Sır Saklama:** Supabase `service_role` anahtarı ve HMAC sırrı dosyalarda saklanmaz, Windows Kimlik Bilgisi Yöneticisi (**Keyring**) üzerinde tutulur.

---

## 📦 Teknoloji Yığını
- **Python:** 3.12 (64-bit), Windows 10/11
- **Ağ ve Doğrulama:** `httpx` (AsyncClient), `pydantic v2`, `tenacity`
- **Güvenlik ve Depolama:** `keyring`, `sqlite3` (stdlib), `tomllib` / `tomli-w`
- **LLM Entegrasyonu:** Groq SDK (OpenAI uyumlu), Gemini API (yedek)
- **Windows Entegrasyonu:** `pywin32`, `ctypes`, `uiautomation`, `pynput`
- **Arayüz:** `pystray` + `Pillow` (Sistem tepsisi), `tkinter` (Onay ve ayar pencereleri)

---

## 📂 Dizin Yapısı Planı
```text
pc-python/
├── pyproject.toml
├── README.md
├── .gitignore
├── config.example.toml
├── src/kaironagent/
│   ├── __main__.py
│   ├── app.py
│   ├── config.py
│   ├── logging_setup.py
│   ├── cloud/
│   │   ├── supabase.py          # REST: fetch, claim, patch, heartbeat, say
│   │   └── models.py            # Pydantic: Command, Plan, Step, Result
│   ├── security/
│   │   ├── signing.py           # HMAC-SHA256, nonce, replay guard
│   │   ├── policy.py            # İzinli kökler, dosya limitleri, uzantı kuralları
│   │   └── pathguard.py         # Path traversal, symlink, reparse point denetimi
│   ├── planner/
│   │   ├── router.py            # V1: Kural tabanlı Türkçe kalıp yönlendirici
│   │   ├── llm_planner.py       # V2: Groq araç çağrılı otonom planlayıcı
│   │   └── naming.py            # Akıllı klasör adı türetme ve sanitization
│   ├── tools/
│   │   ├── registry.py          # Araç kayıt defteri
│   │   ├── files.py             # list, create_folder, move
│   │   ├── pdfmeta.py           # PDF başlık ve özet okuma (pypdf)
│   │   ├── docx_summary.py      # Mobil gelen kutusu için dosya özetleme
│   │   └── speak.py             # robot_state.pending_say köprüsü
│   ├── executor/
│   │   ├── runner.py            # Durum makinesi ve görev yürütücü
│   │   ├── journal.py           # SQLite geri alma günlüğü
│   │   └── confirm.py           # Masaüstü Tkinter onay penceresi
│   ├── cursor/
│   │   ├── uia_desktop.py       # UI Automation masaüstü ikon koordinatları
│   │   ├── choreography.py      # Kübik Bézier imleç animasyonu
│   │   └── interrupt.py         # Kullanıcı müdahale algılayıcı
│   └── ui/
│       ├── tray.py              # Sistem tepsisi simgesi ve kontrolleri
│       └── dialogs.py           # Onay ve bildirim diyalogları
├── tests/
└── scripts/
    ├── gen_secret.py            # HMAC anahtarı üretici
    └── sql/pc_tables.sql        # Supabase DDL tabloları
```

---

## 🚀 Yol Haritası (Aşamalar)
- **V0 (İskelet & Bağlantı):** Supabase tabloları, `gen_secret.py`, config, keyring, heartbeat döngüsü ve ESP32 `/pc` seri test komutu.
- **V1 (Kural Tabanlı PDF Düzenleme):** Kural yönlendirici, PathGuard, dosya taşıma, masaüstü onay penceresi, geri alma (undo) ve `pending_say` ile robota geri bildirim.
- **V2 (LLM Planlayıcı & Dosya Özetleme):** Araç çağrılı LLM (Groq), dinamik klasör adlandırma, İndirilenler klasörünü düzenleme, mobil için `summarize_and_send` desteği.
- **V3 (İmleç Koreografisi):** UIA ikon tespiti, Bézier eğrisiyle yumuşak imleç hareketi, kullanıcı müdahalesi ile anında kesme.
- **V4 (İleri Düzey Ajan):** Sesli onay, güvenli uygulama başlatma, medya kontrolleri.
