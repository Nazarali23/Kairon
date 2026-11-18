-- ====================================================================
-- KAIRON ROBOTİK ASİSTAN - BİRLEŞİK SUPABASE VERİTABANI KURULUMU
-- KaironAgent (PC) ve KaironMobile (Flutter) için gerekli tablolar
-- ====================================================================

-- 1. PC Ajanı Komut Kuyruğu (pc_commands)
create table if not exists pc_commands (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  kind text not null default 'task',      -- task | confirm | cancel | undo
  utterance text not null,                -- kullanıcının sesli komut metni (STT)
  intent text,                            -- robot LLM tahmini (ipucu)
  args jsonb not null default '{}',       -- örn: {"folder_name": "Dersler"}
  ref_id uuid,                            -- confirm/cancel/undo için hedef komut
  nonce text not null unique,             -- tekrar saldırılarını (replay) önleme
  ts bigint not null,                     -- robotun epoch saniyesi
  sig text not null,                      -- HMAC-SHA256 imzası (hex)
  status text not null default 'pending', -- pending | received | planning | awaiting_confirm | running | done | failed | rejected | expired | cancelled | undone
  plan jsonb,
  result text,                            -- robotun seslendireceği sonuç cümlesi
  error text,                             -- teknik hata kaydı (log)
  claimed_by text,                        -- komutu alan PC ana makine adı
  claimed_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists idx_pc_commands_status_created on pc_commands (status, created_at);

-- 2. PC Ajanı Canlılık Durumu (pc_agent_state)
create table if not exists pc_agent_state (
  id int primary key default 1,
  online boolean default false,
  busy boolean default false,
  version text default '0.1.0',
  last_seen timestamptz default now()
);

-- İlk satırı garantiye al (id=1)
insert into pc_agent_state (id, online, busy, version, last_seen)
values (1, false, false, '0.1.0', now())
on conflict (id) do nothing;

-- 3. IoT Sensör Logları & Telemetri (sensor_logs)
create table if not exists sensor_logs (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  active_mode text not null default 'normal', -- normal | focus | guard | sleep | care | office
  pir_motion boolean not null default false,
  distance_cm int,                            -- ortalama mesafe ((sol + sağ) / 2)
  left_cm int,
  right_cm int,
  event_type text not null,                   -- periodic | posture_warn | intrusion | inactivity | sleep_move | pomodoro_done | med_ack
  note text                                   -- ek bilgi/açıklama
);

create index if not exists idx_sensor_logs_created on sensor_logs (created_at desc);
create index if not exists idx_sensor_logs_event_created on sensor_logs (event_type, created_at desc);

-- 4. Mobil Gelen Kutusu & PC Belge Özetleri (app_inbox)
create table if not exists app_inbox (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  source text not null default 'pc_agent',    -- pc_agent | robot
  kind text not null default 'summary',       -- summary | alert | report
  title text not null,
  body text not null,
  file_path text,
  is_read boolean not null default false
);

create index if not exists idx_app_inbox_created on app_inbox (created_at desc);

-- ====================================================================
-- RLS (ROW LEVEL SECURITY) POLİTİKALARI
-- ====================================================================

-- pc_commands RLS
alter table pc_commands enable row level security;

drop policy if exists robot_insert_pc_cmd on pc_commands;
create policy robot_insert_pc_cmd on pc_commands for insert to anon
  with check (status = 'pending' and kind in ('task','confirm','cancel','undo'));

-- anon için pc_commands üzerinde select/update yok (PC service_role ile okur ve günceller)

-- pc_agent_state RLS
alter table pc_agent_state enable row level security;

drop policy if exists robot_read_pc_state on pc_agent_state;
create policy robot_read_pc_state on pc_agent_state for select to anon
  using (true);

-- sensor_logs RLS (ESP32 anon ile yazar, Mobil anon ile okur)
alter table sensor_logs enable row level security;

drop policy if exists sensor_logs_anon_read on sensor_logs;
create policy sensor_logs_anon_read on sensor_logs for select to anon
  using (true);

drop policy if exists sensor_logs_anon_insert on sensor_logs;
create policy sensor_logs_anon_insert on sensor_logs for insert to anon
  with check (true);

-- app_inbox RLS (Mobil anon ile okur/günceller, PC service_role ile yazar)
alter table app_inbox enable row level security;

drop policy if exists app_inbox_anon_all on app_inbox;
create policy app_inbox_anon_all on app_inbox for all to anon
  using (true) with check (true);

-- ====================================================================
-- REALTIME YAYIN AYARLARI (Canlı Güncellemeler İçin)
-- ====================================================================
do $$
begin
  alter publication supabase_realtime add table sensor_logs;
exception when others then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table app_inbox;
exception when others then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table pc_agent_state;
exception when others then null;
end $$;
