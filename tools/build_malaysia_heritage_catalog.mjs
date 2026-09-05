import { writeFile } from 'node:fs/promises';

const endpoints = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
];

const query = `[out:json][timeout:180];
area["ISO3166-1"="MY"][admin_level=2]->.malaysia;
(
  nwr(area.malaysia)["name"]["heritage"];
  nwr(area.malaysia)["name"]["historic"];
  nwr(area.malaysia)["name"]["tourism"~"^(museum|gallery|artwork)$"];
  nwr(area.malaysia)["name"]["amenity"="place_of_worship"]["historic"];
  nwr(area.malaysia)["name"]["boundary"~"^(national_park|protected_area)$"]["heritage"];
);
out tags center qt;`;

let payload;
for (const endpoint of endpoints) {
  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'User-Agent': 'FindItMy/1.0 heritage catalogue builder',
      },
      body: new URLSearchParams({ data: query }),
      signal: AbortSignal.timeout(210_000),
    });
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    payload = await response.json();
    break;
  } catch (error) {
    console.warn(`${endpoint}: ${error.message}`);
  }
}
if (!payload?.elements) throw new Error('All Overpass endpoints failed.');

const clean = value => String(value ?? '').replaceAll('\0', '').trim();
const categoryFor = tags => {
  const historic = clean(tags.historic).toLowerCase();
  const tourism = clean(tags.tourism).toLowerCase();
  const heritage = clean(tags.heritage).toLowerCase();
  if (['archaeological_site', 'ruins'].includes(historic)) return 'Archaeological Site';
  if (tags.amenity === 'place_of_worship' || ['wayside_shrine', 'religious'].includes(historic)) return 'Temple & Sacred';
  if (tourism === 'museum') return 'Museum';
  if (tags.boundary === 'national_park' || tags.boundary === 'protected_area' || tags.natural) return 'Natural Heritage';
  if (tourism === 'gallery' || tourism === 'artwork') return 'Cultural Heritage';
  if (heritage || ['building', 'monument', 'memorial', 'castle', 'fort'].includes(historic)) return 'Historical Monument';
  return 'Traditional Heritage Site';
};
const addressFor = tags => [
  tags['addr:housenumber'], tags['addr:street'], tags['addr:place'],
  tags['addr:city'] || tags['addr:town'], tags['addr:state'], tags['addr:postcode'],
].map(clean).filter(Boolean).filter((v, i, a) => a.indexOf(v) === i).join(', ');
const sqlLiteral = value => `'${clean(value).replaceAll("'", "''")}'`;
const jsonLiteral = value => `${sqlLiteral(JSON.stringify(value))}::jsonb`;

const seen = new Set();
const rows = [];
for (const element of payload.elements) {
  const tags = element.tags ?? {};
  const name = clean(tags.name || tags['name:en']);
  const point = element.type === 'node' ? element : element.center;
  if (!name || !Number.isFinite(point?.lat) || !Number.isFinite(point?.lon)) continue;
  if (point.lat < 0.8 || point.lat > 7.6 || point.lon < 99.5 || point.lon > 119.5) continue;
  const osmId = `${element.type}/${element.id}`;
  if (seen.has(osmId)) continue;
  seen.add(osmId);
  const usefulTags = Object.fromEntries(Object.entries(tags)
    .filter(([key, value]) => typeof value === 'string' && [
      'heritage', 'historic', 'tourism', 'amenity', 'religion', 'denomination',
      'building', 'architect', 'start_date', 'wikidata', 'wikipedia', 'website',
      'opening_hours', 'boundary', 'natural', 'protect_class',
    ].includes(key)));
  rows.push({
    osmId, name, category: categoryFor(tags), state: clean(tags['addr:state']),
    address: addressFor(tags), description: clean(tags.description || tags['description:en']),
    latitude: point.lat, longitude: point.lon, openingHours: clean(tags.opening_hours),
    tags: usefulTags,
  });
}
rows.sort((a, b) => a.name.localeCompare(b.name) || a.osmId.localeCompare(b.osmId));

const values = rows.map(row => `(${[
  sqlLiteral(row.osmId), sqlLiteral(row.name), sqlLiteral(row.category),
  sqlLiteral(row.state || 'Malaysia'), sqlLiteral(row.address), sqlLiteral(row.description),
  row.latitude, row.longitude, sqlLiteral(row.openingHours), jsonLiteral(row.tags),
].join(',')})`).join(',\n');
const sql = `-- Generated from named Malaysian OSM heritage records.\n` +
`insert into public.heritage_locations\n` +
`(osm_id,name,category,state,address,description,latitude,longitude,opening_hours,osm_tags) values\n${values}\n` +
`on conflict(osm_id) do update set name=excluded.name,category=excluded.category,state=excluded.state,address=excluded.address,description=excluded.description,latitude=excluded.latitude,longitude=excluded.longitude,opening_hours=excluded.opening_hours,osm_tags=excluded.osm_tags,source_updated_at=now(),updated_at=now();\n`;
await writeFile('supabase/generated_malaysia_heritage_catalog.sql', sql, 'utf8');
const csvCell = value => `"${String(value ?? '').replaceAll('"', '""')}"`;
const csv = [
  ['osm_id','name','category','state','address','description','latitude','longitude','opening_hours','osm_tags','is_verified','is_active'].join(','),
  ...rows.map(row => [
    row.osmId, row.name, row.category, row.state || 'Malaysia', row.address,
    row.description, row.latitude, row.longitude, row.openingHours,
    JSON.stringify(row.tags), true, true,
  ].map(csvCell).join(',')),
].join('\n');
await writeFile('supabase/generated_malaysia_heritage_catalog.csv', csv, 'utf8');
console.log(JSON.stringify({ records: rows.length, categories: Object.fromEntries(Object.entries(rows.reduce((a, r) => ((a[r.category] = (a[r.category] ?? 0) + 1), a), {})).sort()) }, null, 2));
