#include "Config.h"
#include "NetGuard.h"
#include "Sonar.h"
#include "Servo.h"
#include "Utils.h"
#include "Display.h"
#include "Face.h"
#include "WifiManager.h" // <--- Yorum işaretleri kaldırıldı, tekrar aktif.
#include "Audio.h"
#include "Memory.h"
#include "Brain.h"
#include "Cloud.h"
#include "Conversation.h"
#include "Mic.h"
#include "Console.h"

SET_LOOP_TASK_STACK_SIZE(32 * 1024);   // MP3 cozucu buyuk yigin ister

void setup() {
#if USE_TFT
  // Derin uykudan uyanildiysa kilitlenen pinleri serbest birak
  gpio_hold_dis((gpio_num_t)TFT_CS);
  gpio_hold_dis((gpio_num_t)TFT_RST);
#endif
  Serial.begin(115200);
  delay(1000);
  NetGuard::begin();
#if USE_PIR
  pinMode(PIR_PIN, INPUT_PULLDOWN);
#endif

#if USE_SERVOS
  // Servolar ayri ayri baslatilir: ikisi birden kalkinca cekilen ani akim brownout yapabiliyor
  ledcAttach(SERVO_PAN_PIN, 50, 14);
  curPan = tgtPan = PAN_CENTER;
  curTilt = tgtTilt = TILT_CENTER;
  writePanAngle(PAN_CENTER);
  delay(400);
  ledcAttach(SERVO_TILT_PIN, 50, 14);
  writeTiltAngle(TILT_CENTER);
  delay(300);
#endif

  lastActivity = millis();
  sqMutex = xSemaphoreCreateMutex();

#if USE_TFT
  SPI.begin(TFT_CLK, -1, TFT_MOSI, TFT_CS);
  tft.init(240, 320);
  tft.invertDisplay(TFT_INVERT);
  tft.setSPISpeed(20000000); // 20MHz en stabil frekans (beyaz ekran parazitini onler)
  applyTftRotation(1);
  tft.fillScreen(0x0000);
#endif

  setState(IDLE);
  xTaskCreatePinnedToCore(faceTask, "face", 8192, NULL, 1, &faceHandle, 1);
  
#if USE_SERVOS
  xTaskCreatePinnedToCore(servoTask, "servo", 4096, NULL, 2, &servoHandle, 1);
#endif

  sonar.begin();
#if USE_SONAR
  sonar.setEnabled(false);  // Baslangicta kapali: konusma basladiginda acilir, 10sn sonra kapanir
#endif

  Serial.printf("PSRAM: %d, boyut: %u\n", psramFound(), ESP.getPsramSize());
  recBuf = (int16_t*)ps_malloc(MAX_SAMPLES * sizeof(int16_t));
  mp3Buf = (uint8_t*)ps_malloc(MP3_MAX);
  pcmA = (int16_t*)ps_malloc(TTS_MAX * sizeof(int16_t));
  pcmB = (int16_t*)ps_malloc(TTS_MAX * sizeof(int16_t));
  outBuf = (int16_t*)ps_malloc(TTS_MAX * sizeof(int16_t));
  
  if (!recBuf || !mp3Buf || !pcmA || !pcmB || !outBuf) Serial.println("PSRAM tamponlari ayrilamadi!");
  if (!LittleFS.begin(true)) Serial.println("LittleFS baslatilamadi");

// --- Wİ-Fİ BAĞLANTI VE EKRAN BİLGİLENDİRME ---
  if (!wifiMgr.connectStation()) {
    wifiMgr.startConfigPortal();
    
#if USE_TFT
    // Yüz çizim görevini durduruyoruz (yoksa yazıları siler)
    if (faceHandle != NULL) {
        vTaskSuspend(faceHandle); 
    }
    
    applyTftRotation(1);
    tft.fillScreen(0x0000); // Arka plan siyah
    tft.setTextSize(2);
    
    tft.setTextColor(0xF800); // Kırmızı
    tft.setCursor(20, 30);
    tft.print("WIFI BULUNAMADI!"); 
    
    tft.setTextColor(0xFFFF); // Beyaz
    tft.setCursor(20, 70);
    tft.print("Telefondan baglan:");
    
    tft.setTextColor(0xFFE0); // Sarı
    tft.setCursor(20, 100);
    tft.print("Ag: Robot_Kurulum");
    tft.setCursor(20, 130);
    tft.print("Sifre: 12345678");
    
    tft.setTextColor(0xFFFF); // Beyaz
    tft.setCursor(20, 170);
    tft.print("Sonra tarayiciya yaz:");
    
    tft.setTextColor(0x07E0); // Yeşil
    tft.setCursor(20, 200);
    tft.print("192.168.4.1");
#endif
  }
  // --------------------------------------------------------
  configTzTime("<+03>-3", "pool.ntp.org", "time.google.com");
  unsigned long tn = millis();
  while (!timeValid() && millis() - tn < 8000) delay(200);
  Serial.printf("[ZAMAN] %s\n", humanTime().c_str());

  memInitRAM();
  cloudPullAll();

  if (robotOwnerId.length() == 0) {
    String pin = robotPairingPin.length() ? robotPairingPin : "849201";
    pairingScreen.show(pin);
    Serial.println("[PAIR] Robot henuz bir hesaba bagli degil. Ekranda QR ve PIN gosteriliyor: " + pin);
  } else {
    // Robot zaten bir hesaba bagli: Ekrandaki eski QR ve yazilari tamamen temizle
    pairingScreen.active = false;
    tft.fillScreen(C_BLACK);
    lastL.w = -99; lastR.w = -99; lastColor = 0;
  }

  Serial.printf("[VEKTOR] Gemini anahtari: %s\n", strlen(GEMINI_KEY) >= 10 ? "var" : "yok (kelime aramasi kullanilacak)");
  Serial.printf("[BULUT] etkin: %s\n", cloudEnabled() ? "evet" : "hayir (URL/anahtar/WiFi?)");

  spk.setPins(I2S_BCLK, I2S_LRC, I2S_DOUT);
  if (!spk.begin(I2S_MODE_STD, OUT_RATE, I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_STEREO)) {
    Serial.println("Hoparlor baslatilamadi!");
  }

  micBegin();
  calibrate();
  printFx();
  xTaskCreatePinnedToCore(cloudTaskLoop, "CloudTask", 16384, NULL, 1, &cloudTask, 0);
  Serial.println("Hazir. /kafa evet | /kafa hayir | /kafa asagi | /kafa 45,130,hizli,kal | /style ciddi ...");
}
void loop() {
  if (wifiMgr.inAP) {
    wifiMgr.handleClient();
    return;
  }

  handleSerial();
  wifiMgr.watchdog();                    // baglanti koparsa yeniden baglan

#if USE_SONAR
  // Konusma sonrasi 10sn gecinse sonari kapat
  if (sonarConvUntilMs != 0 && millis() > sonarConvUntilMs) {
    sonar.setEnabled(false);
    sonarConvUntilMs = 0;
    Serial.println("[SONAR] konusma penceresi kapandi, sonar kapatildi");
  }
#endif

  if (!powerOn) {
    delay(50);
    return;
  }

  if (appSayReady && state == IDLE) {
    String say = String(appSayBuf);
    appSayReady = false;
    speak(say);
  }

  if (state != IDLE) lastActivity = millis();

  if (state == IDLE || state == LISTENING) micTask();

  if (state == LISTENING && ms_since(stateSinceMs) > 14000UL) {
    Serial.println("[BEKCI] dinleme 14 sn'yi asti, IDLE'a donuluyor");
    stopAll();
  }

  if (state == IDLE && ms_since(tBrain) > 3000) { tBrain = millis(); brainTick(); }

#if ENABLE_SLEEP
  // Derin uyku: Uzun sure (12 dk) ses veya PIR hareketi yoksa tamamen kapanip derin uykuya gec
  if (state == IDLE && 
      ms_since(lastActivity) > DEEP_SLEEP_AFTER_MS && 
      (lastPresenceMs == 0 || ms_since(lastPresenceMs) > DEEP_SLEEP_AFTER_MS)) {
    Serial.println("[DERIN UYKU] Uzun sure hareket/ses yok, robot tamamen kapaniyor (PIR ile uyanacak)");
    goToSleep();
  }
#endif

  if (state == SPEAKING) {
    pumpAudio();
    if (!playing) {
      if (qHead < qCount) { if (!prepareNextChunk()) speechDone("TTS parcasi basarisiz"); }
      else speechDone("ses bitti");
    }
    if (state == SPEAKING && ms_since(tSpeakStart) > 40000) speechDone("40 sn zaman asimi");
  }
}