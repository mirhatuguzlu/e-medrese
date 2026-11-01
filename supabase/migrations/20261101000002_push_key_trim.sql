-- Vault'a yapıştırılan anahtardaki boşluk/satır sonu pg_net isteğini
-- bozuyordu ("A libcurl function was given a bad argument").
create or replace function public.ping_send_push() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  k text := (select trim(both E' \t\r\n' from decrypted_secret)
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
