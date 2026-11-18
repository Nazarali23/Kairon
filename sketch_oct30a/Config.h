#pragma once
// Ayarlar, pinler, paylasilan global durum ve ileri bildirimler
#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <SPI.h>
#include <LittleFS.h>
#include <time.h>
#include <ESP_I2S.h>
#include <Adafruit_GFX.h>
#include <Adafruit_ST7789.h>
#include "esp_sleep.h"
#include "esp_heap_caps.h"
#include "driver/gpio.h"
#include "secrets.h"          // WIFI_SSID, WIFI_PASS, GROQ_KEY, GEMINI_KEY, SUPABASE_URL, SUPABASE_KEY
#include <WebServer.h>

#ifndef GEMINI_KEY
#define GEMINI_KEY ""         // bos ise vektor (embedding) ozelligi kapali, kelime aramasi calisir
#endif
#ifndef SUPABASE_URL
#define SUPABASE_URL ""
#endif
#ifndef SUPABASE_KEY
#define SUPABASE_KEY ""
#endif

// ---- Modul anahtarlari ----
#define USE_TFT 1
#define USE_MIC 1
#define USE_PIR 1
#define USE_SERVOS 1
#define USE_SONAR 1            // 2x HC-SR04 (sol 42/41, sag 40/39). Seri monitorden /sonar on|off ile de acilip kapatilir
#define ENABLE_SLEEP 1          // 1: Uzun sure (12 dk) ses/hareket yoksa tamamen derin uykuya gec ve PIR ile uyan. Saat ekrani ise 45 sn bosta kalinca acilir.
#define PLAYBACK_TEST 0        // 1: kaydi sadece geri cal (yapay zekayi atla)
#define DEBUG_LEVEL 0
#define TFT_INVERT false       // ekran renkleri ters ise (siyah/beyaz yer degistirmis) true<->false degistir
#define TFT_MIRROR_X 1         // 1: ST7789 yatay ayna duzeltmesi (yazilar ayna gibi ters ise 1 yap)
#define WIFI_TX_POWER WIFI_POWER_19_5dBm   // varsayilan (en guclu). Dusurmek sinyali zayiflatip zaman asimlarina yol acabilir

// ---- Yapay zeka ----
#define STT_MODEL "whisper-large-v3-turbo"
String llmModel = "qwen/qwen3.8-27b";

// Groq ucretsiz katmanda bu modelin dakikalik cikis token siniri ~1000. max_tokens bunun altinda tutulur.
#define LLM_MAXTOK_CHAT   300
#define LLM_MAXTOK_SPONT  300
#define LLM_MAXTOK_CONSOL 500

const char* SYSTEM_PROMPT_BASE =
  "Sen masa üstünde duran fiziksel bir masa robotusun. "
  "Türkçe konuş. Emoji, markdown, madde işareti ve özel karakter kullanma. "
  "Kullanıcının adını biliyorsan yerinde ve doğal şekilde kullan.";

// ---- Pinler ----
#define TFT_DC 9
#define TFT_CS 10
#define TFT_MOSI 11
#define TFT_CLK 12
#define TFT_RST 13
#define I2S_DOUT 7
#define I2S_BCLK 15
#define I2S_LRC 16
#define MIC_SCK 4
#define MIC_WS 5
#define MIC_SD 6
#define PIR_PIN 2

// ---- Servo Motor Pinleri ve Kalibrasyon ----
#define SERVO_PAN_PIN   18     // Sag-Sol (Yatay) MG90S Servo -> Pin 18 (0: Tam Sag, 100: Merkez, 180: Tam Sol)
#define SERVO_TILT_PIN  17     // Yukari-Asagi (Dikey) MG90S Servo -> Pin 17 (60: Tam Asagi, 90: Merkez, 160: Tam Yukari)

#define PAN_CENTER      100.0f
#define PAN_MIN         0.0f
#define PAN_MAX         180.0f

#define TILT_CENTER     90.0f
#define TILT_MIN        60.0f  // Tam Asagi alt sinir
#define TILT_MAX        160.0f // Tam Yukari ust sinir
#define TILT_MECH_OFFSET -10.0f // Mekanik kalibrasyon ofseti
#define TILT_DIR_MULT   1.0f   // Yon ters ise -1.0f yapilabilir

// Hicbir hareket bu hizi (derece/sn) gecemez: kablolari ve disli dislerini korur.
// Ani tepkiler (saskinlik gibi) bu sinira kadar cikabilir, normal hareketler cok altinda kalir.
#define SERVO_ABS_MAX_SPEED 190.0f

// ---- 2x HC-SR04 Ultrasonik Sensor Pinleri ----
#define SONAR_L_TRIG    42     // sol sensor Trig
#define SONAR_L_ECHO    41     // sol sensor Echo  (5V cikis! bolucu kullan, bkz. Sonar.h)
#define SONAR_R_TRIG    40     // sag sensor Trig
#define SONAR_R_ECHO    39     // sag sensor Echo  (5V cikis! bolucu kullan)

// ---- IoT ve Mod Degiskenleri ----
bool powerOn = true;
int activeMode = 0;        // 0: Normal, 1: Calisma, 2: Uyku, 3: Disarida
String activeModesStr = "normal"; // Coklu mod: "normal,office", "office,focus", vb.
inline bool isModeActive(const char* m) {
  if (!m || !m[0]) return false;
  return activeModesStr.indexOf(m) >= 0;
}
int faceStyle = 0;
String robotOwnerId = "";        // Supabase owner_id (Kullanici UUID)
String robotPairingPin = "";     // 6 haneli QR / Eslestirme PIN'i
TaskHandle_t cloudTask = nullptr;
TaskHandle_t faceHandle = nullptr;
TaskHandle_t servoHandle = nullptr;
char appSayBuf[320];                   // Flutter'dan gelen "bunu soyle" (core0 yazar, core1 okur)
volatile bool appSayReady = false;

// Ileri bildirim (Forward declaration)
String runConsoleCommand(String s);
String cloudSendPcCommand(const String& utterance);

// ---- Mikrofon ayarlari ----
const unsigned long SLEEP_AFTER_MS = 5UL * 60UL * 1000UL;
const int SR = 16000;
const int CHUNK = 256;
const int MAX_SEC = 8;
const int MAX_SAMPLES = SR * MAX_SEC;
const int PRE = 10;
const int SILENCE_CHUNKS = 32;       // azaltildi: 40 cok uzundu (28 chunk = ~448ms sessizlik yeterli)
const float THRESH_MULT = 3.8f;
const float THRESH_ADD = 90.0f;
const int MIN_VOICED_CHUNKS = 16;    // arttirildi: 12 cok dusuktu, gurultu bile kaydediliyordu (20 chunk = ~320ms gercek ses)

// ---- Ses cikisi / robot sesi ----
const int OUT_RATE = 24000;
const size_t TTS_MAX = (size_t)OUT_RATE * 14;
const size_t MP3_MAX = 200 * 1024;
float ttsSpeed = 1.35f;
float ttsPitch = 0.92f;
float robotMix = 0.45f;
float robotFreq = 90.0f;
float volume = 0.6f;

const uint16_t C_BLACK = 0x0000, C_CYAN = 0x07FF, C_GREEN = 0x07E0, C_YELLOW = 0xFFE0, C_WHITE = 0xFFFF;

I2SClass spk;
WiFiClientSecure secure;        // Google TTS
WiFiClientSecure secureGroq;    // Groq
WiFiClientSecure secureGem;     // Gemini embedding

enum State { IDLE, LISTENING, THINKING, SPEAKING };
volatile State state = IDLE;

unsigned long tMouth = 0, lastActivity = 0, tSpeakStart = 0, tPipeStart = 0;

int32_t raw[CHUNK];
int16_t pcm[CHUNK];
int16_t pre[PRE][CHUNK];
int preIdx = 0, preCount = 0, voicedChunks = 0;
int16_t* recBuf = nullptr;
size_t recLen = 0;
int silentChunks = 0, loudCount = 0, flushChunks = 0;
float noiseFloor = 50, threshold = 400;
float hpIn = 0, hpOut = 0;

uint8_t* mp3Buf = nullptr;
int16_t *pcmA = nullptr, *pcmB = nullptr, *outBuf = nullptr;
size_t outLen = 0, outPos = 0;
bool playing = false;
volatile int32_t mouthLevel = 0;

unsigned long stateSinceMs = 0;      // durum ne zaman degisti (takilma bekcisi icin)
int micFailCount = 0;
unsigned long lastPresenceMs = 0;    // PIR / sonar / konusma ile guncellenir (yuz motoru da okur)

// ---- Dikkat / uyku ayarlari ----
#define CONV_TRACK_MS         90000UL   // konusmadan sonra kullaniciya bakmaya devam etme suresi
#define ATTENTION_MS          8000UL    // kullanici hareket edince robotun ona donuk kalma suresi (bosta iken)
#define IDLE_SLEEP_AFTER_MS   45000UL   // bosta 45 sn cevap verilmezse uyku gozlerine gec (saat oncesi)
#define CLOCK_AFTER_SLEEP_MS  5000UL    // uyku gozlerinden 5 sn sonra saat ekrani acilsin
#define DEEP_SLEEP_AFTER_MS   (12UL * 60UL * 1000UL) // 12 dakika boyunca ses ve PIR hareketi yoksa tamamen derin uykuya gecip kapan

// ---- Moduller arasi paylasilan zaman damgalari ----
volatile unsigned long lastSoundMs = 0;       // mikrofon son ne zaman ses duydu (uykudan uyandirir)
volatile unsigned long lastConvMs = 0;        // son konusma/ses etkinligi (arka plan ag trafigini bekletir)
volatile unsigned long attentionUntilMs = 0;  // sonar harekete tepki penceresi
unsigned long sonarConvUntilMs = 0;           // bu zamana kadar sonar aktif; gecince kapat (0=zaten kapali)
extern unsigned long lastTurnMs;              // Memory.h'ta tanimli

// ---- Ileriye donuk bildirimler ----
String llmSend(JsonDocument& req);
void setLlmParams(JsonDocument& req, int maxTokens, float temp);
bool embedText(const char* text, bool isQuery, int8_t* out);
bool embedBatch(const int* idxs, int n);
int splitStr(const String& s, char sep, String* parts, int maxN);
void foldTo(const char* s, char* out, size_t cap);
bool cloudEnabled();
void cloudUpsertRec(int idx);
void cloudDeleteRec(uint32_t id);
void cloudSyncDays();
void cloudSyncFollowups();
void cloudDeleteDay(int id);
void cloudDeleteFollowup(int id);
void cloudWipeAll();
void cloudPushState();
void cloudPullAll();
void cloudForceAll();
String cloudRecall(const int8_t* queryEmb);
void notePresence();
void clearTempAudioBuffers();
void goToSleep();

unsigned long ms_since(unsigned long t) {
  unsigned long n = millis();
  return n >= t ? n - t : 0;
}

void logHeap(const char* tag) {
  Serial.printf("[HEAP] %s: ic bellek bos %u, en dusuk %u, en buyuk blok %u | PSRAM bos %u\n", tag,
                (unsigned)heap_caps_get_free_size(MALLOC_CAP_INTERNAL),
                (unsigned)heap_caps_get_minimum_free_size(MALLOC_CAP_INTERNAL),
                (unsigned)heap_caps_get_largest_free_block(MALLOC_CAP_INTERNAL),
                (unsigned)heap_caps_get_free_size(MALLOC_CAP_SPIRAM));
  if (WiFi.status() == WL_CONNECTED) Serial.printf("[WIFI] sinyal %d dBm\n", (int)WiFi.RSSI());
}

const char* stateName(int s) {
  switch (s) {
    case IDLE: return "IDLE";
    case LISTENING: return "LISTENING";
    case THINKING: return "THINKING";
    default: return "SPEAKING";
  }
}

