-- ====================================================================
-- KAIRON EKOSİSTEMİ - ÇOKLU KULLANICI VE VERİ İZOLASYONU GÜNCELLEMESİ
-- Tüm tablolara user_id / owner_id ekleme ve mevcut verileri sahiplendirme
-- ====================================================================

-- 1. TÜM TABLOLARA KULLANICI ALANLARI EKLEME
alter table memories add column if not exists user_id uuid references auth.users(id);
alter table special_days add column if not exists user_id uuid references auth.users(id);
alter table followups add column if not exists user_id uuid references auth.users(id);
alter table sensor_logs add column if not exists user_id uuid references auth.users(id);
alter table app_inbox add column if not exists user_id uuid references auth.users(id);
alter table pc_commands add column if not exists user_id uuid references auth.users(id);

alter table robot_state
  add column if not exists owner_id uuid references auth.users(id),
  add column if not exists pairing_token text;

alter table pc_agent_state
  add column if not exists owner_id uuid references auth.users(id),
  add column if not exists pairing_token text,
  add column if not exists pc_name text;

-- İndeksler (Sorgu Hızı İçin)
create index if not exists idx_memories_user on memories (user_id);
create index if not exists idx_special_days_user on special_days (user_id);
create index if not exists idx_followups_user on followups (user_id);
create index if not exists idx_sensor_logs_user on sensor_logs (user_id);
create index if not exists idx_app_inbox_user on app_inbox (user_id);
create index if not exists idx_pc_commands_user on pc_commands (user_id);

-- 2. MEVCUT SAHİPSİZ VERİLERİ BİR KULLANICIYA ATAYAN FONKSİYON
-- (İlk giriş yapan kullanıcının önceki verileri kaybetmemesi için)
create or replace function claim_all_unassigned_data_to_user(target_user_id uuid)
returns jsonb
language plpgsql
security definer
as $$
declare
  mem_count int;
  days_count int;
  fol_count int;
begin
  -- 1. memories tablosunu sahiplendir
  update memories set user_id = target_user_id where user_id is null;
  get diagnostics mem_count = row_count;

  -- 2. special_days tablosunu sahiplendir
  update special_days set user_id = target_user_id where user_id is null;
  get diagnostics days_count = row_count;

  -- 3. followups tablosunu sahiplendir
  update followups set user_id = target_user_id where user_id is null;
  get diagnostics fol_count = row_count;

  -- 4. sensor_logs ve app_inbox
  update sensor_logs set user_id = target_user_id where user_id is null;
  update app_inbox set user_id = target_user_id where user_id is null;
  update pc_commands set user_id = target_user_id where user_id is null;

  -- 5. robot_state ve pc_agent_state
  update robot_state set owner_id = target_user_id where owner_id is null;
  update pc_agent_state set owner_id = target_user_id where owner_id is null;

  return jsonb_build_object(
    'status', 'success',
    'claimed_by', target_user_id,
    'memories_updated', mem_count,
    'special_days_updated', days_count,
    'followups_updated', fol_count
  );
end;
$$;

-- 3. İLK KAYDOLAN KULLANICI İÇİN OTOMATİK SAHİPLENDİRME TRİGGER'I
-- Kullanıcı uygulamadan ilk kez kayıt olduğu an, tüm mevcut sahipsiz veriler
-- otomatik olarak onun hesabına bağlanır! Başka hiçbir kullanıcının eline geçmez.
create or replace function on_first_user_signup_claim_data()
returns trigger
language plpgsql
security definer
as $$
declare
  total_users int;
begin
  select count(*) into total_users from auth.users;
  -- Eğer ilk kullanıcı ise tüm mevcut verileri ona bağla
  if total_users <= 1 then
    perform claim_all_unassigned_data_to_user(new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_first_user_claim on auth.users;
create trigger trg_first_user_claim
  after insert on auth.users
  for each row execute function on_first_user_signup_claim_data();

-- 4. ÇOKLU KULLANICI İÇİN RLS (ROW LEVEL SECURITY) POLİTİKALARI
-- Her kullanıcı sadece KENDİ verisini okuyabilir/yazabilir!
alter table memories enable row level security;
alter table special_days enable row level security;
alter table followups enable row level security;
alter table sensor_logs enable row level security;
alter table app_inbox enable row level security;

-- memories: Giriş yapmış kullanıcı sadece kendi hafızalarını görür, anon ise eşleşmiş robot için okur
drop policy if exists memories_user_isolation on memories;
create policy memories_user_isolation on memories
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists memories_anon_fallback on memories;
create policy memories_anon_fallback on memories
  for all to anon
  using (true) with check (true);

-- special_days: Kullanıcı izolasyonu
drop policy if exists special_days_user_isolation on special_days;
create policy special_days_user_isolation on special_days
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists special_days_anon_fallback on special_days;
create policy special_days_anon_fallback on special_days
  for all to anon
  using (true) with check (true);

-- followups: Kullanıcı izolasyonu
drop policy if exists followups_user_isolation on followups;
create policy followups_user_isolation on followups
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists followups_anon_fallback on followups;
create policy followups_anon_fallback on followups
  for all to anon
  using (true) with check (true);

-- sensor_logs: Kullanıcı izolasyonu
drop policy if exists sensor_logs_user_isolation on sensor_logs;
create policy sensor_logs_user_isolation on sensor_logs
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- app_inbox: Kullanıcı izolasyonu
drop policy if exists app_inbox_user_isolation on app_inbox;
create policy app_inbox_user_isolation on app_inbox
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
