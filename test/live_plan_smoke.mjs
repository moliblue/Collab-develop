const baseUrl = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_ANON_KEY;

if (!baseUrl || !key) throw new Error('Missing SUPABASE_URL or SUPABASE_ANON_KEY');

async function request(path, { token = key, method = 'GET', body, prefer } = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      apikey: key,
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...(prefer ? { Prefer: prefer } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) throw new Error(`${method} ${path}: ${response.status} ${text}`);
  return data;
}

async function anonymousUser() {
  const auth = await request('/auth/v1/signup', { method: 'POST', body: {} });
  if (!auth.access_token || !auth.user?.id) throw new Error('Anonymous sign-in failed');
  return { token: auth.access_token, id: auth.user.id };
}

const owner = await anonymousUser();
const member = await anonymousUser();
const outsider = await anonymousUser();
const ownerClaims = JSON.parse(Buffer.from(owner.token.split('.')[1], 'base64url'));
if (ownerClaims.sub !== owner.id || ownerClaims.role !== 'authenticated') {
  throw new Error(`Unexpected auth claims: ${JSON.stringify({ sub: ownerClaims.sub, role: ownerClaims.role })}`);
}
const suffix = crypto.randomUUID().replaceAll('-', '').slice(0, 10).toUpperCase();
let planId;

try {
  const [plan] = await request('/rest/v1/travel_plans', {
    token: owner.token,
    method: 'POST',
    prefer: 'return=representation',
    body: {
      owner_id: owner.id,
      name: `Codex Plan Smoke ${suffix}`,
      start_date: '2026-09-10',
      end_date: '2026-09-10',
      invite_code: `CDX-${suffix}`,
      revision: 0,
    },
  });
  planId = plan.id;

  const [day] = await request('/rest/v1/plan_days', {
    token: owner.token,
    method: 'POST',
    prefer: 'return=representation',
    body: { plan_id: planId, date: '2026-09-10', position: 0 },
  });

  const [card] = await request('/rest/v1/itinerary_cards', {
    token: owner.token,
    method: 'POST',
    prefer: 'return=representation',
    body: {
      day_id: day.id,
      title: 'Batu Caves smoke test',
      location: 'Batu Caves, Selangor, Malaysia',
      start_time: '09:00:00',
      category: 'Traditional Heritage Site',
      description: 'Temporary automated test record',
      latitude: 3.2379,
      longitude: 101.684,
      position: 0,
    },
  });

  const joinedPlanId = await request('/rest/v1/rpc/join_travel_plan', {
    token: member.token,
    method: 'POST',
    body: { invite_pin: `CDX-${suffix}` },
  });
  if (joinedPlanId !== planId) throw new Error('Join returned the wrong plan');

  const memberRows = await request(`/rest/v1/itinerary_cards?id=eq.${card.id}&select=id,title`, {
    token: member.token,
  });
  if (memberRows.length !== 1) throw new Error('Joined member could not read the card');

  const outsiderRows = await request(`/rest/v1/travel_plans?id=eq.${planId}&select=id`, {
    token: outsider.token,
  });
  if (outsiderRows.length !== 0) throw new Error('RLS exposed the plan to an outsider');

  const nextRevision = await request('/rest/v1/rpc/claim_plan_revision', {
    token: owner.token,
    method: 'POST',
    body: { target_plan: planId, expected_revision: 0 },
  });
  if (nextRevision !== 1) throw new Error(`Expected revision 1, received ${nextRevision}`);

  const staleRevision = await request('/rest/v1/rpc/claim_plan_revision', {
    token: member.token,
    method: 'POST',
    body: { target_plan: planId, expected_revision: 0 },
  });
  if (staleRevision !== null) throw new Error('Stale update was not rejected');

  await request(`/rest/v1/itinerary_cards?id=eq.${card.id}`, {
    token: member.token,
    method: 'PATCH',
    prefer: 'return=minimal',
    body: { title: 'Updated by joined member' },
  });

  console.log('PASS: Plan create/read/update/join/RLS/concurrency checks succeeded.');
} finally {
  if (planId) {
    await request(`/rest/v1/travel_plans?id=eq.${planId}`, {
      token: owner.token,
      method: 'DELETE',
      prefer: 'return=minimal',
    });
  }
}
