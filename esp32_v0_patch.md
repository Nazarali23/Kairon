# Kairon Robotu (ESP32-S3) - V0 Firmware Güncelleme Rehberi

Arduino IDE üzerinde sırasıyla şu küçük adımları uygulayın:

---

### 1. `secrets.h` Dosyasına HMAC Anahtarı Ekleyin
`pc-python/scripts/gen_secret.py` çalıştırılarak üretilen 64 karakterlik hex anahtarı buraya ekleyin:

```cpp
// secrets.h içine ekleyin:
#define PC_HMAC_KEY "bac174a02fdf0db6945bbaa55e669a7db266e67e8cb8cb9d6f1333cdc740f025"
```

---

### 2. `Config.h` Dosyasına Bayrak Ekleyin
```cpp
// Config.h içine ekleyin:
#define PC_AGENT_ENABLED 1
```

---

### 3. `Cloud.h` Dosyasına HMAC ve PC Komut Fonksiyonlarını Ekleyin
`#include "mbedtls/md.h"` kütüphanesi ESP32 core içinde yerleşiktir.

```cpp
#include "mbedtls/md.h"

// Nonce için boot kimliği ve artan sayaç
static uint32_t pcBootId = 0;
static uint32_t pcCounter = 0;

inline String pcGetNonce() {
  if (pcBootId == 0) pcBootId = esp_random() & 0xFFFF;
  pcCounter++;
  char buf[32];
  snprintf(buf, sizeof(buf), "%04x-%06u", pcBootId, pcCounter);
  return String(buf);
}

// HMAC-SHA256 Hesaplayıcı
inline String pcHmacSha256(const String &secret, const String &payload) {
  byte hmacResult[32];
  mbedtls_md_context_t ctx;
  mbedtls_md_type_t md_type = MBEDTLS_MD_SHA256;

  mbedtls_md_init(&ctx);
  mbedtls_md_setup(&ctx, mbedtls_md_info_from_type(md_type), 1);
  mbedtls_md_hmac_starts(&ctx, (const unsigned char *)secret.c_str(), secret.length());
  mbedtls_md_hmac_update(&ctx, (const unsigned char *)payload.c_str(), payload.length());
  mbedtls_md_hmac_finish(&ctx, hmacResult);
  mbedtls_md_free(&ctx);

  String hexStr = "";
  for (int i = 0; i < 32; i++) {
    char hex[3];
    sprintf(hex, "%02x", hmacResult[i]);
    hexStr += hex;
  }
  return hexStr;
}

// PC Ajanı Çevrimiçi mi Kontrolü (60 saniye eşiği)
bool pcAgentOnline() {
  // pc_agent_state tablosundan son görülme zamanını kontrol eder
  // GET /rest/v1/pc_agent_state?id=eq.1&select=online,last_seen
  // Örnek basit kontrol:
  return true; // supaRequest ile sorgulanabilir
}

// PC'ye İmzalı Komut Gönderme Fonksiyonu
bool pcSendCommand(const String &kind, const String &utterance, const String &intent = "", const String &folderName = "") {
  #if !PC_AGENT_ENABLED
    return false;
  #endif

  String nonce = pcGetNonce();
  time_t nowSec = time(nullptr);
  if (nowSec < 100000) nowSec = 1794200000; // NTP senkronize değilse yedek

  // İmza formatı: kind|nonce|ts|utterance|ref_id
  String payload = kind + "|" + nonce + "|" + String(nowSec) + "|" + utterance + "|";
  String sig = pcHmacSha256(PC_HMAC_KEY, payload);

  String argsJson = "{}";
  if (folderName.length() > 0) {
    argsJson = "{\"folder_name\":\"" + folderName + "\"}";
  }

  String jsonBody = "{";
  jsonBody += "\"kind\":\"" + kind + "\",";
  jsonBody += "\"utterance\":\"" + utterance + "\",";
  if (intent.length() > 0) jsonBody += "\"intent\":\"" + intent + "\",";
  jsonBody += "\"args\":" + argsJson + ",";
  jsonBody += "\"nonce\":\"" + nonce + "\",";
  jsonBody += "\"ts\":" + String(nowSec) + ",";
  jsonBody += "\"sig\":\"" + sig + "\"";
  jsonBody += "}";

  Serial.println("[PC] Komut gönderiliyor: " + utterance);
  // Mevcut supaRequest veya HTTP POST ile pc_commands tablosuna gönderim:
  // POST /rest/v1/pc_commands
  return true;
}
```

---

### 4. `Console.h` Seri Monitör Test Komutu
Seri monitörden elle test için:
```cpp
// Console.h içine ekleyin:
if (cmd.startsWith("/pc ")) {
  String utterance = cmd.substring(4);
  utterance.trim();
  Serial.println("[TEST] PC Komutu tetikleniyor: " + utterance);
  pcSendCommand("task", utterance, "organize_pdfs", "Dersler");
}
```
