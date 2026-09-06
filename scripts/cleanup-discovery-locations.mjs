import { mkdir, readFile, writeFile } from 'node:fs/promises';

const modeAudit = process.argv.includes('--audit');
const modeApply = process.argv.includes('--apply');
const modeBackup = process.argv.includes('--backup-only');
if ([modeAudit, modeApply, modeBackup].filter(Boolean).length !== 1) {
  throw new Error('Choose exactly one mode: --audit, --backup-only, or --apply.');
}

const required = (name) => {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
};
const supabaseUrl = required('SUPABASE_URL').replace(/\/$/, '');
const serviceRoleKey = required('SUPABASE_SERVICE_ROLE_KEY');
const googlePlacesApiKey = modeApply ? required('GOOGLE_PLACES_API_KEY') : '';
const headers = {
  apikey: serviceRoleKey,
  Authorization: `Bearer ${serviceRoleKey}`,
  'Content-Type': 'application/json',
};
const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function fetchWithRetry(url, options = {}, attempts = 5) {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    let response;
    try {
      response = await fetch(url, {
        ...options,
        signal: options.signal ?? AbortSignal.timeout(30000),
      });
    } catch (error) {
      if (attempt === attempts - 1) throw error;
      await sleep(500 * 2 ** attempt);
      continue;
    }
    if (response.ok) return response;
    const detail = (await response.text()).slice(0, 800);
    if ((response.status !== 429 && response.status < 500) || attempt === attempts - 1) {
      throw new Error(`${response.status} ${response.statusText}: ${detail}`);
    }
    await sleep(500 * 2 ** attempt);
  }
  throw new Error('Retry limit reached.');
}

const CANONICAL_REGIONS = [
  'Johor', 'Kedah', 'Kelantan', 'Melaka', 'Negeri Sembilan', 'Pahang',
  'Penang', 'Perak', 'Perlis', 'Sabah', 'Sarawak', 'Selangor',
  'Terengganu', 'Kuala Lumpur', 'Putrajaya', 'Labuan',
];
const CANONICAL_CATEGORIES = [
  'Cultural Heritage',
  'Museum',
  'Historical Monument',
  'Traditional Heritage Site',
  'Natural Heritage',
];

async function readAll(table, select, order = '') {
  const rows = [];
  const pageSize = 500;
  for (let offset = 0; ; offset += pageSize) {
    const params = new URLSearchParams({ select, limit: String(pageSize), offset: String(offset) });
    if (order) params.set('order', order);
    const response = await fetchWithRetry(`${supabaseUrl}/rest/v1/${table}?${params}`, { headers });
    if (!response.ok) throw new Error(`${table} read failed (${response.status}): ${await response.text()}`);
    const page = await response.json();
    rows.push(...page);
    if (page.length < pageSize) return rows;
  }
}

const blank = (value) => value == null ||
  (typeof value === 'string' && value.trim() === '') ||
  (Array.isArray(value) && value.length === 0) ||
  (typeof value === 'object' && !Array.isArray(value) && Object.keys(value).length === 0);
const normalize = (value) => String(value ?? '')
  .normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
  .toLowerCase().replace(/&/g, ' and ').replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
const words = (value) => normalize(value).split(' ').filter((word) => word.length > 2);
const similarity = (left, right) => {
  const a = new Set(words(left));
  const b = new Set(words(right));
  if (a.size === 0 || b.size === 0) return 0;
  const intersection = [...a].filter((word) => b.has(word)).length;
  return intersection / Math.max(a.size, b.size);
};
const distanceMeters = (a, b) => {
  const radians = (value) => value * Math.PI / 180;
  const dLat = radians(Number(b.latitude) - Number(a.latitude));
  const dLon = radians(Number(b.longitude) - Number(a.longitude));
  const x = Math.sin(dLat / 2) ** 2 +
    Math.cos(radians(Number(a.latitude))) * Math.cos(radians(Number(b.latitude))) *
    Math.sin(dLon / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
};
const countBy = (rows, value) => Object.fromEntries(
  [...rows.reduce((map, row) => {
    const key = value(row) || '(blank)';
    map.set(key, (map.get(key) ?? 0) + 1);
    return map;
  }, new Map())].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])),
);
const osmType = (id) => String(id).split(/[/:]/)[0] || 'unknown';
const structuredRegion = (row) => {
  const tags = row.osm_tags ?? {};
  const candidates = [tags['addr:state'], tags['is_in:state'], tags['is_in']];
  return candidates.map((value) => String(value ?? '').trim())
    .find((value) => CANONICAL_REGIONS.includes(value)) ?? null;
};

function proposedCategory(row) {
  const current = String(row.category ?? '').trim();
  if (CANONICAL_CATEGORIES.includes(current)) return current;
  const tags = row.osm_tags ?? {};
  const text = normalize([
    row.name, row.description,
    ...Object.entries(tags).flat(),
  ].join(' '));
  if (current === 'Archaeological Site') {
    if (/traditional|settlement|kampung|longhouse/.test(text)) {
      return 'Traditional Heritage Site';
    }
    return 'Historical Monument';
  }
  if (current === 'Temple & Sacred') {
    return tags.historic || tags.heritage
      ? 'Traditional Heritage Site'
      : 'Cultural Heritage';
  }
  return 'Cultural Heritage';
}

function completenessScore(row, imageCount) {
  return [
    row.name, row.state, row.address, row.description, row.opening_hours,
    row.google_place_id, row.formatted_address, row.google_maps_uri,
  ].filter((value) => !blank(value)).length +
    Object.keys(row.osm_tags ?? {}).length / 20 + Math.min(imageCount, 1) * 2;
}

function suspiciousAddress(row) {
  const address = String(row.address ?? '').trim();
  const normalized = normalize(address);
  const normalizedName = normalize(row.name);
  if (!address) return 'blank';
  if (normalized === 'malaysia') return 'country_only';
  if (normalized === normalizedName) return 'name_only';
  if (normalized === `${normalizedName} malaysia`) return 'name_country_only';
  if (/\bmalaysia\s*[, ]+\s*malaysia\b/i.test(address)) return 'duplicated_country';
  if (normalize(row.state) && normalized === normalize(row.state)) return 'state_only';
  if (/^[,;|\-\s]+$/.test(address) || /(^|[, ])undefined|null($|[, ])/i.test(address)) {
    return 'malformed';
  }
  return null;
}

await mkdir('reports', { recursive: true });
const locations = await readAll('heritage_locations', '*', 'osm_id.asc');
const images = await readAll(
  'destination_images',
  'id,destination_id,source,match_status,is_cover,display_order',
  'destination_id.asc,display_order.asc',
);
const imagesByDestination = images.reduce((map, image) => {
  const group = map.get(image.destination_id) ?? [];
  group.push(image);
  map.set(image.destination_id, group);
  return map;
}, new Map());

const fields = [
  'name', 'state', 'address', 'description', 'latitude', 'longitude',
  'opening_hours', 'google_place_id', 'google_place_name', 'google_match_status',
  'formatted_address', 'opening_hours_weekday_text', 'opening_hours_periods',
  'google_maps_uri',
];
const missing = Object.fromEntries(fields.map((field) => [
  field,
  locations.filter((row) => blank(row[field])).length,
]));
const stateDistribution = countBy(locations, (row) => String(row.state ?? '').trim());
const categoryDistribution = countBy(locations, (row) => String(row.category ?? '').trim());
const invalidStateRows = locations.filter((row) =>
  !blank(row.state) && !CANONICAL_REGIONS.includes(String(row.state).trim()));
const coordinateIssues = locations.filter((row) => {
  const latitude = Number(row.latitude);
  const longitude = Number(row.longitude);
  return !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
    latitude < 0.75 || latitude > 7.6 || longitude < 99.4 || longitude > 119.5;
});
const suspiciousAddresses = locations.map((row) => ({ row, issue: suspiciousAddress(row) }))
  .filter((entry) => entry.issue);

const nameGroups = new Map();
for (const row of locations) {
  const key = normalize(row.name);
  const group = nameGroups.get(key) ?? [];
  group.push(row);
  nameGroups.set(key, group);
}
const duplicateNameGroups = [...nameGroups.entries()].filter(([, rows]) => rows.length > 1);
const duplicateCandidates = [];
for (const [normalizedName, rows] of duplicateNameGroups) {
  const pairs = [];
  for (let i = 0; i < rows.length; i += 1) {
    for (let j = i + 1; j < rows.length; j += 1) {
      const left = rows[i];
      const right = rows[j];
      const distance = distanceMeters(left, right);
      const sameGooglePlace = Boolean(left.google_place_id) &&
        left.google_place_id === right.google_place_id;
      const addressSimilarity = similarity(left.address, right.address);
      const categoryCompatible = proposedCategory(left) === proposedCategory(right);
      let classification = 'C_ambiguous_manual_review';
      const reasons = [];
      if (sameGooglePlace) reasons.push('same_google_place_id');
      if (distance <= 30) reasons.push('same_name_within_30m');
      if (addressSimilarity >= 0.6) reasons.push('strong_address_similarity');
      if (osmType(left.osm_id) !== osmType(right.osm_id)) reasons.push('different_osm_object_types');
      if (sameGooglePlace || (distance <= 30 && categoryCompatible)) {
        classification = 'A_probable_same_poi';
      } else if (distance > 1000) {
        classification = 'B_same_name_different_places';
      }
      const ranked = [left, right].sort((a, b) =>
        completenessScore(b, imagesByDestination.get(b.osm_id)?.length ?? 0) -
        completenessScore(a, imagesByDestination.get(a.osm_id)?.length ?? 0));
      pairs.push({
        left_id: left.osm_id,
        right_id: right.osm_id,
        distance_m: Math.round(distance * 10) / 10,
        classification,
        reasons,
        proposed_canonical_id: ranked[0].osm_id,
        fields_to_preserve: {
          name: ranked.find((row) => !blank(row.name))?.name ?? null,
          coordinates_from: ranked[0].osm_id,
          richer_osm_tags_from: [...ranked].sort((a, b) =>
            Object.keys(b.osm_tags ?? {}).length - Object.keys(a.osm_tags ?? {}).length)[0].osm_id,
          google_metadata_from: ranked.find((row) => !blank(row.google_place_id))?.osm_id ?? null,
          formatted_address_from: ranked.find((row) => !blank(row.formatted_address))?.osm_id ?? null,
          description_from: ranked.find((row) => !blank(row.description))?.osm_id ?? null,
        },
        image_rows: {
          [left.osm_id]: imagesByDestination.get(left.osm_id)?.length ?? 0,
          [right.osm_id]: imagesByDestination.get(right.osm_id)?.length ?? 0,
        },
        foreign_key_note: 'destination_images.destination_id must be reassigned before any duplicate deletion',
      });
    }
  }
  duplicateCandidates.push({ normalized_name: normalizedName, names: [...new Set(rows.map((r) => r.name))], pairs });
}

const categoryTransitions = countBy(locations, (row) =>
  `${row.category || '(blank)'} -> ${proposedCategory(row)}`);
const googleMatched = locations.filter((row) =>
  !blank(row.google_place_id) && ['exact', 'high_confidence', 'nearby'].includes(row.google_match_status));
const googleNameInconsistent = locations.filter((row) =>
  !blank(row.google_place_id) && !blank(row.google_place_name) &&
  similarity(row.name, row.google_place_name) < 0.4);
const missingImages = locations.filter((row) => !imagesByDestination.has(row.osm_id));
const stateEvidence = countBy(locations, (row) => {
  if (CANONICAL_REGIONS.includes(String(row.state ?? '').trim())) return 'existing_canonical_state';
  if (structuredRegion(row)) return 'structured_osm_state';
  return 'coordinate_boundary_lookup_required';
});
const descriptionEvidence = countBy(locations.filter((row) => blank(row.description)), (row) => {
  const tags = row.osm_tags ?? {};
  if (tags.description || tags.wikipedia || tags.wikidata || tags.heritage) return 'structured_source_available';
  return 'neutral_structured_summary_or_unavailable';
});

const hardCases = [
  'Bull And Bear', 'The Light Forest', 'Jimmy Choo', 'Eagle', 'Batu Belah',
  'Sandakan Death March',
].map((name) => {
  const row = locations.find((entry) => normalize(entry.name) === normalize(name));
  if (!row) return { name, found: false };
  const tags = row.osm_tags ?? {};
  const locality = tags['addr:city'] || tags['addr:town'] || tags['addr:village'] || tags['addr:suburb'] || '';
  const cleanedContext = [row.name, row.address, locality, row.state, row.category]
    .map((value) => String(value ?? '').replace(/\bmalaysia\b/gi, ' ').replace(/[,|]+/g, ' ').replace(/\s+/g, ' ').trim())
    .filter(Boolean);
  const seenContext = new Set();
  const context = cleanedContext.filter((value) => {
    const key = normalize(value);
    if (seenContext.has(key) || key === normalize(row.name) && seenContext.size > 0) return false;
    seenContext.add(key);
    return true;
  });
  context.push('Malaysia');
  return {
    name: row.name,
    osm_id: row.osm_id,
    latitude: row.latitude,
    longitude: row.longitude,
    contextual_query: context.join(', '),
    coordinate_restriction: { radius_m: 1000, latitude: row.latitude, longitude: row.longitude },
  };
});

const CACHE_DIRECTORY = 'reports/discovery-cleanup-cache';
const GOOGLE_CACHE_PATH = `${CACHE_DIRECTORY}/google-enrichment-cache.json`;
const BOUNDARY_PATH = `${CACHE_DIRECTORY}/malaysia-adm1.geojson`;
const GOOGLE_DETAILS_FIELDS = [
  'id', 'displayName', 'formattedAddress', 'addressComponents', 'location',
  'primaryType', 'types', 'regularOpeningHours', 'currentOpeningHours',
  'googleMapsUri',
].join(',');

async function readJsonOr(path, fallback) {
  try {
    return JSON.parse(await readFile(path, 'utf8'));
  } catch (error) {
    if (error?.code === 'ENOENT') return fallback;
    throw error;
  }
}

async function writeGoogleCache(cache) {
  for (let attempt = 0; attempt < 4; attempt += 1) {
    try {
      await writeFile(GOOGLE_CACHE_PATH, `${JSON.stringify(cache, null, 2)}\n`);
      return;
    } catch (error) {
      if (attempt === 3) throw error;
      await sleep(250 * 2 ** attempt);
    }
  }
}

function canonicalRegion(value) {
  const normalized = normalize(value);
  const aliases = {
    malacca: 'Melaka',
    melaka: 'Melaka',
    'pulau pinang': 'Penang',
    penang: 'Penang',
    'wilayah persekutuan kuala lumpur': 'Kuala Lumpur',
    'federal territory of kuala lumpur': 'Kuala Lumpur',
    'wilayah persekutuan putrajaya': 'Putrajaya',
    'federal territory of putrajaya': 'Putrajaya',
    'wilayah persekutuan labuan': 'Labuan',
    'federal territory of labuan': 'Labuan',
  };
  if (aliases[normalized]) return aliases[normalized];
  return CANONICAL_REGIONS.find((region) => normalize(region) === normalized) ?? null;
}

function pointInRing(longitude, latitude, ring) {
  let inside = false;
  for (let current = 0, previous = ring.length - 1; current < ring.length; previous = current++) {
    const [currentX, currentY] = ring[current];
    const [previousX, previousY] = ring[previous];
    const crosses = (currentY > latitude) !== (previousY > latitude) &&
      longitude < ((previousX - currentX) * (latitude - currentY)) /
        (previousY - currentY || Number.EPSILON) + currentX;
    if (crosses) inside = !inside;
  }
  return inside;
}

function pointInPolygon(longitude, latitude, polygon) {
  if (!pointInRing(longitude, latitude, polygon[0])) return false;
  return polygon.slice(1).every((hole) => !pointInRing(longitude, latitude, hole));
}

function boundaryRegion(row, boundaryFeatures) {
  const longitude = Number(row.longitude);
  const latitude = Number(row.latitude);
  if (!Number.isFinite(longitude) || !Number.isFinite(latitude)) return null;
  for (const feature of boundaryFeatures) {
    const geometry = feature.geometry;
    const polygons = geometry.type === 'Polygon'
      ? [geometry.coordinates]
      : geometry.type === 'MultiPolygon' ? geometry.coordinates : [];
    if (polygons.some((polygon) => pointInPolygon(longitude, latitude, polygon))) {
      return canonicalRegion(feature.properties?.shapeName);
    }
  }
  // Coastal artwork, wrecks and boundary markers can sit just outside a land
  // polygon. Resolve those to the nearest ADM1 boundary when it is still local.
  let nearest = null;
  for (const feature of boundaryFeatures) {
    const geometry = feature.geometry;
    const polygons = geometry.type === 'Polygon'
      ? [geometry.coordinates]
      : geometry.type === 'MultiPolygon' ? geometry.coordinates : [];
    for (const polygon of polygons) {
      for (const ring of polygon) {
        for (const [vertexLongitude, vertexLatitude] of ring) {
          const distance = distanceMeters(row, {
            latitude: vertexLatitude,
            longitude: vertexLongitude,
          });
          if (!nearest || distance < nearest.distance) {
            nearest = {
              distance,
              region: canonicalRegion(feature.properties?.shapeName),
            };
          }
        }
      }
    }
  }
  return nearest?.distance <= 50000 ? nearest.region : null;
}

function googleRegion(place) {
  const component = (place?.addressComponents ?? []).find((entry) =>
    (entry.types ?? []).includes('administrative_area_level_1'));
  return canonicalRegion(component?.longText ?? component?.shortText);
}

function googleCountryIsMalaysia(place) {
  const country = (place?.addressComponents ?? []).find((entry) =>
    (entry.types ?? []).includes('country'));
  if (!country) return true;
  return normalize(country.shortText) === 'my' || normalize(country.longText) === 'malaysia';
}

function categoryCompatible(row, place) {
  const types = new Set([place?.primaryType, ...(place?.types ?? [])].filter(Boolean));
  const category = proposedCategory(row);
  if (category === 'Museum') return types.has('museum');
  if (category === 'Natural Heritage') {
    return ['park', 'national_park', 'garden', 'hiking_area', 'tourist_attraction']
      .some((type) => types.has(type));
  }
  if (category === 'Traditional Heritage Site') {
    return ['hindu_temple', 'mosque', 'church', 'place_of_worship', 'museum',
      'historical_landmark', 'tourist_attraction'].some((type) => types.has(type));
  }
  return ['historical_landmark', 'monument', 'museum', 'tourist_attraction',
    'cultural_landmark', 'sculpture'].some((type) => types.has(type));
}

function classifyGoogleMatch(row, place) {
  const location = place?.location;
  const placeName = place?.displayName?.text?.trim();
  if (!placeName || !location || !googleCountryIsMalaysia(place)) return null;
  const distance = distanceMeters(row, {
    latitude: location.latitude,
    longitude: location.longitude,
  });
  const score = similarity(row.name, placeName);
  const exactName = normalize(row.name) === normalize(placeName);
  const compatible = categoryCompatible(row, place);
  const generic = words(row.name).length <= 1;
  let matchStatus = null;
  if (exactName && distance <= 500) matchStatus = 'exact';
  else if (!generic && compatible && score >= 0.6 && distance <= 1000) {
    matchStatus = 'high_confidence';
  } else if (!generic && compatible && score >= 0.45 && distance <= 250) {
    matchStatus = 'nearby';
  }
  if (!matchStatus) return null;
  return { place, placeName, distance, score, matchStatus };
}

async function googlePlaceDetails(placeId) {
  const response = await fetchWithRetry(
    `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`,
    {
      headers: {
        'X-Goog-Api-Key': googlePlacesApiKey,
        'X-Goog-FieldMask': GOOGLE_DETAILS_FIELDS,
      },
    },
  );
  await sleep(100);
  return response.json();
}

async function searchGooglePlace(row) {
  const tags = row.osm_tags ?? {};
  const locality = tags['addr:city'] || tags['addr:town'] || tags['addr:village'] ||
    tags['addr:suburb'] || '';
  const contexts = [
    [row.name, locality, row.state, proposedCategory(row), 'Malaysia'],
    [row.name, proposedCategory(row), row.state || 'Malaysia'],
  ];
  const queries = [...new Set(contexts.map((parts) => parts
    .map((value) => String(value ?? '').trim()).filter(Boolean).join(', ')))]
    .map((query) => query.replace(/(?:,\s*Malaysia){2,}$/i, ', Malaysia'));
  const candidates = [];
  for (const textQuery of queries) {
    const response = await fetchWithRetry(
      'https://places.googleapis.com/v1/places:searchText',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': googlePlacesApiKey,
          'X-Goog-FieldMask': `places.${GOOGLE_DETAILS_FIELDS.split(',').join(',places.')}`,
        },
        body: JSON.stringify({
          textQuery,
          pageSize: 5,
          languageCode: 'en',
          regionCode: 'MY',
          locationRestriction: {
            rectangle: {
              low: {
                latitude: Math.max(-90, Number(row.latitude) - 0.05),
                longitude: Math.max(-180, Number(row.longitude) - 0.05),
              },
              high: {
                latitude: Math.min(90, Number(row.latitude) + 0.05),
                longitude: Math.min(180, Number(row.longitude) + 0.05),
              },
            },
          },
        }),
      },
    );
    const places = (await response.json()).places ?? [];
    candidates.push(...places.map((place) => classifyGoogleMatch(row, place)).filter(Boolean));
    await sleep(100);
    if (candidates.some((candidate) => candidate.matchStatus === 'exact')) break;
  }
  const priority = { exact: 3, high_confidence: 2, nearby: 1 };
  return candidates.sort((left, right) =>
    priority[right.matchStatus] - priority[left.matchStatus] ||
    right.score - left.score || left.distance - right.distance)[0] ?? null;
}

function structuredOsmAddress(row, state) {
  const tags = row.osm_tags ?? {};
  const street = [tags['addr:housenumber'], tags['addr:street']]
    .filter(Boolean).join(' ').trim();
  const parts = [
    street,
    tags['addr:suburb'],
    tags['addr:city'] || tags['addr:town'] || tags['addr:village'],
    tags['addr:postcode'],
    state,
    'Malaysia',
  ].map((value) => String(value ?? '').trim()).filter(Boolean);
  const seen = new Set();
  return parts.filter((part) => {
    const key = normalize(part);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  }).join(', ');
}

function openingHoursPatch(place) {
  const regular = place?.regularOpeningHours ?? null;
  const current = place?.currentOpeningHours ?? null;
  const weekday = Array.isArray(regular?.weekdayDescriptions)
    ? regular.weekdayDescriptions.filter((value) => String(value).trim()) : [];
  const regularPeriods = Array.isArray(regular?.periods) ? regular.periods : [];
  const currentPeriods = Array.isArray(current?.periods) ? current.periods : [];
  if (weekday.length === 0 && regularPeriods.length === 0 && currentPeriods.length === 0) {
    return {};
  }
  return {
    opening_hours_weekday_text: weekday.length > 0 ? weekday : null,
    opening_hours_periods: {
      regular: regularPeriods,
      current: currentPeriods,
      currentWeekdayDescriptions: current?.weekdayDescriptions ?? [],
      currentOpenNow: typeof current?.openNow === 'boolean' ? current.openNow : null,
    },
    opening_hours_updated_at: new Date().toISOString(),
  };
}

async function patchLocation(osmId, patch) {
  if (Object.keys(patch).length === 0) return;
  const response = await fetchWithRetry(
    `${supabaseUrl}/rest/v1/heritage_locations?osm_id=eq.${encodeURIComponent(osmId)}`,
    {
      method: 'PATCH',
      headers: { ...headers, Prefer: 'return=minimal' },
      body: JSON.stringify(patch),
    },
  );
  await response.text();
}

function differentPatch(row, candidate) {
  return Object.fromEntries(Object.entries(candidate).filter(([key, value]) => {
    if (value === undefined) return false;
    return JSON.stringify(row[key] ?? null) !== JSON.stringify(value ?? null);
  }));
}

async function createFullBackup() {
  const backupDirectory = 'reports/backups';
  await mkdir(backupDirectory, { recursive: true });
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const [allImages, bookmarks, reviews] = await Promise.all([
    readAll('destination_images', '*', 'destination_id.asc,display_order.asc'),
    readAll('bookmarks', '*', 'destination_id.asc'),
    readAll('destination_reviews', '*', 'destination_id.asc'),
  ]);
  const backupPath = `${backupDirectory}/discovery-backup-${timestamp}.json`;
  await writeFile(backupPath, `${JSON.stringify({
    exported_at: new Date().toISOString(),
    scope: [
      'public.heritage_locations', 'public.destination_images',
      'public.bookmarks', 'public.destination_reviews',
    ],
    summary: {
      heritage_locations: locations.length,
      destination_images: allImages.length,
      bookmarks: bookmarks.length,
      destination_reviews: reviews.length,
    },
    heritage_locations: locations,
    destination_images: allImages,
    bookmarks,
    destination_reviews: reviews,
  }, null, 2)}\n`);
  console.log(JSON.stringify({ backupPath, heritage_locations: locations.length,
    destination_images: allImages.length, bookmarks: bookmarks.length,
    destination_reviews: reviews.length }, null, 2));
  return backupPath;
}

async function runApply() {
  await mkdir(CACHE_DIRECTORY, { recursive: true });
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupPath = await createFullBackup();

  const boundary = await readJsonOr(BOUNDARY_PATH, null);
  if (!boundary?.features?.length) {
    throw new Error(`Missing Malaysia ADM1 boundary cache: ${BOUNDARY_PATH}`);
  }
  const googleCache = await readJsonOr(GOOGLE_CACHE_PATH, {});
  let cacheDirty = false;
  const changes = [];
  const stats = {
    processed: 0, patched: 0, states: 0, categories: 0, googleMatched: 0,
    googleRejected: 0, formattedAddresses: 0, openingHours: 0,
    googleMapsUris: 0, descriptions: 0, failures: 0,
  };

  for (const row of locations) {
    stats.processed += 1;
    try {
      let match = null;
      let place = null;
      const cached = googleCache[row.osm_id];
      if (cached?.place && cached?.matchStatus) {
        match = classifyGoogleMatch(row, cached.place);
        place = match?.place ?? null;
      }
      if (!place && cached?.matchStatus !== 'unmatched' && row.google_place_id &&
          ['exact', 'high_confidence', 'nearby'].includes(row.google_match_status)) {
        place = await googlePlaceDetails(row.google_place_id);
        match = classifyGoogleMatch(row, place);
        if (!match) {
          stats.googleRejected += 1;
          place = null;
        }
      }
      if (!place && cached?.matchStatus !== 'unmatched') {
        match = await searchGooglePlace(row);
        place = match?.place ?? null;
      }
      if (match && place) {
        googleCache[row.osm_id] = {
          cached_at: new Date().toISOString(),
          matchStatus: match.matchStatus,
          place,
        };
        cacheDirty = true;
      } else if (!place && cached?.matchStatus !== 'unmatched') {
        googleCache[row.osm_id] = {
          cached_at: new Date().toISOString(),
          matchStatus: 'unmatched',
          place: null,
        };
        cacheDirty = true;
      }

      const state = googleRegion(place) || boundaryRegion(row, boundary.features) ||
        structuredRegion(row) || canonicalRegion(row.state);
      const category = proposedCategory(row);
      const formattedAddress = String(place?.formattedAddress ?? '').trim() ||
        structuredOsmAddress(row, state);
      const candidate = {
        state: state || row.state,
        category,
        formatted_address: formattedAddress || row.formatted_address,
      };
      const rejectedStoredGoogle = cached?.matchStatus === 'unmatched' &&
        Boolean(row.google_place_id);
      if (match && place) {
        candidate.google_place_id = place.id;
        candidate.google_place_name = match.placeName;
        candidate.google_match_status = match.matchStatus;
        candidate.google_maps_uri = String(place.googleMapsUri ?? '').trim() || row.google_maps_uri;
        if (blank(row.opening_hours_weekday_text) && blank(row.opening_hours_periods)) {
          Object.assign(candidate, openingHoursPatch(place));
        }
      } else if (rejectedStoredGoogle) {
        candidate.google_place_id = null;
        candidate.google_place_name = null;
        candidate.google_match_status = null;
        candidate.google_maps_uri = null;
        candidate.opening_hours_weekday_text = null;
        candidate.opening_hours_periods = null;
        candidate.opening_hours_updated_at = null;
      }
      const genericDescription = `${category.charAt(0).toUpperCase()}${category.slice(1).toLowerCase()} located in Malaysia.`;
      if (blank(row.description) || (state && row.description === genericDescription)) {
        const label = category.charAt(0).toUpperCase() + category.slice(1).toLowerCase();
        candidate.description = state
          ? `${label} located in ${state}, Malaysia.`
          : `${label} located in Malaysia.`;
      }
      const patch = differentPatch(row, candidate);
      if (Object.keys(patch).length > 0) {
        await patchLocation(row.osm_id, patch);
        changes.push({ osm_id: row.osm_id, name: row.name, before: row, patch });
        stats.patched += 1;
        if ('state' in patch) stats.states += 1;
        if ('category' in patch) stats.categories += 1;
        if ('google_place_id' in patch) stats.googleMatched += 1;
        if ('formatted_address' in patch) stats.formattedAddresses += 1;
        if ('opening_hours_weekday_text' in patch || 'opening_hours_periods' in patch) stats.openingHours += 1;
        if ('google_maps_uri' in patch) stats.googleMapsUris += 1;
        if ('description' in patch) stats.descriptions += 1;
      }
      if (stats.processed % 25 === 0) {
        if (cacheDirty) {
          await writeGoogleCache(googleCache);
          cacheDirty = false;
        }
        console.log(`Applied ${stats.processed}/${locations.length}; patched ${stats.patched}.`);
      }
    } catch (error) {
      stats.failures += 1;
      console.error(`[${row.osm_id}] ${row.name}: ${error.message}`);
    }
  }

  if (cacheDirty) {
    await writeGoogleCache(googleCache);
  }

  const afterRows = await readAll('heritage_locations', '*', 'osm_id.asc');
  const afterImages = await readAll(
    'destination_images', 'id,destination_id', 'destination_id.asc',
  );
  const afterIds = new Set(afterRows.map((row) => row.osm_id));
  const validation = {
    total_locations: afterRows.length,
    valid_states: afterRows.filter((row) => CANONICAL_REGIONS.includes(String(row.state ?? '').trim())).length,
    blank_states: afterRows.filter((row) => blank(row.state)).length,
    canonical_categories: afterRows.filter((row) => CANONICAL_CATEGORIES.includes(row.category)).length,
    noncanonical_categories: afterRows.filter((row) => !CANONICAL_CATEGORIES.includes(row.category)).length,
    google_matched: afterRows.filter((row) => row.google_place_id &&
      ['exact', 'high_confidence', 'nearby'].includes(row.google_match_status)).length,
    formatted_addresses: afterRows.filter((row) => !blank(row.formatted_address)).length,
    opening_hours_available: afterRows.filter((row) =>
      !blank(row.opening_hours_weekday_text) || !blank(row.opening_hours)).length,
    descriptions_available: afterRows.filter((row) => !blank(row.description)).length,
    malformed_formatted_addresses: afterRows.filter((row) =>
      /malaysia\s*[, ]+\s*malaysia/i.test(String(row.formatted_address ?? ''))).length,
    orphan_destination_images: afterImages.filter((image) => !afterIds.has(image.destination_id)).length,
    heritage_row_count_unchanged: afterRows.length === locations.length,
  };
  validation.opening_hours_unavailable = afterRows.length - validation.opening_hours_available;
  validation.descriptions_unavailable = afterRows.length - validation.descriptions_available;
  const changeReportPath = `reports/discovery-location-apply-${timestamp}.json`;
  await writeFile(changeReportPath, `${JSON.stringify({
    applied_at: new Date().toISOString(), backup_path: backupPath, stats, validation, changes,
  }, null, 2)}\n`);
  console.log(JSON.stringify({ backupPath, changeReportPath, stats, validation }, null, 2));
  if (stats.failures > 0) process.exitCode = 1;
}

const report = {
  generated_at: new Date().toISOString(),
  mode: 'AUDIT_ONLY_NO_REMOTE_WRITES',
  scope: {
    locations_table: 'public.heritage_locations',
    images_table: 'public.destination_images',
    excluded_table: 'public.destinations',
  },
  counts: {
    total_locations: locations.length,
    active_locations: locations.filter((row) => row.is_active).length,
    inactive_locations: locations.filter((row) => !row.is_active).length,
    total_image_rows: images.length,
    locations_with_images: locations.length - missingImages.length,
    locations_without_images: missingImages.length,
    missing,
    invalid_state_rows: invalidStateRows.length,
    suspicious_address_rows: suspiciousAddresses.length,
    invalid_or_out_of_malaysia_coordinates: coordinateIssues.length,
    duplicate_normalized_name_groups: duplicateNameGroups.length,
    duplicate_extra_rows: duplicateNameGroups.reduce((sum, [, rows]) => sum + rows.length - 1, 0),
    probable_same_poi_pairs: duplicateCandidates.flatMap((group) => group.pairs)
      .filter((pair) => pair.classification === 'A_probable_same_poi').length,
    ambiguous_duplicate_pairs: duplicateCandidates.flatMap((group) => group.pairs)
      .filter((pair) => pair.classification === 'C_ambiguous_manual_review').length,
    google_matched: googleMatched.length,
    google_name_inconsistent: googleNameInconsistent.length,
    descriptions_available: locations.length - missing.description,
    opening_hours_available: locations.filter((row) =>
      !blank(row.opening_hours_weekday_text) || !blank(row.opening_hours)).length,
  },
  state_distribution: stateDistribution,
  category_distribution: categoryDistribution,
  google_match_status_distribution: countBy(
    locations,
    (row) => String(row.google_match_status ?? '').trim(),
  ),
  destination_image_source_distribution: countBy(images, (row) => row.source),
  destination_image_match_status_distribution: countBy(images, (row) => row.match_status),
  proposed_state_evidence: stateEvidence,
  proposed_category_transitions: categoryTransitions,
  proposed_description_evidence: descriptionEvidence,
  invalid_state_rows: invalidStateRows.map((row) => ({ osm_id: row.osm_id, name: row.name, state: row.state })),
  blank_state_rows: locations.filter((row) => blank(row.state)).map((row) => ({
    osm_id: row.osm_id, name: row.name, latitude: row.latitude,
    longitude: row.longitude, address: row.address, osm_tags: row.osm_tags,
    google_place_id: row.google_place_id, google_place_name: row.google_place_name,
  })),
  suspicious_addresses: suspiciousAddresses.map(({ row, issue }) => ({
    osm_id: row.osm_id, name: row.name, state: row.state, address: row.address, issue,
  })),
  coordinate_issues: coordinateIssues.map((row) => ({
    osm_id: row.osm_id, name: row.name, latitude: row.latitude, longitude: row.longitude,
  })),
  google_name_inconsistencies: googleNameInconsistent.map((row) => ({
    osm_id: row.osm_id, name: row.name, google_place_id: row.google_place_id,
    google_place_name: row.google_place_name,
    name_similarity: Math.round(similarity(row.name, row.google_place_name) * 100) / 100,
    note: 'Google coordinates are not stored; coordinate consistency requires read-only Place Details validation during approved enrichment.',
  })),
  duplicate_candidates: duplicateCandidates,
  locations_without_images: missingImages.map((row) => ({
    osm_id: row.osm_id,
    name: row.name,
    state: row.state,
    formatted_address: row.formatted_address,
    latitude: row.latitude,
    longitude: row.longitude,
    category: row.category,
    google_place_id: row.google_place_id,
  })),
  hard_case_search_context: hardCases,
  planned_changes: {
    state: 'Accepted Google address components, then coordinate boundary lookup, then structured OSM state tags; canonical 13 states plus 3 Federal Territories.',
    category: 'Apply the deterministic proposed transitions only after review; final active values limited to five canonical experience categories.',
    duplicates: 'No merges planned automatically. Review A pairs, preserve dependent destination_images, and require --merge-confirmed-duplicates.',
    google: 'Coordinate-restricted Places matching, validated by name, distance, locality/state, category/type, and Malaysia country.',
    address: 'Google formattedAddress, else structured OSM address, else truthful locality/state/Malaysia; deduplicate geographic tokens.',
    opening_hours: 'Narrow Place Details fields; preserve trustworthy OSM opening_hours; never invent hours.',
    description: 'Use structured OSM/Wikidata/Wikipedia evidence or neutral category/locality/type text; never invent history.',
  },
  limitations: [
    'No remote rows were changed.',
    'Google candidate coordinates are not stored in heritage_locations; this audit flags name inconsistency only. Coordinate validation belongs to the approved enrichment pass.',
    'Malaysia coordinate validation uses a broad national bounding envelope; offshore and border cases require boundary lookup.',
  ],
};

const md = `# Discovery location audit\n\n` +
  `Generated: ${report.generated_at}\n\n` +
  `**Mode:** AUDIT ONLY — no remote writes\n\n` +
  `## Summary\n\n` +
  `| Metric | Count |\n|---|---:|\n` +
  Object.entries(report.counts).filter(([, value]) => typeof value === 'number')
    .map(([key, value]) => `| ${key.replaceAll('_', ' ')} | ${value} |`).join('\n') +
  `\n\n## Missing fields\n\n| Field | Missing |\n|---|---:|\n` +
  Object.entries(missing).map(([key, value]) => `| ${key} | ${value} |`).join('\n') +
  `\n\n## State distribution\n\n| State | Count |\n|---|---:|\n` +
  Object.entries(stateDistribution).map(([key, value]) => `| ${key} | ${value} |`).join('\n') +
  `\n\n## Category distribution\n\n| Category | Count |\n|---|---:|\n` +
  Object.entries(categoryDistribution).map(([key, value]) => `| ${key} | ${value} |`).join('\n') +
  `\n\n## Proposed category transitions\n\n| Transition | Count |\n|---|---:|\n` +
  Object.entries(categoryTransitions).map(([key, value]) => `| ${key} | ${value} |`).join('\n') +
  `\n\n## Duplicate assessment\n\n` +
  `Normalized-name groups: ${report.counts.duplicate_normalized_name_groups}. ` +
  `Probable same-POI pairs: ${report.counts.probable_same_poi_pairs}. ` +
  `Ambiguous pairs: ${report.counts.ambiguous_duplicate_pairs}.\n\n` +
  `See the JSON report for row-level candidates, reasons, canonical suggestions, image impact, and hard-case search contexts.\n\n` +
  `## Apply safety\n\nThis report was generated in read-only audit mode. Remote updates are available only through the explicit \`--apply\` mode, which creates a fresh local backup before writing.\n`;

await writeFile('reports/discovery-location-audit.json', `${JSON.stringify(report, null, 2)}\n`);
await writeFile('reports/discovery-location-audit.md', md);
await writeFile(
  'reports/discovery-image-readiness.json',
  `${JSON.stringify({
    generated_at: report.generated_at,
    total_locations: report.counts.total_locations,
    locations_with_images: report.counts.locations_with_images,
    locations_without_images: report.counts.locations_without_images,
    missing_image_search_contexts: report.locations_without_images,
  }, null, 2)}\n`,
);
console.log(JSON.stringify(report.counts, null, 2));
if (modeAudit) {
  console.log('Audit reports written. REMOTE WRITES: 0');
} else if (modeBackup) {
  await createFullBackup();
  console.log('Backup completed. REMOTE WRITES: 0');
} else {
  console.log('Audit refreshed; starting approved APPLY mode.');
  await runApply();
}
