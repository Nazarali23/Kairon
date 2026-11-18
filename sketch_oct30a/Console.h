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

// ================= SERIAL KOMUTLARI =================
void handleSerial() {
  if (!Serial.available()) return;
  String s = Serial.readStringUntil('\n');
  s.trim();
  if (!s.length()) return;
  Serial.printf("[KOMUT] %s\n", s.c_str());
  stopAll();
  if (s == "dur") return;
  if (s == "ton") { playTestTone(); return; }

  if (s == "/restart" || s == "restart" || s == "/reboot" || s == "reboot") {
    Serial.println("[SISTEM] Yeniden baslatiliyor (ESP.restart)...");
    Serial.flush();
    delay(200);
    ESP.restart();
    return;
  }
#if USE_TFT
  if (s == "/reinit" || s == "/ekran" || s == "ekran") {
    reinitTft();
    return;
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
    return;
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
    tft.setTextColor(C_WHITE);
    tft.setCursor(20, 90);
    tft.print("TEST: Robot Duzgun mu? 123");
    Serial.printf("[AYNA] Mod %d (0x%02X). Ekrani kontrol et.\n", mirrorMode, modes[mirrorMode]);
    return;
  }
#endif

  // ---- Servo Motor Komutlari ----
  if (s.startsWith("/aci ")) {
    int sp = s.indexOf(' ', 5);
    if (sp > 0) {
      float p = s.substring(5, sp).toFloat();
      float t = s.substring(sp + 1).toFloat();
      lockHeadAt(p, t, 110.0f, 300.0f);
      Serial.printf("Yeni Aci (Kilitlendi) -> Pan: %.1f (0-180), Tilt: %.1f (sinir %.0f-%.0f)\n", tgtPan, tgtTilt, TILT_MIN, TILT_MAX);
    }
    return;
  }
  if (s.startsWith("/kafa ")) {
    userLookRequest = true;                       // seri komut = kullanici istegi: "kal" kilitler
    applyHeadByName(s.substring(6));
    Serial.printf("Kafa hareketi: %s\n", s.substring(6).c_str());
    return;
  }
  if (s.startsWith("/servohiz ")) {
    servoMaxSpeed = constrain(s.substring(10).toFloat(), 25.0f, 180.0f);
    servoMaxAccel = constrain(servoMaxSpeed * 3.2f, 80.0f, 700.0f);
    Serial.printf("Servo varsayilan hiz: %.1f derece/sn (yumusaklik: %.1f)\n", servoMaxSpeed, servoMaxAccel);
    return;
  }
  if (s.startsWith("/sonar")) {                 // /sonar | /sonar on | /sonar off | /sonar test | /sonar log on|off
    String a = s.substring(6); a.trim();
    if (a.startsWith("test")) { sonar.selfTest(); return; }
    if (a.startsWith("log")) { bool on = a.indexOf("on") >= 0; sonar.setDebug(on); Serial.printf("sonar log: %s\n", on ? "ACIK" : "KAPALI"); return; }
    if (a.startsWith("on")) sonar.setEnabled(true);
    else if (a.startsWith("off")) sonar.setEnabled(false);
    sonar.printStatus();
    return;
  }

  if (s == "/reset") { histClear(); sessionLog = ""; sessionTurns = 0; Serial.println("gecici konusma gecmisi silindi"); return; }
  if (s == "/models") { listModels(); return; }
  if (s == "/time") { Serial.printf("%s\n", humanTime().c_str()); return; }
  if (s == "/mem") { printMem(); return; }
  if (s == "/days") { printDays(); return; }
  if (s == "/brain") { printBrain(); return; }
  if (s == "/undo") { Serial.printf("%s\n", memUndo().c_str()); return; }
  if (s == "/cloud") {
    logHeap("cloud");
    Serial.printf("[NET] arka plan serbest: %s\n", NetGuard::backgroundAllowed() ? "evet" : "hayir (konusma/ses var)");
    Serial.printf("[BULUT] bekleyen yazma istegi: %d\n", sqCount);
    Serial.printf("[BULUT] etkin: %s | url uzunlugu %d | anahtar uzunlugu %d | wifi %d\n",
                  cloudEnabled() ? "evet" : "hayir", (int)strlen(SUPABASE_URL), (int)strlen(SUPABASE_KEY), WiFi.status() == WL_CONNECTED);
    String r; int c = supaRequest("memories?select=id&limit=1", "GET", "", r);
    Serial.printf("[BULUT] memories GET -> %d %s\n", c, r.substring(0, 120).c_str());
    return;
  }
  if (s == "/cloudsync") {
    // Zorla hepsini gonder (normalde gerekmez: sadece degisenler otomatik gider)
    cloudForceAll();
    for (int i = 0; i < nRecs; i++) cloudUpsertRec(i);
    cloudSyncDays();
    cloudSyncFollowups();
    cloudPushState();
    Serial.printf("%d ani, %d ozel gun, %d takip ve ayarlar buluta gonderildi\n", nRecs, nDays, nFu);
    return;
  }
  if (s == "/cloudpull") {
    cloudPullAll();
    return;
  }
  if (s.startsWith("/face ")) {
    int e = s.substring(6).toInt();
    currentEmotion = constrain(e, 0, 8); emotionSetMs = millis();
    setEmotionPose(currentEmotion, tgtL, tgtR); idleActEnd = millis() + 6000;
    applyHeadFromEmotion(currentEmotion);
    return;
  }
  if (s == "/sleep" || s == "/saat") {
    idleAct = A_SLEEP; idleActEnd = millis() + 10000;
    sleepSinceMs = millis() - CLOCK_AFTER_SLEEP_MS + 2000;
    setEmotionPose(0, tgtL, tgtR); tgtL.h = tgtR.h = 3;
    Serial.println("[UYKU] 2 sn sonra saat ekrani acilacak");
    return;
  }
#if ENABLE_SLEEP
  if (s == "/deepsleep" || s == "deepsleep") {
    Serial.println("[KOMUT] Derin uykuya geciliyor (PIR ile uyanacak)...");
    goToSleep();
    return;
  }
#endif
  if (s.startsWith("/prompt ")) { Serial.println(buildSystem(s.substring(8), false)); return; }
  if (s == "/embed") { int e = embedPending(8); Serial.printf("%d kayit icin embedding alindi\n", e); memSave(); return; }
  if (s == "/embedall") {
    // Onbellekteki tum kayitlari yeniden embedle ve buluta bir kez yaz (bulutta embedding'i eksik kayitlari tamamlamak icin)
    for (int i = 0; i < nRecs; i++) recs[i].flags &= ~(F_EMB | F_REMOTE);
    int total = 0, e;
    for (int round = 0; round < 3 && (e = embedPending(8)) > 0; round++) total += e;
    Serial.printf("%d kayit embedlendi ve buluta yazildi\n", total);
    return;
  }
  if (s == "/consolidate") {
    if (sessionTurns == 0) Serial.println("islenecek konusma yok");
    else { consolidateNotBefore = 0; consolidate(); }
    printMem();
    return;
  }
  if (s == "/wipe evet") {
    nRecs = 0; nDays = 0; nFu = 0; lastCheckinDate = ""; sessionLog = ""; sessionTurns = 0;
    histClear();
    purgeLocalFiles();
    cloudWipeAll();
    Serial.println("tum lokal RAM ve bulut hafizasi silindi");
    return;
  }
  if (s == "/wipe") { Serial.println("TUM hafizayi (bulut dahil) silmek icin: /wipe evet"); return; }
  if (s == "/muse") { spontaneousSpeak(R_MUSE); return; }
  if (s == "/arrive") { arrivalPending = true; arrivalAbsenceMin = 180; spontaneousSpeak(R_ARRIVAL); return; }
  if (s.startsWith("/fu ")) {
    if (nFu >= MAX_FOLLOW) { Serial.println("takip listesi dolu"); return; }
    fuText[nFu] = s.substring(4); fuDue[nFu] = dateOf(nowEpoch()); fuAsked[nFu] = false; nFu++;
    memSave();
    spontaneousSpeak(R_FOLLOWUP);
    return;
  }
  if (s.startsWith("/remember ")) { Serial.printf("%s\n", rememberNote(s.substring(10)).c_str()); return; }
  if (s.startsWith("/forget ")) { Serial.printf("%s\n", forgetBest(s.substring(8)).c_str()); return; }
  if (s.startsWith("/recall ")) { recallDebug(s.substring(8)); return; }
  if (s.startsWith("/day ")) { Serial.printf("%s\n", addDayFromSpec(s.substring(5)).c_str()); return; }
  if (s.startsWith("/builtin ")) { builtinDaysOn = s.substring(9).startsWith("on"); memDirty = true; memSave(); printDays(); return; }
  if (s.startsWith("/style ")) {
    String resp = applyStyleByName(s.substring(7));
    Serial.printf("tarz: %s (%s)\n", STYLE_NAMES[styleMode], resp.c_str());
    return;
  }
  if (s.startsWith("/think ")) { llmReasoning = s.substring(7); llmReasoning.trim(); if (llmReasoning == "off") llmReasoning = ""; Serial.printf("dusunme: '%s'\n", llmReasoning.c_str()); return; }
  if (s.startsWith("/model ")) { llmModel = s.substring(7); llmModel.trim(); Serial.printf("model: %s\n", llmModel.c_str()); return; }
  if (s.startsWith("/say ")) { speak(s.substring(5)); return; }
  if (s.startsWith("/speed ")) { ttsSpeed = constrain(s.substring(7).toFloat(), 0.8f, 2.5f); printFx(); return; }
  if (s.startsWith("/pitch ")) { ttsPitch = constrain(s.substring(7).toFloat(), 0.6f, 1.4f); printFx(); return; }
  if (s.startsWith("/vol ")) { volume = constrain(s.substring(5).toFloat(), 0.0f, 1.0f); printFx(); return; }
  if (s.startsWith("/robot ")) {
    String a = s.substring(7);
    int sp = a.indexOf(' ');
    if (sp < 0) robotMix = constrain(a.toFloat(), 0.0f, 1.0f);
    else {
      robotMix = constrain(a.substring(0, sp).toFloat(), 0.0f, 1.0f);
      robotFreq = constrain(a.substring(sp + 1).toFloat(), 20.0f, 400.0f);
    }
    printFx();
    return;
  }
  askAndSpeak(s);
}

