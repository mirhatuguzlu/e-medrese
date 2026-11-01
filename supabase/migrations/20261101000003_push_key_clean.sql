-- Kenarları kırpmak yetmedi: yapıştırılan anahtarın içinde de libcurl'ü
-- bozan karakter (satır sonu, tırnak, görünmez karakter) olabiliyor.
-- JWT yalnızca base64url harfleri ve noktadan oluşur; gerisi atılır.
create or replace function public.ping_send_push() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  k text := (select regexp_replace(decrypted_secret, '[^A-Za-z0-9._-]', '', 'g')
             from vault.decrypted_secrets where name = 'service_role_key');
begin
  if k is not null then
    perform net.http_post(
      url := 'https://abtsartfcblqeqwpsdxl.supabase.co/functions/v1/send-push',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || k
      )
    );
  end if;
  return null;
end $$;
