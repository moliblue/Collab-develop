const required = (name) => {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
};

const supabaseUrl = required('SUPABASE_URL').replace(/\/$/, '');
const serviceRoleKey = required('SUPABASE_SERVICE_ROLE_KEY');
const googlePlacesApiKey = required('GOOGLE_PLACES_API_KEY');
const pexelsApiKey = process.env.PEXELS_API_KEY?.trim() ?? '';
const dryRun = process.argv.includes('--dry-run');
const showcaseMode = process.argv.includes('--showcase');
const singleImageCleanup = process.argv.includes('--single-image');
const ensureImage = process.argv.includes('--ensure-image');
const allowPexelsFallback =
  ensureImage || process.argv.includes('--allow-pexels-fallback');
const refreshPlaceDetails = process.argv.includes('--refresh-place-details');
const forcePlaceDetails = process.argv.includes('--force-place-details');
const replacePexels =
  process.argv.includes('--replace-pexels') ||
  process.argv.includes('--refresh-fallbacks');
const limitArg = process.argv.find((arg) => arg.startsWith('--limit='));
const namesArg = process.argv.find((arg) => arg.startsWith('--names='));
const randomArg = process.argv.find((arg) => arg.startsWith('--random='));
const destinationLimit = limitArg
  ? Number.parseInt(limitArg.slice('--limit='.length), 10)
  : Number.POSITIVE_INFINITY;
const randomCount = randomArg
  ? Number.parseInt(randomArg.slice('--random='.length), 10)
  : 0;
const requestedNames = namesArg
  ? namesArg.slice('--names='.length).split(/[|,]/).map((value) => value.trim()).filter(Boolean)
  : [];

if (limitArg && (!Number.isInteger(destinationLimit) || destinationLimit < 1)) {
  throw new Error('--limit must be a positive integer.');
}
if (randomArg && (!Number.isInteger(randomCount) || randomCount < 0)) {
  throw new Error('--random must be a non-negative integer.');
}

const stats = {
  destinations: 0,
  skippedComplete: 0,
  skippedProtected: 0,
  imagesInserted: 0,
  fallbacksRefreshed: 0,
  googleImagesSelected: 0,
  exactGoogleImages: 0,
  highConfidenceGoogleImages: 0,
  nearbyImages: 0,
  wikimediaImages: 0,
  pexelsFallbackImages: 0,
  areaFallbackImages: 0,
  genericFallbackImages: 0,
  destinationsWithImage: 0,
  destinationsWithoutImage: 0,
  wikimediaNearbyImagesSelected: 0,
  placeholdersSelected: 0,
  pexelsFallbackRowsRemoved: 0,
  coversRepaired: 0,
  singleImageDestinationsCleaned: 0,
  singleImageRowsRemoved: 0,
  singleImageRowsNormalized: 0,
  singleImageProtectedSkipped: 0,
  noMatches: 0,
  failures: 0,
};
const apiStats = {
  googlePlacesSearches: 0,
  googleNearbySearches: 0,
  googlePlaceDetails: 0,
  googlePhotoFetches: 0,
  wikimediaRequests: 0,
  pexelsRequests: 0,
};
const placeDetailStats = {
  destinations: 0,
  skippedWithoutAcceptedGoogleMatch: 0,
  skippedFresh: 0,
  googlePlaceDetailsRequests: 0,
  placesWithFormattedAddress: 0,
  placesWithOpeningHours: 0,
  placesWithoutOpeningHours: 0,
  placesWithGoogleMapsUri: 0,
  failures: 0,
};
const PLACE_DETAILS_FRESH_MS = 30 * 24 * 60 * 60 * 1000;
const PLACE_DETAILS_FIELD_MASK = [
  'formattedAddress',
  'regularOpeningHours',
  'currentOpeningHours',
  'googleMapsUri',
  'rating',
  'userRatingCount',
].join(',');

const WIKIMEDIA_API = 'https://commons.wikimedia.org/w/api.php';
const WIKIMEDIA_USER_AGENT =
  'FindItMY-DiscoveryImageImporter/1.0 (educational project; https://github.com/moliblue/Collab-develop)';
const GEO_RADII_METERS = [100, 250];
const HIGH_RISK_GENERIC_NAMES = new Set([
  'eagle',
  'the light forest',
  'jimmy choo',
  'batu belah',
  'kluang crown',
  'our lady of lourdes',
]);
const MALAYSIAN_REGIONS = [
  'johor', 'kedah', 'kelantan', 'kuala lumpur', 'labuan', 'malacca', 'melaka',
  'negeri sembilan', 'pahang', 'penang', 'perak', 'perlis', 'putrajaya',
  'sabah', 'sarawak', 'selangor', 'terengganu',
];
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

class FatalConfigurationError extends Error {}

async function fetchWithRetry(url, options = {}, attempts = 5) {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    let response;
    try {
      response = await fetch(url, {
        ...options,
        signal: options.signal ?? AbortSignal.timeout(20000),
      });
    } catch (error) {
      if (attempt === attempts - 1) throw error;
      await sleep(500 * 2 ** attempt);
      continue;
    }
    if (response.ok) return response;
    const retryable = response.status === 429 || response.status >= 500;
    if (!retryable || attempt === attempts - 1) {
      const detail = (await response.text()).slice(0, 500);
      throw new Error(`${response.status} ${response.statusText}: ${detail}`);
    }
    const retryAfter = Number.parseInt(response.headers.get('retry-after') ?? '', 10);
    await sleep(Number.isFinite(retryAfter) ? retryAfter * 1000 : 500 * 2 ** attempt);
  }
  throw new Error('Request retry limit reached.');
}

const adminHeaders = {
  apikey: serviceRoleKey,
  Authorization: `Bearer ${serviceRoleKey}`,
  'Content-Type': 'application/json',
};

async function readAll(table, select, order, filters = {}) {
  const rows = [];
  const pageSize = 500;
  for (let offset = 0; ; offset += pageSize) {
    const query = new URLSearchParams({
      select,
      order,
      offset: String(offset),
      limit: String(pageSize),
      ...filters,
    });
    const response = await fetchWithRetry(`${supabaseUrl}/rest/v1/${table}?${query}`, {
      headers: adminHeaders,
    });
    const page = await response.json();
    rows.push(...page);
    if (page.length < pageSize) return rows;
  }
}

const stripMarkup = (value) =>
  String(value ?? '')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&(?:nbsp|amp|quot|#39);/gi, ' ')
    .replace(/\{\{[^}]*\}\}/g, ' ');

const normalize = (value) =>
  stripMarkup(value)
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

const STOP_WORDS = new Set([
  'a', 'an', 'and', 'at', 'dan', 'di', 'for', 'in', 'jalan', 'malaysia',
  'malaysian', 'of', 'the',
]);
const GENERIC_PLACE_WORDS = new Set([
  'building', 'centre', 'center', 'church', 'gallery', 'house', 'memorial',
  'museum', 'national', 'park', 'temple',
]);

const tokens = (value, omitGeneric = false) =>
  [...new Set(normalize(value).split(' '))].filter(
    (token) => token.length > 2 && !STOP_WORDS.has(token) &&
      (!omitGeneric || !GENERIC_PLACE_WORDS.has(token)),
  );

const overlap = (needles, haystack) => {
  if (needles.length === 0) return 0;
  const words = new Set(tokens(haystack));
  return needles.filter((token) => words.has(token)).length / needles.length;
};

const metadataValue = (metadata, key) => metadata?.[key]?.value ?? '';

function candidateText(page) {
  const metadata = page.imageinfo?.[0]?.extmetadata;
  return [
    page.title,
    page.categories?.map((entry) => entry.title).join(' '),
    metadataValue(metadata, 'ObjectName'),
    metadataValue(metadata, 'ImageDescription'),
    metadataValue(metadata, 'Categories'),
  ].join(' ');
}

function candidatePrimaryText(page) {
  const metadata = page.imageinfo?.[0]?.extmetadata;
  return [page.title, metadataValue(metadata, 'ObjectName')].join(' ');
}

function distanceMeters(lat1, lon1, lat2, lon2) {
  const toRadians = (value) => (value * Math.PI) / 180;
  const latitudeDelta = toRadians(lat2 - lat1);
  const longitudeDelta = toRadians(lon2 - lon1);
  const a = Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
      Math.sin(longitudeDelta / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function pageDistance(destination, page) {
  const coordinate = page.coordinates?.[0];
  if (!coordinate || !Number.isFinite(destination.latitude) ||
      !Number.isFinite(destination.longitude)) return null;
  return distanceMeters(
    destination.latitude,
    destination.longitude,
    Number(coordinate.lat),
    Number(coordinate.lon),
  );
}

function googleCountryCode(place) {
  const country = place.addressComponents?.find((component) =>
    component.types?.includes('country'),
  );
  return String(country?.shortText ?? '').toUpperCase();
}

function googleDisplayName(place) {
  return String(place.displayName?.text ?? '').trim();
}

function isHighRiskGenericName(name) {
  const normalized = normalize(name);
  const nameTokens = tokens(name);
  return HIGH_RISK_GENERIC_NAMES.has(normalized) ||
    normalized.startsWith('i ') ||
    nameTokens.length <= 3;
}

function destinationLocality(destination) {
  const tags = destination.osm_tags ?? {};
  return [
    tags['addr:city'],
    tags['addr:town'],
    tags['addr:village'],
    tags['addr:suburb'],
    tags['is_in:city'],
    tags['is_in:town'],
  ].map((value) => String(value ?? '').trim()).find(Boolean) ?? '';
}

function compactSearchParts(parts) {
  const seen = new Set();
  return parts.map((part) => String(part ?? '').trim())
    .filter((part) => part.length > 0)
    .filter((part) => {
      const key = normalize(part);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function locationSearchPart(value) {
  return String(value ?? '')
    .replace(/\bmalaysia\b/gi, ' ')
    .replace(/[|,]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function googleSearchQueries(destination) {
  const locality = destinationLocality(destination);
  const basic = compactSearchParts([
    destination.name,
    locationSearchPart(destination.address || locality || destination.state),
    locationSearchPart(destination.state),
    'Malaysia',
  ]).join(', ');
  const contextual = compactSearchParts([
    destination.name,
    locationSearchPart(destination.address),
    locationSearchPart(locality),
    locationSearchPart(destination.state),
    destination.category,
    'Malaysia',
  ]).join(', ');
  const ordered = isHighRiskGenericName(destination.name)
    ? [contextual, basic]
    : [basic, contextual];
  return [...new Set(ordered.filter(Boolean))];
}

function googleCategoryCompatible(destination, place) {
  const category = normalize(destination.category);
  const types = new Set([place.primaryType, ...(place.types ?? [])].filter(Boolean));
  let expected = [];
  if (category.includes('museum')) {
    expected = ['museum'];
  } else if (/temple|sacred|religious|mosque|church|shrine/.test(category)) {
    expected = ['place_of_worship', 'hindu_temple', 'mosque', 'church', 'buddhist_temple'];
  } else if (/nature|park|garden|forest/.test(category)) {
    expected = ['park', 'national_park', 'tourist_attraction', 'natural_feature'];
  } else if (/monument|histor|heritage|building|architecture/.test(category)) {
    expected = ['historical_landmark', 'monument', 'museum', 'tourist_attraction', 'cultural_landmark'];
  } else if (/mural|street|art|cultural/.test(category)) {
    expected = ['art_gallery', 'museum', 'tourist_attraction', 'cultural_landmark'];
  }
  return expected.length === 0 || expected.some((type) => types.has(type));
}

function classifyGooglePlace(destination, place) {
  const name = googleDisplayName(place);
  const location = place.location;
  if (!name || !location || googleCountryCode(place) !== 'MY') return null;
  const nonPoiTypes = new Set([
    'administrative_area_level_1',
    'administrative_area_level_2',
    'country',
    'locality',
    'postal_code',
  ]);
  if ([place.primaryType, ...(place.types ?? [])].some((type) => nonPoiTypes.has(type))) {
    return null;
  }
  const distance = distanceMeters(
    destination.latitude,
    destination.longitude,
    Number(location.latitude),
    Number(location.longitude),
  );
  const nameTokens = tokens(destination.name);
  const distinctiveTokens = tokens(destination.name, true);
  const nameSimilarity = overlap(nameTokens, name);
  const reverseSimilarity = overlap(tokens(name), destination.name);
  const similarity = Math.max(nameSimilarity, reverseSimilarity);
  const addressSimilarity = overlap(
    tokens(`${destination.address} ${destination.state}`),
    place.formattedAddress,
  );
  const normalizedDestinationName = normalize(destination.name);
  const normalizedGoogleName = normalize(name);
  const directNameMatch =
    normalizedGoogleName.includes(normalizedDestinationName) ||
    normalizedDestinationName.includes(normalizedGoogleName);
  const isGeneric = isHighRiskGenericName(destination.name);

  // Short/common labels can easily resolve to a person, brand, animal or a
  // different landmark. They need both very close coordinates and locality
  // evidence; name similarity alone is deliberately insufficient.
  if (isGeneric) {
    if (distance <= 100 && similarity >= 0.9 && directNameMatch &&
        addressSimilarity >= 0.25 && googleCategoryCompatible(destination, place)) {
      return {
        place,
        name,
        distance,
        matchStatus: 'high_confidence',
        similarity,
        addressSimilarity,
      };
    }
    return null;
  }

  if (distance <= 500 && similarity >= 0.8 &&
      (directNameMatch || addressSimilarity >= 0.25)) {
    return {
      place,
      name,
      distance,
      matchStatus: 'exact',
      similarity,
      addressSimilarity,
    };
  }
  if (distance <= 500 && similarity >= 0.75 &&
      (addressSimilarity >= 0.25 || (distance <= 150 && directNameMatch))) {
    return {
      place,
      name,
      distance,
      matchStatus: 'high_confidence',
      similarity,
      addressSimilarity,
    };
  }
  // A long, distinctive POI name can be translated or reordered by Google.
  // Very close coordinates provide the additional evidence in this case.
  if (distance <= 100 && distinctiveTokens.length >= 3 && similarity >= 0.67) {
    return {
      place,
      name,
      distance,
      matchStatus: 'high_confidence',
      similarity,
      addressSimilarity,
    };
  }
  // Coarse stored coordinates may be slightly displaced, but a result beyond
  // 500 m is accepted only with an exact name and strong address agreement.
  if (distance <= 2000 && similarity === 1 && directNameMatch &&
      addressSimilarity >= 0.5) {
    return {
      place,
      name,
      distance,
      matchStatus: 'high_confidence',
      similarity,
      addressSimilarity,
    };
  }
  return null;
}

function classifyNearbyGooglePlace(destination, place) {
  const name = googleDisplayName(place);
  const location = place.location;
  if (!name || !location || googleCountryCode(place) !== 'MY') return null;
  const nonPoiTypes = new Set([
    'administrative_area_level_1',
    'administrative_area_level_2',
    'country',
    'locality',
    'postal_code',
  ]);
  if ([place.primaryType, ...(place.types ?? [])].some((type) => nonPoiTypes.has(type))) {
    return null;
  }
  const distance = distanceMeters(
    destination.latitude,
    destination.longitude,
    Number(location.latitude),
    Number(location.longitude),
  );
  const nameTokens = tokens(destination.name);
  const similarity = Math.max(
    overlap(nameTokens, name),
    overlap(tokens(name), destination.name),
  );
  const directNameMatch =
    normalize(name).includes(normalize(destination.name)) ||
    normalize(destination.name).includes(normalize(name));
  const categoryCompatible = googleCategoryCompatible(destination, place);
  const supported = directNameMatch || similarity >= 0.6 ||
    (similarity >= 0.45 && categoryCompatible);
  if (distance > 250 || !supported || !categoryCompatible) return null;
  return {
    place,
    name,
    distance,
    matchStatus: 'nearby',
    similarity,
    addressSimilarity: overlap(
      tokens(`${destination.address} ${destination.state}`),
      place.formattedAddress,
    ),
  };
}

const GOOGLE_PLACE_FIELD_MASK = [
  'places.id',
  'places.displayName',
  'places.formattedAddress',
  'places.addressComponents',
  'places.location',
  'places.primaryType',
  'places.types',
].join(',');

async function searchGooglePlace(destination) {
  console.log('  Google Places:');
  for (const [index, query] of googleSearchQueries(destination).entries()) {
    console.log(`    ${index === 0 ? 'query' : 'contextual retry'}: ${query}`);
    apiStats.googlePlacesSearches += 1;
    let response;
    try {
      response = await fetchWithRetry(
        'https://places.googleapis.com/v1/places:searchText',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': googlePlacesApiKey,
            'X-Goog-FieldMask': GOOGLE_PLACE_FIELD_MASK,
          },
          body: JSON.stringify({
            textQuery: query,
            pageSize: 5,
            languageCode: 'en',
            regionCode: 'MY',
            locationBias: {
              circle: {
                center: {
                  latitude: destination.latitude,
                  longitude: destination.longitude,
                },
                radius: 5000,
              },
            },
          }),
        },
      );
    } catch (error) {
      if (/403|PERMISSION_DENIED|has not been used|disabled/i.test(error.message)) {
        throw new FatalConfigurationError(
          'Google Places API (New) is disabled or not permitted for GOOGLE_PLACES_API_KEY. Enable places.googleapis.com for the key project, then retry.',
        );
      }
      throw error;
    }
    const places = (await response.json()).places ?? [];
    const matches = places
      .map((place) => classifyGooglePlace(destination, place))
      .filter(Boolean)
      .sort((a, b) => {
        const status = { exact: 2, high_confidence: 1 };
        return status[b.matchStatus] - status[a.matchStatus] ||
          b.similarity - a.similarity || a.distance - b.distance;
      });
    const match = matches[0] ?? null;
    if (match) {
      console.log(`    matched place: ${match.name}`);
      console.log(`    confidence: ${match.matchStatus}`);
      console.log(`    distance: ${Math.round(match.distance)}m`);
      return match;
    }
    console.log('    no acceptable match');
  }
  return null;
}

async function searchGooglePlaceByCoordinates(destination) {
  if (!Number.isFinite(destination.latitude) || !Number.isFinite(destination.longitude)) {
    return null;
  }
  console.log('  Google coordinate-biased:');
  apiStats.googleNearbySearches += 1;
  let response;
  try {
    response = await fetchWithRetry(
      'https://places.googleapis.com/v1/places:searchNearby',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': googlePlacesApiKey,
          'X-Goog-FieldMask': GOOGLE_PLACE_FIELD_MASK,
        },
        body: JSON.stringify({
          maxResultCount: 10,
          rankPreference: 'DISTANCE',
          languageCode: 'en',
          regionCode: 'MY',
          locationRestriction: {
            circle: {
              center: {
                latitude: destination.latitude,
                longitude: destination.longitude,
              },
              radius: 1000,
            },
          },
        }),
      },
    );
  } catch (error) {
    if (/403|PERMISSION_DENIED|has not been used|disabled/i.test(error.message)) {
      throw new FatalConfigurationError(
        'Google Places API (New) is disabled or not permitted for GOOGLE_PLACES_API_KEY. Enable places.googleapis.com for the key project, then retry.',
      );
    }
    throw error;
  }
  const places = (await response.json()).places ?? [];
  const matches = places
    .map((place) => classifyNearbyGooglePlace(destination, place))
    .filter(Boolean)
    .sort((a, b) => b.similarity - a.similarity || a.distance - b.distance);
  const match = matches[0] ?? null;
  if (!match) {
    console.log('    no acceptable nearby POI');
    return null;
  }
  console.log(`    matched place: ${match.name}`);
  console.log('    confidence: nearby');
  console.log(`    distance: ${Math.round(match.distance)}m`);
  return match;
}

async function saveGoogleMatch(destinationId, match) {
  if (dryRun || !match) return;
  const response = await fetchWithRetry(
    `${supabaseUrl}/rest/v1/heritage_locations?osm_id=eq.${encodeURIComponent(destinationId)}`,
    {
      method: 'PATCH',
      headers: { ...adminHeaders, Prefer: 'return=minimal' },
      body: JSON.stringify({
        google_place_id: match.place.id,
        google_place_name: match.name,
        google_match_status: match.matchStatus,
      }),
    },
  );
  await response.text();
}

async function getGooglePlacePhotos(placeId, matchStatus = 'fallback') {
  apiStats.googlePlaceDetails += 1;
  const detailsResponse = await fetchWithRetry(
    `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`,
    {
      headers: {
        'X-Goog-Api-Key': googlePlacesApiKey,
        'X-Goog-FieldMask': 'id,photos',
      },
    },
  );
  const photos = (await detailsResponse.json()).photos ?? [];
  console.log('  Google Place Photos:');
  console.log(`    photos available: ${photos.length}`);
  const selected = [];
  for (const photo of photos.slice(0, 1)) {
    apiStats.googlePhotoFetches += 1;
    const mediaParams = new URLSearchParams({
      maxWidthPx: '1600',
      skipHttpRedirect: 'true',
      key: googlePlacesApiKey,
    });
    const mediaResponse = await fetchWithRetry(
      `https://places.googleapis.com/v1/${photo.name}/media?${mediaParams}`,
    );
    const media = await mediaResponse.json();
    if (!media.photoUri) continue;
    const author = photo.authorAttributions?.[0];
    selected.push({
      source: 'google_places',
      sourceImageId: `${placeId}:slot:${selected.length + 1}`,
      sourceTitle: `Google Place Photo ${selected.length + 1}`,
      imageUrl: media.photoUri,
      photographerName: author?.displayName ?? null,
      photographerUrl: author?.uri ?? null,
      sourcePageUrl: photo.googleMapsUri ?? author?.uri ?? null,
      licenseName: null,
      licenseUrl: null,
      matchStatus,
      distanceMeters: null,
      refreshAfter: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
    });
  }
  console.log(`    selected: ${selected.length}`);
  console.log('    lifetime: short-lived; refresh before presentation/use');
  return { images: selected, available: photos.length > 0 };
}

async function getGooglePlaceDetails(placeId) {
  apiStats.googlePlaceDetails += 1;
  placeDetailStats.googlePlaceDetailsRequests += 1;
  const response = await fetchWithRetry(
    `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`,
    {
      headers: {
        'X-Goog-Api-Key': googlePlacesApiKey,
        'X-Goog-FieldMask': PLACE_DETAILS_FIELD_MASK,
      },
    },
  );
  return response.json();
}

function placeDetailsPatch(details) {
  const regular = details.regularOpeningHours ?? null;
  const current = details.currentOpeningHours ?? null;
  const weekdayDescriptions = Array.isArray(regular?.weekdayDescriptions)
    ? regular.weekdayDescriptions.filter((value) => String(value).trim())
    : [];
  const regularPeriods = Array.isArray(regular?.periods) ? regular.periods : [];
  const currentPeriods = Array.isArray(current?.periods) ? current.periods : [];
  const currentWeekdayDescriptions = Array.isArray(current?.weekdayDescriptions)
    ? current.weekdayDescriptions.filter((value) => String(value).trim())
    : [];
  const hasOpeningHours = weekdayDescriptions.length > 0 || regularPeriods.length > 0;
  return {
    row: {
      formatted_address: details.formattedAddress?.trim() || null,
      opening_hours_weekday_text: weekdayDescriptions.length > 0
        ? weekdayDescriptions
        : null,
      opening_hours_periods: regularPeriods.length > 0 || currentPeriods.length > 0 ||
          currentWeekdayDescriptions.length > 0
        ? {
            regular: regularPeriods,
            current: currentPeriods,
            currentWeekdayDescriptions,
            currentOpenNow: typeof current?.openNow === 'boolean' ? current.openNow : null,
          }
        : null,
      opening_hours_updated_at: new Date().toISOString(),
      google_maps_uri: details.googleMapsUri?.trim() || null,
      google_rating: Number.isFinite(details.rating) ? details.rating : null,
      google_user_rating_count: Number.isInteger(details.userRatingCount)
        ? details.userRatingCount
        : null,
      google_rating_updated_at: new Date().toISOString(),
    },
    hasOpeningHours,
  };
}

async function savePlaceDetails(destinationId, row) {
  if (dryRun) return;
  const response = await fetchWithRetry(
    `${supabaseUrl}/rest/v1/heritage_locations?osm_id=eq.${encodeURIComponent(destinationId)}`,
    {
      method: 'PATCH',
      headers: { ...adminHeaders, Prefer: 'return=minimal' },
      body: JSON.stringify(row),
    },
  );
  await response.text();
}

const PLACE_CONTEXT_WORDS = new Set([
  'architecture', 'art', 'building', 'church', 'exterior', 'facade', 'gallery',
  'heritage', 'house', 'installation', 'interior', 'landmark', 'memorial',
  'monument', 'mosque', 'mural', 'museum', 'park', 'sculpture', 'shop', 'shrine',
  'sign', 'square', 'statue', 'street', 'temple', 'tower',
]);
const OBVIOUS_NON_PLACE_WORDS = new Set([
  'animal', 'bird', 'coat of arms', 'diagram', 'emblem', 'headshot', 'icon',
  'insect', 'logo', 'portrait', 'scorpion', 'selfie',
]);

function hasAnyPhrase(text, phrases) {
  return [...phrases].some((phrase) => text.includes(phrase));
}

function looksLikeNearbyPlacePhoto(page) {
  const text = normalize(candidateText(page));
  const hasPlaceContext = hasAnyPhrase(text, PLACE_CONTEXT_WORDS);
  const hasNonPlaceSubject = hasAnyPhrase(text, OBVIOUS_NON_PLACE_WORDS);
  return hasPlaceContext || !hasNonPlaceSubject;
}

function classifyCandidate(destination, page, distanceMeters = null, mode = 'name') {
  const text = normalize(candidateText(page));
  const primaryText = normalize(candidatePrimaryText(page));
  const normalizedName = normalize(
    normalize(destination.name).replace(/\bmalaysia\b/g, ' '),
  );
  const nameTokens = tokens(destination.name);
  const distinctiveTokens = tokens(destination.name, true);
  const nameOverlap = overlap(nameTokens, text);
  const distinctiveOverlap = overlap(distinctiveTokens, text);
  const primaryDistinctiveOverlap = overlap(distinctiveTokens, primaryText);
  const localityOverlap = overlap(tokens(`${destination.address} ${destination.state}`), text);
  const categoryOverlap = overlap(tokens(destination.category), text);
  const fullNameMatch =
    normalizedName.length >= 5 && primaryText.includes(normalizedName);
  const allDistinctiveMatch =
    distinctiveTokens.length >= 2 && primaryDistinctiveOverlap === 1;
  const destinationLocation = normalize(`${destination.address} ${destination.state}`);
  const conflictingRegion = MALAYSIAN_REGIONS.some(
    (region) => primaryText.includes(region) && !destinationLocation.includes(region),
  );
  const isGeneric = isHighRiskGenericName(destination.name);

  if (conflictingRegion || (distanceMeters != null && distanceMeters > 250)) {
    return { accepted: false, matchStatus: null, score: 0 };
  }

  const normalNearbyPhoto = looksLikeNearbyPlacePhoto(page);

  // This relaxed path is geosearch-only. Name search keeps its strict semantic
  // checks even when a Commons file happens to include coordinates.
  if (mode === 'geo' && distanceMeters != null && distanceMeters <= 100 &&
      normalNearbyPhoto) {
    return {
      accepted: true,
      matchStatus: 'nearby',
      score: 70 - Math.round(distanceMeters / 10),
    };
  }

  // Wikimedia titles are not POI identities. For risky/common names, accept
  // only a geotagged image very close to the stored POI with locality context.
  if (isGeneric) {
    if (distanceMeters != null && distanceMeters <= 250 && fullNameMatch &&
        localityOverlap > 0) {
      return {
        accepted: true,
        matchStatus: 'high_confidence',
        score: 90 - Math.round(distanceMeters / 25),
      };
    }
    return { accepted: false, matchStatus: null, score: 0 };
  }

  // Name-search files without coordinates need both a strong POI-name match
  // and locality evidence. This prevents portraits, logos and generic subjects
  // from being classified as destination photos merely by title keywords.
  if (distanceMeters == null) {
    if (distinctiveTokens.length >= 2 && localityOverlap > 0 &&
        (fullNameMatch || allDistinctiveMatch)) {
      return { accepted: true, matchStatus: 'exact', score: 95 };
    }
    return { accepted: false, matchStatus: null, score: 0 };
  }

  if (distanceMeters <= 250 && (fullNameMatch || allDistinctiveMatch)) {
    return {
      accepted: true,
      matchStatus: 'exact',
      score: 100 - Math.round(distanceMeters / 25),
    };
  }
  if (distanceMeters <= 250 && localityOverlap > 0 &&
      ((distinctiveTokens.length >= 2 && distinctiveOverlap === 1) ||
       (nameTokens.length >= 2 && nameOverlap >= 0.8))) {
    return {
      accepted: true,
      matchStatus: 'high_confidence',
      score: 80 + Math.round(10 * localityOverlap) - Math.round(distanceMeters / 50),
    };
  }
  if (mode === 'geo' && distanceMeters > 100 && distanceMeters <= 250 &&
      normalNearbyPhoto &&
      (fullNameMatch || allDistinctiveMatch || localityOverlap > 0 ||
       categoryOverlap > 0 || distinctiveOverlap > 0)) {
    return {
      accepted: true,
      matchStatus: 'nearby',
      score: 60 + Math.round(10 * Math.max(localityOverlap, categoryOverlap)) -
        Math.round(distanceMeters / 25),
    };
  }
  return { accepted: false, matchStatus: null, score: 0 };
}

function wikimediaImage(page, matchStatus, distanceMeters = null) {
  const info = page.imageinfo?.[0] ?? {};
  const metadata = info.extmetadata;
  const author = stripMarkup(
    metadataValue(metadata, 'Artist') || metadataValue(metadata, 'Credit'),
  ).trim();
  const artistMarkup = String(metadataValue(metadata, 'Artist'));
  const authorUrl = artistMarkup.match(/href=["']([^"']+)["']/i)?.[1] ?? null;
  const sourcePageUrl = `https://commons.wikimedia.org/wiki/${encodeURIComponent(
    page.title.replace(/ /g, '_'),
  )}`;
  return {
    source: 'wikimedia',
    sourceImageId: `pageid:${page.pageid}`,
    sourceTitle: page.title,
    imageUrl: info.thumburl || info.url,
    photographerName: author || null,
    photographerUrl: authorUrl?.startsWith('//') ? `https:${authorUrl}` : authorUrl,
    sourcePageUrl,
    licenseName: stripMarkup(metadataValue(metadata, 'LicenseShortName')).trim() || null,
    licenseUrl: metadataValue(metadata, 'LicenseUrl') || null,
    matchStatus,
    distanceMeters,
    refreshAfter: null,
  };
}

async function wikimediaRequest(params) {
  apiStats.wikimediaRequests += 1;
  const query = new URLSearchParams({
    action: 'query', format: 'json', formatversion: '2', origin: '*', ...params,
  });
  const response = await fetchWithRetry(`${WIKIMEDIA_API}?${query}`, {
    headers: { 'User-Agent': WIKIMEDIA_USER_AGENT },
  });
  await sleep(250);
  return response.json();
}

const imageInfoParams = {
  prop: 'imageinfo|categories|coordinates',
  iiprop: 'url|mime|extmetadata',
  iiurlwidth: '1600',
  cllimit: 'max',
};

function usableWikimediaPage(page) {
  const info = page.imageinfo?.[0];
  return Boolean(page.pageid && (info?.thumburl || info?.url) &&
    String(info?.mime ?? '').startsWith('image/'));
}

async function searchWikimediaByName(destination, usedKeys) {
  const queries = [
    destination.googlePlaceName
      ? `\"${destination.googlePlaceName}\" ${destination.state || destination.address} Malaysia`
      : null,
    `\"${destination.name}\" ${destination.state || destination.address} Malaysia`,
    `\"${destination.name}\" Malaysia`,
    `${destination.name} ${destination.address} Malaysia`,
  ].filter(Boolean).map((value) => value.replace(/\s+/g, ' ').trim());
  const candidates = new Map();
  for (const query of [...new Set(queries)]) {
    const data = await wikimediaRequest({
      generator: 'search',
      gsrsearch: query,
      gsrnamespace: '6',
      gsrlimit: '15',
      ...imageInfoParams,
    });
    for (const page of data.query?.pages ?? []) {
      if (usableWikimediaPage(page)) candidates.set(page.pageid, page);
    }
    if (candidates.size >= 10) break;
  }
  const accepted = [];
  for (const page of candidates.values()) {
    const distance = pageDistance(destination, page);
    const classification = classifyCandidate(destination, page, distance, 'name');
    const key = `wikimedia:pageid:${page.pageid}`;
    if (!classification.accepted || usedKeys.has(key)) continue;
    accepted.push({
      ...wikimediaImage(page, classification.matchStatus, distance),
      score: classification.score,
    });
  }
  accepted.sort((a, b) => b.score - a.score || a.sourceTitle.localeCompare(b.sourceTitle));
  return { candidateCount: candidates.size, accepted };
}

async function searchWikimediaByCoordinates(destination, usedKeys) {
  if (!Number.isFinite(destination.latitude) || !Number.isFinite(destination.longitude)) {
    return { candidateCount: 0, accepted: [], radius: null };
  }
  const candidates = new Map();
  let usedRadius = null;
  for (const radius of GEO_RADII_METERS) {
    usedRadius = radius;
    const geo = await wikimediaRequest({
      list: 'geosearch',
      gscoord: `${destination.latitude}|${destination.longitude}`,
      gsradius: String(radius),
      gsnamespace: '6',
      gslimit: '30',
    });
    const hits = geo.query?.geosearch ?? [];
    if (hits.length === 0) continue;
    const details = await wikimediaRequest({
      titles: hits.map((hit) => hit.title).join('|'),
      ...imageInfoParams,
    });
    const distanceByTitle = new Map(hits.map((hit) => [hit.title, hit.dist]));
    for (const page of details.query?.pages ?? []) {
      if (!usableWikimediaPage(page)) continue;
      const distance = Number(distanceByTitle.get(page.title));
      const previous = candidates.get(page.pageid);
      if (!previous || distance < previous.distance) candidates.set(page.pageid, { page, distance });
    }
    if ([...candidates.values()].some(({ page, distance }) =>
      classifyCandidate(destination, page, distance, 'geo').accepted)) break;
  }
  const accepted = [];
  for (const { page, distance } of candidates.values()) {
    const classification = classifyCandidate(destination, page, distance, 'geo');
    const key = `wikimedia:pageid:${page.pageid}`;
    if (!classification.accepted || usedKeys.has(key)) continue;
    accepted.push({
      ...wikimediaImage(page, classification.matchStatus, distance),
      score: classification.score,
    });
  }
  accepted.sort((a, b) => b.score - a.score ||
    (a.distanceMeters ?? Number.POSITIVE_INFINITY) -
      (b.distanceMeters ?? Number.POSITIVE_INFINITY));
  return { candidateCount: candidates.size, accepted, radius: usedRadius };
}

async function findWikimediaImages(destination, usedKeys) {
  console.log('  Wikimedia name search:');
  const nameResult = await searchWikimediaByName(destination, usedKeys);
  console.log(`    candidates: ${nameResult.candidateCount}`);
  console.log(`    accepted: ${nameResult.accepted.length}`);
  if (nameResult.accepted.length > 0) {
    const exact = nameResult.accepted.filter((image) => image.matchStatus === 'exact');
    return (exact.length > 0 ? exact : nameResult.accepted).slice(0, 1);
  }
  console.log('    no acceptable match');
  console.log('  Wikimedia geosearch:');
  const geoResult = await searchWikimediaByCoordinates(destination, usedKeys);
  const checkedRadii = GEO_RADII_METERS.filter((radius) => radius <= (geoResult.radius ?? 0));
  console.log(`    radii checked: ${checkedRadii.length ? `${checkedRadii.join('m, ')}m` : 'none'}`);
  console.log(`    candidates: ${geoResult.candidateCount}`);
  console.log(`    accepted: ${geoResult.accepted.length}`);
  if (geoResult.accepted.length === 0) console.log('    no acceptable match');
  return geoResult.accepted.slice(0, 1);
}

async function searchPexels(query) {
  if (!pexelsApiKey) {
    console.log('    skipped: PEXELS_API_KEY is not configured');
    return [];
  }
  const params = new URLSearchParams({
    query,
    orientation: 'landscape',
    per_page: '15',
  });
  apiStats.pexelsRequests += 1;
  const response = await fetchWithRetry(`https://api.pexels.com/v1/search?${params}`, {
    headers: { Authorization: pexelsApiKey },
  });
  await sleep(400);
  return (await response.json()).photos ?? [];
}

async function findPexelsFallback(destination, usedKeys) {
  console.log('  Pexels fallback:');
  if (!pexelsApiKey) {
    console.log('    skipped: PEXELS_API_KEY is not configured');
    return [];
  }
  const locality = destinationLocality(destination);
  const queries = [
    {
      query: compactSearchParts([
        destination.name,
        locationSearchPart(destination.address),
        locationSearchPart(locality),
        locationSearchPart(destination.state),
        'Malaysia',
      ]).join(' '),
      matchStatus: 'fallback',
    },
    {
      query: compactSearchParts([
        destination.name,
        locationSearchPart(destination.state),
        'Malaysia',
      ]).join(' '),
      matchStatus: 'fallback',
    },
    ...(locality ? [{
      query: compactSearchParts([
        locationSearchPart(locality),
        destination.category,
        'Malaysia',
      ]).join(' '),
      matchStatus: 'area_fallback',
    }] : []),
    ...(destination.state && normalize(destination.state) !== 'malaysia' ? [{
      query: compactSearchParts([
        locationSearchPart(destination.state),
        destination.category,
        'Malaysia',
      ]).join(' '),
      matchStatus: 'area_fallback',
    }] : []),
  ];
  const seenQueries = new Set();
  for (const candidate of queries) {
    const queryKey = normalize(candidate.query);
    if (!queryKey || seenQueries.has(queryKey) || queryKey === 'malaysia') continue;
    seenQueries.add(queryKey);
    console.log(`    query: ${candidate.query}`);
    const photos = (await searchPexels(candidate.query)).filter(
      (photo) => !usedKeys.has(`pexels:${photo.id}`),
    );
    const photo = photos.find(
      (entry) => entry.src?.large2x || entry.src?.large || entry.src?.landscape,
    );
    if (!photo) continue;
    const imageUrl = photo.src?.large2x ?? photo.src?.large ?? photo.src?.landscape;
    console.log('    selected: 1');
    console.log(`    match: ${candidate.matchStatus}`);
    return [{
      source: 'pexels',
      sourceImageId: String(photo.id),
      sourceTitle: `Pexels ${photo.id}`,
      imageUrl,
      photographerName: photo.photographer ?? null,
      photographerUrl: photo.photographer_url ?? null,
      sourcePageUrl: photo.url ?? null,
      licenseName: null,
      licenseUrl: null,
      matchStatus: candidate.matchStatus,
      distanceMeters: null,
      refreshAfter: null,
    }];
  }
  console.log('    selected: 0');
  return [];
}

function fallbackCategory(category) {
  const value = normalize(category);
  if (value.includes('museum')) return 'museum';
  if (/mural|street art|gallery|artwork/.test(value)) return 'mural';
  if (/temple|sacred|religious|mosque|church|shrine/.test(value)) return 'religious';
  if (/nature|forest|beach/.test(value)) return 'nature';
  if (/park|garden/.test(value)) return 'park';
  if (/monument|memorial|histor/.test(value)) return 'monument';
  if (/building|architecture|palace|house/.test(value)) return 'building';
  if (/heritage|culture|cultural/.test(value)) return 'heritage';
  return 'general';
}

function localCategoryFallback(destination) {
  const category = fallbackCategory(destination.category);
  console.log('  Category fallback:');
  console.log(`    category: ${category}`);
  console.log('    selected local fallback image');
  console.log('    match: generic_fallback');
  return [{
    source: 'local_fallback',
    sourceImageId: `local:${category}:${destination.osm_id}`,
    sourceTitle: `Local ${category} Discovery placeholder`,
    imageUrl: 'assets/discovery_placeholder.png',
    photographerName: null,
    photographerUrl: null,
    sourcePageUrl: null,
    licenseName: null,
    licenseUrl: null,
    matchStatus: 'generic_fallback',
    distanceMeters: null,
    refreshAfter: null,
  }];
}

function printSelected(images) {
  if (images.length === 0) return;
  console.log('  Selected:');
  images.forEach((image, index) => {
    console.log(`    ${index + 1}. ${image.sourceTitle}`);
    console.log(`       source: ${image.source}`);
    console.log(`       match: ${image.matchStatus}`);
    if (image.distanceMeters != null) console.log(`       distance: ${Math.round(image.distanceMeters)}m`);
  });
}

async function patchRowsForReplacement(destinationId, current, selected) {
  if (dryRun) return;
  const clearCover = await fetchWithRetry(
    `${supabaseUrl}/rest/v1/destination_images?destination_id=eq.${encodeURIComponent(destinationId)}`,
    {
      method: 'PATCH',
      headers: { ...adminHeaders, Prefer: 'return=minimal' },
      body: JSON.stringify({ is_cover: false }),
    },
  );
  await clearCover.text();
  const ordered = [...current].sort((a, b) => a.display_order - b.display_order);
  for (let index = 0; index < selected.length; index += 1) {
    const image = selected[index];
    const response = await fetchWithRetry(
      `${supabaseUrl}/rest/v1/destination_images?id=eq.${encodeURIComponent(ordered[index].id)}`,
      {
        method: 'PATCH',
        headers: { ...adminHeaders, Prefer: 'return=minimal' },
        body: JSON.stringify({
          image_url: image.imageUrl,
          source: image.source,
          source_image_id: image.sourceImageId,
          photographer_name: image.photographerName,
          photographer_url: image.photographerUrl,
          license_name: image.licenseName,
          license_url: image.licenseUrl,
          source_page_url: image.sourcePageUrl,
          refresh_after: image.refreshAfter,
          is_cover: index === 0,
          display_order: index + 1,
          match_status: image.matchStatus,
        }),
      },
    );
    await response.text();
  }
  for (const row of ordered.slice(selected.length)) {
    const response = await fetchWithRetry(
      `${supabaseUrl}/rest/v1/destination_images?id=eq.${encodeURIComponent(row.id)}`,
      { method: 'DELETE', headers: { ...adminHeaders, Prefer: 'return=minimal' } },
    );
    await response.text();
  }
}

async function repairCover(images) {
  if (images.length === 0 || images.some((image) => image.is_cover)) return;
  const selected = [...images].sort(
    (a, b) => a.display_order - b.display_order || a.id.localeCompare(b.id),
  )[0];
  if (!dryRun) {
    const response = await fetchWithRetry(
      `${supabaseUrl}/rest/v1/destination_images?id=eq.${encodeURIComponent(selected.id)}`,
      {
        method: 'PATCH',
        headers: { ...adminHeaders, Prefer: 'return=minimal' },
        body: JSON.stringify({ is_cover: true }),
      },
    );
    await response.text();
  }
  selected.is_cover = true;
  stats.coversRepaired += 1;
}

async function insertImage(row) {
  if (dryRun) return;
  const response = await fetchWithRetry(`${supabaseUrl}/rest/v1/destination_images`, {
    method: 'POST',
    headers: { ...adminHeaders, Prefer: 'return=minimal' },
    body: JSON.stringify(row),
  });
  await response.text();
}

async function deleteImageRows(rows) {
  if (dryRun) return;
  for (const row of rows) {
    const response = await fetchWithRetry(
      `${supabaseUrl}/rest/v1/destination_images?id=eq.${encodeURIComponent(row.id)}`,
      { method: 'DELETE', headers: { ...adminHeaders, Prefer: 'return=minimal' } },
    );
    await response.text();
  }
}

function isProtectedImage(image) {
  return image.source === 'manual' ||
    image.match_status === 'manual' ||
    image.match_status === 'verified';
}

function existingImagePriority(image) {
  const hasImage = String(image.image_url ?? '').trim().length > 0;
  if (image.is_cover && hasImage) return 0;
  if (
    image.source === 'google_places' &&
    ['exact', 'high_confidence'].includes(image.match_status)
  ) return 1;
  if (
    image.source === 'wikimedia' &&
    ['exact', 'high_confidence', 'nearby'].includes(image.match_status)
  ) return 2;
  return 3;
}

function chooseExistingSingleImage(images) {
  return [...images].sort((a, b) =>
    existingImagePriority(a) - existingImagePriority(b) ||
    a.display_order - b.display_order ||
    a.id.localeCompare(b.id)
  )[0];
}

async function cleanToSingleImage(destination, images) {
  if (images.length === 0) {
    console.log('  Cleanup: no destination image rows; placeholder remains in use.');
    return [];
  }
  if (images.length > 1 && images.some(isProtectedImage)) {
    stats.singleImageProtectedSkipped += 1;
    console.log(
      `  Cleanup skipped: preserved ${images.length} protected/manual/verified image row(s).`,
    );
    return images;
  }

  const selected = chooseExistingSingleImage(images);
  const extras = images.filter((image) => image.id !== selected.id);
  const needsNormalization = !selected.is_cover || selected.display_order !== 1;
  if (!dryRun && (extras.length > 0 || needsNormalization)) {
    const clearCover = await fetchWithRetry(
      `${supabaseUrl}/rest/v1/destination_images?destination_id=eq.${encodeURIComponent(destination.osm_id)}`,
      {
        method: 'PATCH',
        headers: { ...adminHeaders, Prefer: 'return=minimal' },
        body: JSON.stringify({ is_cover: false }),
      },
    );
    await clearCover.text();
    await deleteImageRows(extras);
    const normalizeCover = await fetchWithRetry(
      `${supabaseUrl}/rest/v1/destination_images?id=eq.${encodeURIComponent(selected.id)}`,
      {
        method: 'PATCH',
        headers: { ...adminHeaders, Prefer: 'return=minimal' },
        body: JSON.stringify({ display_order: 1, is_cover: true }),
      },
    );
    await normalizeCover.text();
  }

  if (extras.length > 0) {
    stats.singleImageDestinationsCleaned += 1;
    stats.singleImageRowsRemoved += extras.length;
  }
  if (needsNormalization) stats.singleImageRowsNormalized += 1;
  selected.display_order = 1;
  selected.is_cover = true;
  console.log(
    `  ${dryRun ? 'Would keep' : 'Kept'} one ${selected.source} image as display_order=1, is_cover=true; ` +
    `${dryRun ? 'would remove' : 'removed'} ${extras.length} extra row(s).`,
  );
  return [selected];
}

function presentationImageStatus(image) {
  if (!image) return 'placeholder';
  const source = image.source;
  const matchStatus = image.matchStatus ?? image.match_status ?? 'fallback';
  if (source === 'google_places') return `google_${matchStatus}`;
  if (source === 'wikimedia') return `wikimedia_${matchStatus}`;
  return matchStatus;
}

function recordPresentationOutcome(images) {
  if (images.length === 0) {
    stats.placeholdersSelected += 1;
    stats.destinationsWithoutImage += 1;
    console.log('  Image status: placeholder');
    console.log('  FINAL IMAGE: NO');
    return;
  }
  stats.destinationsWithImage += 1;
  const image = chooseExistingSingleImage(images);
  const source = image.source;
  const matchStatus = image.matchStatus ?? image.match_status;
  if (source === 'google_places') stats.googleImagesSelected += 1;
  if (source === 'google_places' && matchStatus === 'exact') {
    stats.exactGoogleImages += 1;
  }
  if (source === 'google_places' && matchStatus === 'high_confidence') {
    stats.highConfidenceGoogleImages += 1;
  }
  if (matchStatus === 'nearby') stats.nearbyImages += 1;
  if (source === 'wikimedia') {
    stats.wikimediaImages += 1;
    if (matchStatus === 'nearby') stats.wikimediaNearbyImagesSelected += 1;
  }
  if (source === 'pexels' && matchStatus === 'fallback') {
    stats.pexelsFallbackImages += 1;
  }
  if (matchStatus === 'area_fallback') stats.areaFallbackImages += 1;
  if (matchStatus === 'generic_fallback') stats.genericFallbackImages += 1;
  console.log(`  Image status: ${presentationImageStatus(image)}`);
  console.log('  FINAL IMAGE: YES');
}

function printDryRunResult(destination, result, selected) {
  if (!dryRun) return;
  console.log([
    '  RESULT',
    `destination=${destination.name}`,
    `google=${result.googleMatch?.name ?? 'none'}`,
    `distance=${result.googleMatch ? `${Math.round(result.googleMatch.distance)}m` : 'n/a'}`,
    `confidence=${result.googleMatch?.matchStatus ?? 'none'}`,
    `photo_available=${result.googlePhotoAvailable ? 'yes' : 'no'}`,
    `selected_source=${selected[0]?.source ?? 'placeholder'}`,
    `image_status=${presentationImageStatus(selected[0])}`,
    `wikimedia_fallback=${result.wikimediaNeeded ? 'yes' : 'no'}`,
    `placeholder=${selected.length === 0 ? 'yes' : 'no'}`,
  ].join(' | '));
}

async function findPreferredImages(destination, usedKeys) {
  let googleMatch = null;
  try {
    googleMatch = await searchGooglePlace(destination);
    if (!googleMatch) {
      googleMatch = await searchGooglePlaceByCoordinates(destination);
    }
  } catch (error) {
    if (error instanceof FatalConfigurationError) throw error;
    console.log(`  Google unavailable: ${error.message}`);
  }
  await saveGoogleMatch(destination.osm_id, googleMatch);
  const imageDestination = googleMatch
    ? { ...destination, googlePlaceName: googleMatch.name }
    : destination;
  let googlePhotoAvailable = false;
  if (googleMatch) {
    try {
      const googlePhotoResult = await getGooglePlacePhotos(
        googleMatch.place.id,
        googleMatch.matchStatus,
      );
      googlePhotoAvailable = googlePhotoResult.available;
      if (googlePhotoResult.images.length > 0) {
        return {
          images: googlePhotoResult.images,
          googleMatch,
          googlePhotoAvailable,
          wikimediaNeeded: false,
        };
      }
    } catch (error) {
      console.log(`  Google photo unavailable: ${error.message}`);
    }
  }
  let wikimedia = [];
  try {
    wikimedia = await findWikimediaImages(imageDestination, usedKeys);
  } catch (error) {
    console.log(`  Wikimedia unavailable: ${error.message}`);
  }
  if (wikimedia.length > 0) {
    return {
      images: wikimedia,
      googleMatch,
      googlePhotoAvailable,
      wikimediaNeeded: true,
    };
  }
  let pexels = [];
  if (allowPexelsFallback) {
    try {
      pexels = await findPexelsFallback(destination, usedKeys);
    } catch (error) {
      console.log(`  Pexels unavailable: ${error.message}`);
    }
  }
  const finalImages = pexels.length > 0
    ? pexels
    : ensureImage
      ? localCategoryFallback(destination)
      : [];
  return {
    images: finalImages,
    googleMatch,
    googlePhotoAvailable,
    wikimediaNeeded: true,
  };
}

function hashName(value) {
  let hash = 2166136261;
  for (const character of value) {
    hash ^= character.charCodeAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function chooseDestinations(destinations) {
  if (requestedNames.length === 0 && randomCount === 0) {
    return destinations.slice(0, destinationLimit);
  }
  const chosen = [];
  const chosenIds = new Set();
  for (const requestedName of requestedNames) {
    const target = normalize(requestedName);
    const destination = destinations.find((entry) => normalize(entry.name) === target) ??
      destinations.find((entry) => normalize(entry.name).includes(target));
    if (!destination) {
      console.warn(`Requested destination not found: ${requestedName}`);
      continue;
    }
    if (!chosenIds.has(destination.osm_id)) {
      chosen.push(destination);
      chosenIds.add(destination.osm_id);
    }
  }
  const randomPool = destinations
    .filter((entry) => !chosenIds.has(entry.osm_id))
    .sort((a, b) => hashName(a.osm_id) - hashName(b.osm_id));
  chosen.push(...randomPool.slice(0, randomCount));
  return chosen.slice(0, destinationLimit);
}

const DISCOVERY_DESTINATION_SELECT =
  'osm_id,name,address,state,category,latitude,longitude,osm_tags,' +
  'google_place_id,google_place_name,google_match_status';

async function readDiscoveryDestinations({ includeDetailsTimestamp = false } = {}) {
  const select = includeDetailsTimestamp
    ? `${DISCOVERY_DESTINATION_SELECT},opening_hours_updated_at`
    : DISCOVERY_DESTINATION_SELECT;
  try {
    return await readAll(
      'heritage_locations',
      select,
      'osm_id.asc',
      { is_active: 'eq.true', is_verified: 'eq.true' },
    );
  } catch (error) {
    if (includeDetailsTimestamp && /42703|opening_hours_updated_at/i.test(error.message)) {
      console.log('Place-details migration is pending; freshness cache is unavailable in this dry run.');
      return readDiscoveryDestinations();
    }
    throw error;
  }
}

async function runPlaceDetailsRefresh() {
  const destinations = await readDiscoveryDestinations({ includeDetailsTimestamp: true });
  const eligible = destinations.filter((destination) =>
    ['exact', 'high_confidence'].includes(destination.google_match_status) &&
      destination.google_place_id,
  );
  const selected = chooseDestinations(eligible);
  console.log(
    `${dryRun ? '[DRY RUN] ' : ''}Place Details refresh selected ${selected.length} Google-matched destinations.`,
  );
  console.log(`Field mask: ${PLACE_DETAILS_FIELD_MASK}`);
  for (const destination of selected) {
    placeDetailStats.destinations += 1;
    console.log(`\n[${placeDetailStats.destinations}/${selected.length}] ${destination.name}`);
    const acceptedMatch = ['exact', 'high_confidence'].includes(
      destination.google_match_status,
    );
    if (!acceptedMatch || !destination.google_place_id) {
      placeDetailStats.skippedWithoutAcceptedGoogleMatch += 1;
      console.log('  Skipped: no accepted stored Google Place match.');
      continue;
    }
    const updatedAt = Date.parse(destination.opening_hours_updated_at ?? '');
    const fresh = Number.isFinite(updatedAt) &&
      Date.now() - updatedAt < PLACE_DETAILS_FRESH_MS;
    if (fresh && !forcePlaceDetails) {
      placeDetailStats.skippedFresh += 1;
      console.log('  Skipped: cached Place Details are still fresh.');
      continue;
    }
    try {
      const details = await getGooglePlaceDetails(destination.google_place_id);
      const parsed = placeDetailsPatch(details);
      await savePlaceDetails(destination.osm_id, parsed.row);
      if (parsed.row.formatted_address) {
        placeDetailStats.placesWithFormattedAddress += 1;
      }
      if (parsed.hasOpeningHours) {
        placeDetailStats.placesWithOpeningHours += 1;
      } else {
        placeDetailStats.placesWithoutOpeningHours += 1;
      }
      if (parsed.row.google_maps_uri) placeDetailStats.placesWithGoogleMapsUri += 1;
      console.log(`  Google place ID: ${destination.google_place_id}`);
      console.log(`  Formatted address: ${parsed.row.formatted_address ?? 'unavailable'}`);
      console.log(
        `  Opening hours: ${parsed.hasOpeningHours ? `${parsed.row.opening_hours_weekday_text?.length ?? 0} weekday descriptions` : 'unavailable'}`,
      );
      console.log(`  Google Maps URI: ${parsed.row.google_maps_uri ? 'available' : 'unavailable'}`);
    } catch (error) {
      placeDetailStats.failures += 1;
      console.error(`  Failed: ${error.message}`);
      if (/403 Forbidden|API_KEY_SERVICE_BLOCKED|has not been used.*disabled/i.test(error.message)) {
        console.error(
          '  Stopping: enable Places API (New) and permit places.googleapis.com for this key before retrying.',
        );
        break;
      }
    }
  }
  console.log('\nGoogle Place Details refresh summary');
  console.table(placeDetailStats);
  if (placeDetailStats.failures > 0) process.exitCode = 1;
}

async function runImagePopulation() {
const destinations = await readDiscoveryDestinations();
const existingImages = await readAll(
  'destination_images',
  'id,destination_id,image_url,source,source_image_id,is_cover,display_order,match_status,refresh_after',
  'destination_id.asc,display_order.asc',
);
const byDestination = new Map();
for (const image of existingImages) {
  const group = byDestination.get(image.destination_id) ?? [];
  group.push(image);
  byDestination.set(image.destination_id, group);
}
const usedKeys = new Set(
  existingImages.filter((image) => image.source_image_id)
    .map((image) => `${image.source}:${image.source_image_id}`),
);
const selectedDestinations = chooseDestinations(destinations);

console.log(
  `${dryRun ? '[DRY RUN] ' : ''}Found ${destinations.length} destinations and ${existingImages.length} existing images; selected ${selectedDestinations.length}.`,
);
if (replacePexels) console.log('Pexels replacement mode is enabled.');
if (ensureImage) console.log('Guaranteed image coverage mode is enabled.');
console.log(`Pexels automatic fallback: ${allowPexelsFallback ? 'enabled' : 'disabled'}.`);
if (showcaseMode) {
  console.log('Showcase mode is accepted for compatibility; image selection remains limited to one.');
}
if (singleImageCleanup && !ensureImage) {
  console.log('Single-image cleanup mode: no new images will be fetched or populated.');
}

for (const destination of selectedDestinations) {
  stats.destinations += 1;
  let current = byDestination.get(destination.osm_id) ?? [];
  console.log(`\n[${stats.destinations}/${selectedDestinations.length}] ${destination.name}`);
  try {
    if (singleImageCleanup && !ensureImage) {
      await cleanToSingleImage(destination, current);
      continue;
    }
    if (current.length > 1 && (singleImageCleanup || ensureImage)) {
      current = await cleanToSingleImage(destination, current);
    }
    if (
      current.length === 1 &&
      (!current[0].is_cover || current[0].display_order !== 1)
    ) {
      await cleanToSingleImage(destination, current);
    }
    const protectedImages = current.some(
      isProtectedImage,
    );
    if (protectedImages) {
      stats.skippedProtected += 1;
      recordPresentationOutcome(current);
      console.log('  Skipped: manually verified image(s) are protected.');
      continue;
    }

    const onlyLowConfidencePexels = current.length > 0 && current.every(
      (image) => image.source === 'pexels' && image.match_status === 'fallback',
    );
    const onlyUpgradeableFallback = current.length > 0 && current.every(
      (image) => ![
        'exact',
        'high_confidence',
        'nearby',
        'manual',
        'verified',
      ].includes(image.match_status),
    );
    const shouldUpgrade = onlyLowConfidencePexels && replacePexels ||
      onlyUpgradeableFallback && ensureImage;
    const onlyGoogle = current.length > 0 &&
      current.every((image) => image.source === 'google_places');
    if (onlyUpgradeableFallback && !shouldUpgrade) {
      stats.skippedProtected += 1;
      recordPresentationOutcome(current);
      console.log('  Existing Pexels images preserved (use --replace-pexels to re-evaluate).');
      continue;
    }

    if (onlyGoogle && !shouldUpgrade) {
      if (current.length > 1) {
        stats.skippedComplete += 1;
        recordPresentationOutcome(current);
        console.log('  Existing multi-image data preserved; use --single-image for explicit cleanup.');
        continue;
      }
      const refreshAfter = Date.parse(current[0].refresh_after ?? '');
      if (Number.isFinite(refreshAfter) && refreshAfter > Date.now()) {
        stats.skippedComplete += 1;
        recordPresentationOutcome(current);
        console.log('  Existing Google demo image is still fresh; skipped.');
        continue;
      }
      const placeId = String(current[0].source_image_id ?? '').split(':slot:')[0];
      if (!placeId) {
        stats.failures += 1;
        console.log('  Cannot refresh Google demo photos: stable place ID is missing.');
        continue;
      }
      const refreshedResult = await getGooglePlacePhotos(
        placeId,
        current[0].match_status ?? 'fallback',
      );
      const refreshed = refreshedResult.images;
      printSelected(refreshed);
      if (refreshed.length === 0) {
        recordPresentationOutcome(current);
        console.log('  Existing Google demo photos kept: refresh returned no photos.');
        continue;
      }
      recordPresentationOutcome(refreshed);
      await patchRowsForReplacement(destination.osm_id, current, refreshed);
      stats.fallbacksRefreshed += 1;
      console.log(
        `  ${dryRun ? 'Would refresh' : 'Refreshed'} ${refreshed.length} short-lived Google demo photo(s).`,
      );
      continue;
    }

    if (current.length > 0 && !shouldUpgrade) {
      await repairCover(current);
      stats.skippedComplete += 1;
      recordPresentationOutcome(current);
      console.log(`  Existing reusable ${current[0].source} image(s) preserved; no additional image is fetched.`);
      continue;
    }

    const result = await findPreferredImages(destination, usedKeys);
    const selected = result.images.slice(0, 1);
    printSelected(selected);
    printDryRunResult(destination, result, selected);
    recordPresentationOutcome(selected);
    if (selected.length === 0) {
      stats.noMatches += 1;
      if (shouldUpgrade) {
        await deleteImageRows(current);
        stats.pexelsFallbackRowsRemoved += current.length;
        console.log(
          `  ${dryRun ? 'Would remove' : 'Removed'} ${current.length} low-confidence Pexels fallback image(s); using placeholder.`,
        );
      } else {
        console.log('  No image selected; accuracy is preferred over filling slots.');
      }
      continue;
    }

    if (shouldUpgrade) {
      await patchRowsForReplacement(destination.osm_id, current, selected);
      for (const image of selected) usedKeys.add(`${image.source}:${image.sourceImageId}`);
      stats.fallbacksRefreshed += 1;
      console.log(
        `  ${dryRun ? 'Would replace' : 'Replaced'} ${current.length} Pexels image(s) with ${selected.length} ${selected[0].source} image(s).`,
      );
      continue;
    }

    for (let index = 0; index < selected.length; index += 1) {
      const image = selected[index];
      await insertImage({
        destination_id: destination.osm_id,
        image_url: image.imageUrl,
        source: image.source,
        source_image_id: image.sourceImageId,
        photographer_name: image.photographerName,
        photographer_url: image.photographerUrl,
        license_name: image.licenseName,
        license_url: image.licenseUrl,
        source_page_url: image.sourcePageUrl,
        refresh_after: image.refreshAfter,
        is_cover: index === 0,
        display_order: index + 1,
        match_status: image.matchStatus,
      });
      usedKeys.add(`${image.source}:${image.sourceImageId}`);
      stats.imagesInserted += 1;
    }
  } catch (error) {
    if (error instanceof FatalConfigurationError) {
      stats.failures += 1;
      if (ensureImage) stats.destinationsWithoutImage += 1;
      console.error(`  Fatal configuration error: ${error.message}`);
      break;
    }
    stats.failures += 1;
    if (ensureImage) stats.destinationsWithoutImage += 1;
    console.error(`  Failed: ${error.message}`);
  }
}

console.log('\nDestination image population summary');
console.table(stats);
const coverageTotal = stats.destinationsWithImage + stats.destinationsWithoutImage;
const coverage = coverageTotal === 0
  ? 100
  : (stats.destinationsWithImage / coverageTotal) * 100;
console.log(`Image coverage: ${coverage.toFixed(2)}%`);
console.log('\nAPI usage summary');
console.table(apiStats);
if (stats.failures > 0) process.exitCode = 1;
}

if (refreshPlaceDetails) {
  await runPlaceDetailsRefresh();
} else {
  await runImagePopulation();
}
