// Gönderilmemiş bildirimleri FCM ile telefonlara yollar.
// notifications tablosuna satır eklenince veritabanı bu fonksiyonu
// service_role anahtarıyla çağırır. İmzayı Supabase doğrular (verify_jwt);
// burada yalnızca rolün service_role olduğuna bakılır.
import { createClient } from 'npm:@supabase/supabase-js@2.49.4';
import { decodeJwt, importPKCS8, SignJWT } from 'npm:jose@5.9.6';

const account = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT')!);

// Service account ile 1 saatlik Google erişim belirteci alır.
async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256' })
    .setIssuer(account.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(await importPKCS8(account.private_key, 'RS256'));
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!res.ok) throw new Error(`token: ${await res.text()}`);
  return (await res.json()).access_token;
}

type Pending = { kind: string; title: string; body: string; tokens: string[] };

Deno.serve(async (req) => {
  const key = req.headers.get('Authorization')?.replace(/^Bearer /, '') ?? '';
  let role: unknown;
  try {
    role = decodeJwt(key).role;
  } catch {
    // Biçimi bozuk anahtar: aşağıda reddedilir.
  }
  if (role !== 'service_role') {
    return new Response('forbidden', { status: 403 });
  }
  const db = createClient(Deno.env.get('SUPABASE_URL')!, key);
  const { data, error } = await db.rpc('claim_pending_pushes');
  if (error) return new Response(error.message, { status: 500 });
  const pending = data as Pending[];
  if (!pending.some((p) => p.tokens.length)) return new Response('ok');

  const auth = `Bearer ${await accessToken()}`;
  const url =
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;
  const dead: string[] = [];
  await Promise.all(pending.flatMap((p) =>
    p.tokens.map(async (token) => {
      const res = await fetch(url, {
        method: 'POST',
        headers: { Authorization: auth, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: p.title, body: p.body },
            data: { kind: p.kind },
          },
        }),
      });
      // Uygulama silinmiş ya da token yenilenmiş.
      if (res.status === 404) dead.push(token);
      else if (!res.ok) console.error(token, await res.text());
    })
  ));
  if (dead.length) await db.from('push_tokens').delete().in('token', dead);
  return new Response('ok');
});
