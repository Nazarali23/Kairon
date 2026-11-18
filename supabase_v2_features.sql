-- ====================================================================
-- KAIRON V2: KONSOL, ÇOKLU MOD, KİŞİLİK VE HATIRLATICI MİGRASYONU
-- ====================================================================

-- 1. robot_state tablosuna geçici konsol ve ekran parlaklığı sütunları
ALTER TABLE robot_state ADD COLUMN IF NOT EXISTS console_cmd text DEFAULT '';
ALTER TABLE robot_state ADD COLUMN IF NOT EXISTS console_output text DEFAULT '';
ALTER TABLE robot_state ADD COLUMN IF NOT EXISTS screen_brightness int DEFAULT 100;

-- 2. followups (hatırlatıcılar) tablosuna tekrar tipi ve tamamlanma alanları
ALTER TABLE followups ADD COLUMN IF NOT EXISTS recurring text DEFAULT 'none'; -- 'none', 'daily', 'weekly'
ALTER TABLE followups ADD COLUMN IF NOT EXISTS title text DEFAULT '';

-- 3. İndeksler ve performans
CREATE INDEX IF NOT EXISTS idx_followups_due ON followups (due);
CREATE INDEX IF NOT EXISTS idx_followups_asked ON followups (asked);

-- 4. Mevcut robot_state satırını güvenle başlat
UPDATE robot_state 
SET 
  console_cmd = COALESCE(console_cmd, ''),
  console_output = COALESCE(console_output, ''),
  screen_brightness = COALESCE(screen_brightness, 100)
WHERE id = 1;
