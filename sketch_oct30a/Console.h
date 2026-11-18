#pragma once
// Seri monitor komutlari ve (opsiyonel) derin uyku
// ================= DERIN UYKU =================
#if ENABLE_SLEEP
void goToSleep() {
  Serial.println("[DERIN UYKU] Uykuya hazirlaniliyor...");
  consolidate();
  if (timeValid()) lastSeenEpoch = nowEpoch();
  memSave();
  
#if USE_TFT
  Serial.println("[DERIN UYKU] Ekran uyutuluyor (DISPOFF + SLPIN)...");
  if (faceHandle) vTaskSuspend(faceHandle);
  tft.fillScreen(C_BLACK);
  tft.enableDisplay(false);             // ST7789 DISPOFF (0x28)
  tft.sendCommand((uint8_t)0x10);       // ST7789 SLPIN (0x10) donanim uyku komutu
  // Deep sleep sirasinda ekranin reset yememesi ve beyaza donmemesi icin CS ve RST pinlerini kitle
  digitalWrite(TFT_CS, HIGH);
  digitalWrite(TFT_RST, HIGH);
  gpio_hold_en((gpio_num_t)TFT_CS);
  gpio_hold_en((gpio_num_t)TFT_RST);
  gpio_deep_sleep_hold_en();
#endif

  if (servoHandle) vTaskSuspend(servoHandle);

  Serial.printf("[DERIN UYKU] PIR durumu: %d (HIGH ise max 4 sn bekleniyor)...\n", digitalRead(PIR_PIN));
  unsigned long pirWaitStart = millis();
  while (digitalRead(PIR_PIN) == HIGH && (millis() - pirWaitStart < 4000)) {
    delay(100);
  }

  Serial.println("[DERIN UYKU] PIR wake-up kuruluyor...");
  pinMode(PIR_PIN, INPUT_PULLDOWN);
  gpio_pulldown_en((gpio_num_t)PIR_PIN);
  gpio_pullup_dis((gpio_num_t)PIR_PIN);
  esp_sleep_enable_ext1_wakeup_io(1ULL << PIR_PIN, ESP_EXT1_WAKEUP_ANY_HIGH);

  Serial.println("[DERIN UYKU] ESP32 derin uykuya geciyor! Odaya girildiginde PIR ile uyanacak.");
  Serial.flush();
  delay(100);
  esp_deep_sleep_start();
}
#else
void goToSleep() {}
#endif

// ================= MERKEZI KONSOL KOMUT MOTORU =================
// Hem Seri Port'tan hem de Mobil Uygulama / Supabase'den gelen komutlari ortak calistirir
String runConsoleCommand(String s) {
  s.trim();
  if (!s.length()) return "";
  Serial.printf("[KONSOL ISLECI] %s\n", s.c_str());
  stopAll();

  if (s == "dur") return "Robot durduruldu.";
  if (s == "ton") { playTestTone(); return "Test tonu calindi."; }

  if (s == "/restart" || s == "restart" || s == "/reboot" || s == "reboot") {
    Serial.println("[SISTEM] Yeniden baslatiliyor (ESP.restart)...");
    Serial.flush();
    delay(200);
    ESP.restart();
    return "ESP32 yeniden baslatiliyor...";
  }

#if USE_TFT
  if (s == "/reinit" || s == "/ekran" || s == "ekran") {
    reinitTft();
    return "TFT ekran yeniden baslatildi.";
  }
  if (s.startsWith("/madctl ")) {
    uint8_t v = (uint8_t)strtol(s.substring(8).c_str(), nullptr, 16);
    setRawMadctl(v);
    tft.fillScreen(C_BLACK);
    tft.setTextSize(2);
    tft.setTextColor(C_YELLOW);
    tft.setCursor(20, 50);
    tft.printf("MADCTL: 0x%02X", v);
    tft.setTextColor(C_WHITE);
    tft.setCursor(20, 90);
    tft.print("TEST: ABC 123 Robot");
    return "MADCTL ayarlandi: 0x" + String(v, HEX);
  }
  if (s == "/mirror") {
    static uint8_t mirrorMode = 0;
    mirrorMode = (mirrorMode + 1) % 4;
    uint8_t modes[] = {0x20, 0x60, 0xA0, 0xE0};
    setRawMadctl(modes[mirrorMode]);
    tft.fillScreen(C_BLACK);
    tft.setTextSize(2);
    tft.setTextColor(C_GREEN);
    tft.setCursor(20, 50);
    tft.printf("MOD %d (0x%02X)", mirrorMode, modes[mirrorMode]);
    return "Ayna modu degistirildi: " + String(mirrorMode);
  }
#endif

  // ---- Servo Motor Komutlari ----
  if (s.startsWith("/aci ")) {
    int sp = s.indexOf(' ', 5);
    if (sp > 0) {
      float p = s.substring(5, sp).toFloat();
      float t = s.substring(sp + 1).toFloat();
      lockHeadAt(p, t, 110.0f, 300.0f);
      return "Yeni aci pan=" + String(tgtPan, 1) + ", tilt=" + String(tgtTilt, 1);
    }
    return "Gecersiz aci komutu. Ornek: /aci 90 90";
  }
  if (s.startsWith("/kafa ")) {
    userLookRequest = true;                       // seri komut = kullanici istegi: "kal" kilitler
    String gesture = s.substring(6);
    applyHeadByName(gesture);
    return "Kafa hareketi uygulandi: " + gesture;
  }
  if (s.startsWith("/servohiz ")) {
    servoMaxSpeed = constrain(s.substring(10).toFloat(), 25.0f, 180.0f);
    servoMaxAccel = constrain(servoMaxSpeed * 3.2f, 80.0f, 700.0f);
    return "Servo hiz: " + String(servoMaxSpeed, 1) + " deg/s";
  }
  if (s.startsWith("/sonar")) {
    String a = s.substring(6); a.trim();
    if (a.startsWith("test")) { sonar.selfTest(); return "Sonar self-test tamamlandi."; }
    if (a.startsWith("log")) { bool on = a.indexOf("on") >= 0; sonar.setDebug(on); return on ? "Sonar log ACIK" : "Sonar log KAPALI"; }
    if (a.startsWith("on")) sonar.setEnabled(true);
    else if (a.startsWith("off")) sonar.setEnabled(false);
    sonar.printStatus();
    return "Sonar durumu: " + String(sonar.enabled() ? "ETKIN" : "DEVRE DISI") +
           " | Mesafe: " + String(sonar.distance()) + " cm" +
           " | Gorunur: " + String(sonar.userVisible() ? "EVET" : "HAYIR");
  }

  if (s == "/reset") { histClear(); sessionLog = ""; sessionTurns = 0; return "Gecici konusma gecmisi silindi."; }
  if (s == "/models") { listModels(); return "Groq modelleri listelendi (Seri porta bakiniz)."; }
  if (s == "/time") { return "Sistem Saati: " + humanTime(); }
  if (s == "/mem") { printMem(); return "Hafiza: " + String(nRecs) + " kayit aktif."; }
  if (s == "/days") { printDays(); return "Ozel Gunler: " + String(nDays) + " gun kayitli."; }
  if (s == "/brain") { printBrain(); return "Brain durumu döküldü (Seri porta bakiniz)."; }
  if (s == "/undo") { return "Geri alindi: " + memUndo(); }
  if (s == "/cloudsync") {
    cloudForceAll();
    for (int i = 0; i < nRecs; i++) cloudUpsertRec(i);
    cloudSyncDays();
    cloudSyncFollowups();
    cloudPushState();
    return String(nRecs) + " ani, " + String(nDays) + " ozel gun, " + String(nFu) + " takip senkronlandi.";
  }
  if (s == "/cloudpull") {
    cloudPullAll();
    return "Buluttan tum veriler basariyla cekildi.";
  }
  if (s.startsWith("/face ")) {
    int e = s.substring(6).toInt();
    currentEmotion = constrain(e, 0, 8); emotionSetMs = millis();
    setEmotionPose(currentEmotion, tgtL, tgtR); idleActEnd = millis() + 6000;
    applyHeadFromEmotion(currentEmotion);
    return "Yuz ifadesi ayarlandi: " + String(currentEmotion);
  }
  if (s == "/sleep" || s == "/saat") {
    idleAct = A_SLEEP; idleActEnd = millis() + 10000;
    sleepSinceMs = millis() - CLOCK_AFTER_SLEEP_MS + 2000;
    setEmotionPose(0, tgtL, tgtR); tgtL.h = tgtR.h = 3;
    return "Saat ekranina gecildi.";
  }
#if ENABLE_SLEEP
  if (s == "/deepsleep" || s == "deepsleep") {
    goToSleep();
    return "Derin uykuya gecildi.";
  }
#endif
  if (s.startsWith("/prompt ")) { return buildSystem(s.substring(8), false); }
  if (s == "/wipe evet") {
    nRecs = 0; nDays = 0; nFu = 0; lastCheckinDate = ""; sessionLog = ""; sessionTurns = 0;
    histClear();
    purgeLocalFiles();
    cloudWipeAll();
    return "Tum yerel RAM ve bulut hafizasi sifirlandi.";
  }
  if (s == "/wipe") { return "TUM hafizayi silmek icin: /wipe evet"; }
  if (s == "/muse") { spontaneousSpeak(R_MUSE); return "Kairon muse konusmasi baslatildi."; }
  if (s.startsWith("/remember ")) { return rememberNote(s.substring(10)); }
  if (s.startsWith("/forget ")) { return forgetBest(s.substring(8)); }
  if (s.startsWith("/day ")) { return addDayFromSpec(s.substring(5)); }
  if (s.startsWith("/style ")) {
    String resp = applyStyleByName(s.substring(7));
    return "Tarz guncellendi: " + String(STYLE_NAMES[styleMode]) + " (" + resp + ")";
  }
  if (s.startsWith("/say ")) { speak(s.substring(5)); return "Seslendirildi: " + s.substring(5); }
  if (s.startsWith("/vol ")) {
    volume = constrain(s.substring(5).toFloat(), 0.0f, 1.0f);
    printFx();
    return "Ses seviyesi: %" + String((int)(volume * 100));
  }
  if (s == "/qr" || s == "/pair") {
    if (pairingScreen.active) {
      pairingScreen.leave();
      return "QR ekrani kapatildi, robot yuzu geri geldi.";
    } else {
      String pin = robotPairingPin.length() ? robotPairingPin : "849201";
      pairingScreen.show(pin);
      return "QR ekrani acildi. PIN: " + pin;
    }
  }
  if (s == "/owner") {
    return robotOwnerId.length() ? ("Sahip Kullanici UUID: " + robotOwnerId) : "Robot henuz bir hesaba baglanmadi.";
  }

  // Varsayilan: Soru olarak yapay zekaya ilet ve seslendir
  askAndSpeak(s);
  return "Soru yapay zekaya iletildi: " + s;
}

// ================= SERIAL PORT YOKLAMA =================
void handleSerial() {
  if (!Serial.available()) return;
  String s = Serial.readStringUntil('\n');
  s.trim();
  if (!s.length()) return;
  String result = runConsoleCommand(s);
  if (result.length()) {
    Serial.printf("[KONSOL] %s\n", result.c_str());
  }
}
