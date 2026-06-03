import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const SB_URL  = 'https://ygrkcynyduuflzvbkkvo.supabase.co';
const SB_ANON = 'sb_publishable_-aRakEBT-U17VQJHksmK1Q_TbL1cToK';

const TEST_EMAIL    = __ENV.TEST_EMAIL    || 'dominskipatryk@gmail.com';
const TEST_PASSWORD = __ENV.TEST_PASSWORD || '';

const errRate   = new Rate('error_rate');
const authTime  = new Trend('auth_duration_ms');
const queryTime = new Trend('query_duration_ms');

export const options = {
  stages: [
    { duration: '10s', target: 10 },
    { duration: '20s', target: 50 },
    { duration: '30s', target: 50 },
    { duration: '10s', target: 0  },
  ],
  thresholds: {
    error_rate:        ['rate<0.05'],
    http_req_duration: ['p(95)<2000'],
    auth_duration_ms:  ['p(95)<3000'],
    query_duration_ms: ['p(95)<500'],
  },
};

// Logowanie raz przed startem — token przekazywany do wszystkich VU
export function setup() {
  const start = Date.now();
  const res = http.post(
    `${SB_URL}/auth/v1/token?grant_type=password`,
    JSON.stringify({ email: TEST_EMAIL, password: TEST_PASSWORD }),
    { headers: { 'apikey': SB_ANON, 'Content-Type': 'application/json' } }
  );
  authTime.add(Date.now() - start);
  if (res.status !== 200) {
    console.error(`Login failed: ${res.status} — ${res.body}`);
    return { token: null };
  }
  console.log(`Login OK — token obtained in ${Date.now() - start}ms`);
  return { token: res.json('access_token') };
}

export default function (data) {
  if (!data.token) { errRate.add(1); return; }

  const headers = {
    'apikey':        SB_ANON,
    'Authorization': `Bearer ${data.token}`,
    'Content-Type':  'application/json',
  };

  group('odczyt danych (sync-down)', () => {
    const start = Date.now();

    const r1 = http.get(`${SB_URL}/rest/v1/trades?select=id,symbol,status,pnl&limit=50&order=updated_at.desc`, { headers });
    if (r1.status !== 200 && __VU === 1 && __ITER === 0) {
      console.error(`Trades error ${r1.status}: ${r1.body?.substring(0, 200)}`);
    }
    check(r1, { 'trades 200': r => r.status === 200 });
    errRate.add(r1.status !== 200);

    const r2 = http.get(`${SB_URL}/rest/v1/accounts?select=id,name,currency,capital`, { headers });
    check(r2, { 'accounts 200': r => r.status === 200 });
    errRate.add(r2.status !== 200);

    const r3 = http.get(`${SB_URL}/rest/v1/analyses?select=id,title,symbol&limit=20`, { headers });
    check(r3, { 'analyses 200': r => r.status === 200 });
    errRate.add(r3.status !== 200);

    const r4 = http.get(`${SB_URL}/rest/v1/user_settings?select=key,value`, { headers });
    check(r4, { 'settings 200': r => r.status === 200 });
    errRate.add(r4.status !== 200);

    queryTime.add(Date.now() - start);
  });

  sleep(1);
}
