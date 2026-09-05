const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, options);
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`${response.status} ${url}: ${text.slice(0, 300)}`);
  }
  return text ? JSON.parse(text) : null;
}

const nominatim = await fetchJson(
  'https://nominatim.openstreetmap.org/search?' +
    new URLSearchParams({
      q: 'Batu Caves, Selangor, Malaysia',
      format: 'jsonv2',
      addressdetails: '1',
      countrycodes: 'my',
      limit: '5',
    }),
  { headers: { 'User-Agent': 'FindItMy/1.0 API smoke test' } },
);
assert(Array.isArray(nominatim) && nominatim.length > 0, 'Nominatim returned no Malaysian location');
assert(nominatim.every((item) => item.address?.country_code === 'my'), 'Nominatim escaped Malaysia filter');

const overpassQuery = `[out:json][timeout:18];
(
  nwr(around:3000,3.1390,101.6869)["historic"];
  nwr(around:3000,3.1390,101.6869)["heritage"];
  nwr(around:3000,3.1390,101.6869)["tourism"~"^(museum|gallery|attraction|artwork)$"];
);
out tags center qt;`;
const overpassEndpoints = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
];
let overpass;
let overpassEndpoint;
for (const endpoint of overpassEndpoints) {
  try {
    overpass = await fetchJson(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'User-Agent': 'FindItMy/1.0 API smoke test',
      },
      body: new URLSearchParams({ data: overpassQuery }),
    });
    overpassEndpoint = endpoint;
    break;
  } catch (error) {
    console.warn(`Overpass fallback: ${error.message}`);
  }
}
assert(Array.isArray(overpass?.elements), 'All Overpass endpoints failed');

const osrm = await fetchJson(
  'https://router.project-osrm.org/route/v1/driving/' +
    '101.6840,3.2379;101.6869,3.1390?' +
    new URLSearchParams({ overview: 'full', geometries: 'geojson', steps: 'false' }),
);
assert(osrm.code === 'Ok' && osrm.routes?.length > 0, 'OSRM returned no route');
assert(osrm.routes[0].distance > 0 && osrm.routes[0].duration > 0, 'OSRM route metrics are invalid');
assert(osrm.routes[0].geometry?.coordinates?.length > 1, 'OSRM route geometry is missing');

if (supabaseUrl && supabaseKey) {
  const auth = await fetchJson(`${supabaseUrl}/auth/v1/signup`, {
    method: 'POST',
    headers: { apikey: supabaseKey, 'Content-Type': 'application/json' },
    body: '{}',
  });
  const headers = {
    apikey: supabaseKey,
    Authorization: `Bearer ${auth.access_token}`,
    'Content-Type': 'application/json',
  };
  const completions = await fetchJson(
    `${supabaseUrl}/rest/v1/quest_completions?select=id,photo_path&user_id=eq.${auth.user.id}&limit=1`,
    { headers },
  );
  assert(Array.isArray(completions), 'Supabase quest completion read failed');

  const bucketResponse = await fetch(`${supabaseUrl}/storage/v1/object/list/quest-photos`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ prefix: `${auth.user.id}/`, limit: 1, offset: 0 }),
  });
  assert(bucketResponse.ok, `Supabase quest-photos bucket is unavailable (${bucketResponse.status})`);

  const testPath = `${auth.user.id}/codex-map-smoke-${crypto.randomUUID()}.png`;
  const objectUrl = `${supabaseUrl}/storage/v1/object/quest-photos/${testPath}`;
  const downloadUrl = `${supabaseUrl}/storage/v1/object/authenticated/quest-photos/${testPath}`;
  const onePixelPng = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    'base64',
  );
  try {
    const upload = await fetch(objectUrl, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'image/png', 'x-upsert': 'false' },
      body: onePixelPng,
    });
    assert(upload.ok, `Supabase quest photo upload failed (${upload.status}: ${await upload.text()})`);

    const download = await fetch(downloadUrl, { headers });
    assert(download.ok, `Supabase quest photo read failed (${download.status})`);
    assert((await download.arrayBuffer()).byteLength > 0, 'Downloaded quest photo is empty');
  } finally {
    const cleanup = await fetch(`${supabaseUrl}/storage/v1/object/quest-photos`, {
      method: 'DELETE',
      headers,
      body: JSON.stringify({ prefixes: [testPath] }),
    });
    assert(cleanup.ok || cleanup.status === 404, `Supabase quest photo cleanup failed (${cleanup.status})`);
  }
}

console.log(JSON.stringify({
  status: 'PASS',
  nominatimResults: nominatim.length,
  overpassEndpoint,
  overpassElements: overpass.elements.length,
  osrmDistanceMeters: osrm.routes[0].distance,
  osrmDurationSeconds: osrm.routes[0].duration,
  supabaseMapReadContracts: Boolean(supabaseUrl && supabaseKey),
  supabasePhotoCreateReadDelete: Boolean(supabaseUrl && supabaseKey),
}));
