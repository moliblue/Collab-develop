import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    concurrent_planners: {
      executor: 'ramping-vus',
      stages: [
        { duration: '20s', target: 5 },
        { duration: '40s', target: 10 },
        { duration: '20s', target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1500'],
    checks: ['rate>0.99'],
  },
};

const baseUrl = __ENV.SUPABASE_URL;
const publishableKey = __ENV.SUPABASE_ANON_KEY;

function uuid() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (char) => {
    const value = Math.floor(Math.random() * 16);
    return (char === 'x' ? value : (value & 0x3) | 0x8).toString(16);
  });
}

function headers(token, prefer = 'return=minimal') {
  return {
    apikey: publishableKey,
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
    Prefer: prefer,
  };
}

export default function () {
  if (!baseUrl || !publishableKey) {
    throw new Error('Set SUPABASE_URL and SUPABASE_ANON_KEY first.');
  }

  const auth = http.post(
    `${baseUrl}/auth/v1/signup`,
    '{}',
    { headers: headers(publishableKey) },
  );
  check(auth, { 'anonymous sign-in succeeds': (r) => r.status === 200 });
  if (auth.status !== 200) return;

  const session = auth.json();
  const token = session.access_token;
  const userId = session.user.id;
  const planId = uuid();
  const dayId = uuid();
  const cardId = uuid();
  const inviteCode = `LOAD-${planId.substring(0, 8)}`;

  const plan = http.post(
    `${baseUrl}/rest/v1/travel_plans`,
    JSON.stringify({
      id: planId,
      owner_id: userId,
      name: `Load test ${planId.substring(0, 6)}`,
      start_date: '2026-09-10',
      end_date: '2026-09-10',
      invite_code: inviteCode,
      revision: 0,
    }),
    { headers: headers(token) },
  );
  check(plan, { 'plan create succeeds': (r) => r.status === 201 });

  const day = http.post(
    `${baseUrl}/rest/v1/plan_days`,
    JSON.stringify({ id: dayId, plan_id: planId, date: '2026-09-10', position: 0 }),
    { headers: headers(token) },
  );
  check(day, { 'day create succeeds': (r) => r.status === 201 });

  const card = http.post(
    `${baseUrl}/rest/v1/itinerary_cards`,
    JSON.stringify({
      id: cardId,
      day_id: dayId,
      title: 'Batu Caves',
      location: 'Batu Caves, Selangor, Malaysia',
      start_time: '09:00:00',
      category: 'Traditional Heritage Site',
      latitude: 3.2379,
      longitude: 101.684,
      position: 0,
    }),
    { headers: headers(token) },
  );
  check(card, { 'card create succeeds': (r) => r.status === 201 });

  const read = http.get(
    `${baseUrl}/rest/v1/itinerary_cards?select=*&id=eq.${cardId}`,
    { headers: headers(token) },
  );
  check(read, { 'card read succeeds': (r) => r.status === 200 && r.json().length === 1 });

  const update = http.patch(
    `${baseUrl}/rest/v1/itinerary_cards?id=eq.${cardId}`,
    JSON.stringify({ title: 'Updated Batu Caves' }),
    { headers: headers(token) },
  );
  check(update, { 'card update succeeds': (r) => r.status === 204 });

  const remove = http.del(
    `${baseUrl}/rest/v1/travel_plans?id=eq.${planId}`,
    null,
    { headers: headers(token) },
  );
  check(remove, { 'cascade delete succeeds': (r) => r.status === 204 });
  sleep(1);
}
