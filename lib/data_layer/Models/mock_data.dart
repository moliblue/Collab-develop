import 'package:flutter/material.dart';

import 'app_models.dart';

const assetRoot = 'assets';

List<HeritagePlace> createPlaces() => <HeritagePlace>[
  HeritagePlace(
    id: 'batu',
    name: 'Batu Caves Murugan Temple',
    category: 'Traditional Heritage Site',
    state: 'Selangor',
    shortDescription:
        'Iconic limestone cave temple with a golden Murugan statue and 272 vibrant steps.',
    description:
        'Rising 100 metres above the ground, Batu Caves is one of the most popular Hindu shrines outside India. The 400-million-year-old limestone complex has cathedral-like caves, elaborate shrines and panoramic views of Kuala Lumpur.',
    image: '$assetRoot/batu_caves.png',
    distanceKm: 9.8,
    rating: 4.9,
    reviewsCount: 42,
    latitude: 3.2379,
    longitude: 101.6840,
    address: 'Gombak, 68100 Batu Caves, Selangor',
    hours: 'Daily · 6:00 AM – 9:00 PM',
    bookmarked: true,
    reviews: <Review>[
      Review(
        name: 'Eleanor Vance',
        date: 'October 12, 2025',
        rating: 5,
        comment: 'The rainbow steps and morning light are magical.',
      ),
      Review(
        name: 'Jonathan Harker',
        date: 'September 4, 2025',
        rating: 4,
        comment: 'A steep climb, but completely worth it.',
      ),
    ],
  ),
  HeritagePlace(
    id: 'sultan',
    name: 'Sultan Abdul Samad Building',
    category: 'Traditional Heritage Site',
    state: 'Kuala Lumpur',
    shortDescription: 'A 19th-century Moorish landmark at Merdeka Square.',
    description:
        'Completed in 1897, this Indo-Saracenic masterpiece faces Dataran Merdeka. Its 41-metre copper-domed clock tower witnessed defining moments in Malaysian independence.',
    image: '$assetRoot/sultan_abdul_samad.png',
    distanceKm: 1.5,
    rating: 4.8,
    reviewsCount: 36,
    latitude: 3.1487,
    longitude: 101.6944,
    address: 'Jalan Raja, Dataran Merdeka, Kuala Lumpur',
    hours: 'Mon–Fri · 8:30 AM – 6:00 PM',
    reviews: <Review>[
      Review(
        name: 'Ahmad Zaki',
        date: 'November 20, 2025',
        rating: 5,
        comment: 'The night lighting is spectacular.',
      ),
    ],
  ),
  HeritagePlace(
    id: 'blue',
    name: 'Cheong Fatt Tze Blue Mansion',
    category: 'Traditional Heritage Site',
    state: 'Penang',
    shortDescription:
        'An indigo courtyard mansion blending Chinese and European craft.',
    description:
        'Built in the 1890s, the mansion has 38 rooms, five granite courtyards, Art Nouveau stained glass and UNESCO-recognised conservation.',
    image: '$assetRoot/blue_mansion.png',
    distanceKm: .5,
    rating: 4.9,
    reviewsCount: 54,
    latitude: 5.4215,
    longitude: 100.3353,
    address: '14 Leith Street, George Town, Penang',
    hours: 'Daily · 11:00 AM – 4:00 PM',
  ),
  HeritagePlace(
    id: 'pewter',
    name: 'Royal Selangor Visitor Centre',
    category: 'Local Craft',
    state: 'Kuala Lumpur',
    shortDescription:
        'Pewter museum and artisan workshop celebrating craft since 1885.',
    description:
        'The world’s largest pewter maker welcomes visitors for guided museum tours and hands-on hammering workshops.',
    image: '$assetRoot/pewter_craft.png',
    distanceKm: 6.2,
    rating: 4.7,
    reviewsCount: 29,
    latitude: 3.1963,
    longitude: 101.7239,
    address: 'Setapak Jaya, Kuala Lumpur',
    hours: 'Daily · 9:00 AM – 5:00 PM',
  ),
  HeritagePlace(
    id: 'batik',
    name: 'George Town Batik Artisan Workshop',
    category: 'Local Craft',
    state: 'Penang',
    shortDescription:
        'Hand-painted batik studio preserving wax-resist textile techniques.',
    description:
        'Local artisans demonstrate canting wax drawing and natural botanical dyes on silk and cotton.',
    image: '$assetRoot/batik_artisan.png',
    distanceKm: .9,
    rating: 4.8,
    reviewsCount: 32,
    latitude: 5.4152,
    longitude: 100.3375,
    address: 'Armenian Street, George Town',
    hours: 'Mon–Sat · 10:00 AM – 6:00 PM',
  ),
  HeritagePlace(
    id: 'petaling',
    name: 'Petaling Street Heritage Food Stalls',
    category: 'Local Food',
    state: 'Kuala Lumpur',
    shortDescription:
        'Historic Chinatown stalls, kopitiams and time-tested recipes.',
    description:
        'The vibrant heart of Kuala Lumpur Chinatown has traded since the late 19th century and remains known for claypot rice, roast duck and herbal tea.',
    image: '$assetRoot/petaling_street.png',
    distanceKm: .8,
    rating: 4.7,
    reviewsCount: 58,
    latitude: 3.1438,
    longitude: 101.6968,
    address: 'Jalan Petaling, Kuala Lumpur',
    hours: 'Daily · 10:00 AM – 10:00 PM',
  ),
  HeritagePlace(
    id: 'kopitiam',
    name: 'Keng Pin Heritage Hainanese Kopitiam',
    category: 'Local Food',
    state: 'Penang',
    shortDescription: 'Traditional charcoal kaya toast and coffee since 1950.',
    description:
        'A 70-year-old breakfast spot with marble tables, charcoal toast and the aroma of traditionally roasted coffee.',
    image: '$assetRoot/hainanese_kopitiam.png',
    distanceKm: .3,
    rating: 4.9,
    reviewsCount: 88,
    latitude: 5.4170,
    longitude: 100.3320,
    address: 'George Town, Penang',
    hours: 'Daily · 7:00 AM – 3:00 PM',
  ),
  HeritagePlace(
    id: 'woodcraft',
    name: 'Old Straits Woodcraft & Antique',
    category: 'Local Micro Business',
    state: 'Penang',
    shortDescription:
        'Family-run shop restoring Nyonya furniture and brassware.',
    description:
        'Third-generation craftspeople hand-carve teak panels and restore Straits Chinese Peranakan cabinets.',
    image: '$assetRoot/woodcraft_antique.png',
    distanceKm: 1.2,
    rating: 4.8,
    reviewsCount: 19,
    latitude: 5.4140,
    longitude: 100.3390,
    address: 'George Town, Penang',
    hours: 'Mon–Sat · 10:00 AM – 6:00 PM',
  ),
];

List<PlanDay> createPlanDays() => <PlanDay>[
  PlanDay(
    id: 'day1',
    label: 'Day 1',
    date: DateTime(2026, 8, 20),
    activities: <ActivityItem>[
      ActivityItem(
        id: 'a1',
        time: '09:00 AM',
        title: 'Visit Batu Caves Cathedral Cavern',
        location: 'Gombak, Selangor',
        category: 'Culture',
        latitude: 3.2379,
        longitude: 101.6840,
        notes: 'Climb 272 rainbow steps to Lord Murugan shrine.',
        transit: '35 min drive',
      ),
      ActivityItem(
        id: 'a2',
        time: '12:30 PM',
        title: 'Lunch at Petaling Street Chinatown',
        location: 'Jalan Petaling, Kuala Lumpur',
        category: 'Food',
        latitude: 3.1438,
        longitude: 101.6968,
        notes: 'Try Hainanese chicken rice and traditional iced coffee.',
        transit: '10 min walk',
      ),
      ActivityItem(
        id: 'a3',
        time: '02:30 PM',
        title: 'Sultan Abdul Samad Clock Tower Tour',
        location: 'Dataran Merdeka, KL',
        category: 'Sightseeing',
        latitude: 3.1487,
        longitude: 101.6944,
        notes: 'Explore Merdeka Square colonial architecture.',
      ),
    ],
  ),
  PlanDay(
    id: 'day2',
    label: 'Day 2',
    date: DateTime(2026, 8, 21),
    activities: <ActivityItem>[
      ActivityItem(
        id: 'a4',
        time: '10:00 AM',
        title: 'Explore Cheong Fatt Tze Blue Mansion',
        location: 'George Town, Penang',
        category: 'Culture',
        latitude: 5.4215,
        longitude: 100.3353,
        notes: 'Guided Feng Shui courtyard heritage tour.',
        transit: '15 min drive',
      ),
      ActivityItem(
        id: 'a5',
        time: '01:00 PM',
        title: 'Penang Street Food Tasting',
        location: 'Chulia Street, George Town',
        category: 'Food',
        latitude: 5.4188,
        longitude: 100.3342,
        notes: 'Char kway teow, asam laksa and cendol.',
      ),
    ],
  ),
];

List<Traveller> createTravellers() => <Traveller>[
  Traveller(name: 'Amberly', initials: 'AM', role: 'Admin'),
  Traveller(name: 'Lucas Tan', initials: 'LT', role: 'Member'),
  Traveller(name: 'Amirah S.', initials: 'AS', role: 'Member'),
];

const badges = <BadgeData>[
  BadgeData(
    title: 'Heritage Master',
    description: 'Visited 5+ UNESCO heritage monuments across Malaysia.',
    rarity: 'Legendary',
    xp: 500,
    unlocked: true,
    icon: 0xe3d9,
  ),
  BadgeData(
    title: 'Penang Trail Pioneer',
    description: 'Explored 3 heritage sites in George Town.',
    rarity: 'Epic',
    xp: 300,
    unlocked: true,
    icon: 0xe55b,
  ),
  BadgeData(
    title: 'Local Craft Apprentice',
    description: 'Visit Royal Selangor’s pewter craft centre.',
    rarity: 'Rare',
    xp: 200,
    unlocked: true,
    icon: 0xea23,
  ),
  BadgeData(
    title: 'OSM Contributor',
    description: 'Recommend a new local spot to the community archive.',
    rarity: 'Rare',
    xp: 250,
    unlocked: false,
    icon: 0xe153,
  ),
];

IconData badgeIcon(BadgeData data) => switch (data.title) {
  'Heritage Master' => Icons.workspace_premium_rounded,
  'Penang Trail Pioneer' => Icons.map_rounded,
  'Local Craft Apprentice' => Icons.handyman_rounded,
  _ => Icons.add_location_alt_rounded,
};
