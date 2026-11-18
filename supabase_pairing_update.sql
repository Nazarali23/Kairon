-- ====================================================================
-- KAIRON EKOSİSTEMİ - CİHAZ SAHİPLİĞİ VE EŞLEŞTİRME GÜNCELLEMESİ
-- Mobil Kullanıcı Hesabı + Robot-QR + PC-QR (WhatsApp Web Modeli)
-- ====================================================================

-- 1. robot_state tablosuna sahip kullanıcı ve eşleşme token'ı ekleme
alter table robot_state
  add column if not exists owner_id uuid references auth.users(id),
  add column if not exists pairing_token text;

-- 2. pc_agent_state tablosuna sahip kullanıcı ve eşleşme token'ı ekleme
alter table pc_agent_state
  add column if not exists owner_id uuid references auth.users(id),
  add column if not exists pairing_token text,
  add column if not exists pc_name text;

-- 3. pc_commands tablosuna komutu veren kullanıcıyı bağlama
alter table pc_commands
  add column if not exists user_id uuid references auth.users(id);

-- 4. Anlık Eşleşme Oturumları Tablosu (Pairing Sessions)
create table if not exists pairing_sessions (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  device_type text not null,            -- 'robot' veya 'pc'
  device_name text,                     -- 'Nazarali-Laptop' veya 'Kairon-S3'
  pairing_token text not null unique,   -- 6 haneli PIN veya QR token
  claimed_by uuid references auth.users(id),
  claimed_at timestamptz,
  expires_at timestamptz not null default (now() + interval '15 minutes')
);

create index if not exists idx_pairing_sessions_token on pairing_sessions (pairing_token);

alter table pairing_sessions enable row level security;

-- Herkes geçici eşleşme oluşturabilir (PC/Robot)
drop policy if exists pairing_sessions_anon on pairing_sessions;
create policy pairing_sessions_anon on pairing_sessions
  for all to anon using (true) with check (true);

-- Giriş yapmış kullanıcılar eşleştirmeyi sahiplenebilir
drop policy if exists pairing_sessions_auth on pairing_sessions;
create policy pairing_sessions_auth on pairing_sessions
  for all to authenticated using (true) with check (true);

-- Realtime yayını
do $$
begin
  alter publication supabase_realtime add table pairing_sessions;
exception when others then null;
end $$;
