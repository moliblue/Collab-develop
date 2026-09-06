import 'package:flutter_test/flutter_test.dart';
import 'package:findit_my/data_layer/Models/app_models.dart';
import 'package:findit_my/data_layer/Service Managers/Remote Services/heritage_location_normalizer.dart';

void main() {
  test('repairs country-only state and empty address from OSM tags', () {
    final row = <String, dynamic>{'state': 'Malaysia', 'address': ''};
    final tags = <String, String>{
      'addr:street': 'Lebuh Leith',
      'addr:city': 'George Town',
      'addr:state': 'Penang',
    };
    expect(HeritageLocationNormalizer.stateFor(row, tags), 'Penang');
    expect(
      HeritageLocationNormalizer.addressFor(
        row,
        tags,
        name: 'Blue Mansion',
        state: 'Penang',
      ),
      'Lebuh Leith, George Town, Penang, Malaysia',
    );
  });

  test('provides a searchable address when OSM has no address tags', () {
    expect(
      HeritageLocationNormalizer.addressFor(
        {'address': ''},
        const {},
        name: 'Fort Alice',
        state: '',
      ),
      'Fort Alice, Malaysia',
    );
  });

  test('removes same-place duplicates but preserves same name far away', () {
    final places = <HeritagePlace>[
      _place('node/1', 5.4200, 100.3400, address: ''),
      _place('way/2', 5.4202, 100.3402, address: 'George Town, Penang'),
      _place('node/3', 3.1400, 101.6900, address: 'Kuala Lumpur'),
    ];
    final result = HeritageLocationNormalizer.deduplicate(places);
    expect(result, hasLength(2));
    expect(result.first.id, 'way/2');
  });

  test('keeps database identity while filling a missing local image', () {
    final database = _place('way/2', 5.4200, 100.3400, address: 'Penang');
    final local = HeritagePlace(
      id: 'local-card',
      name: 'Heritage Hall',
      category: 'Traditional Heritage Site',
      state: 'Penang',
      shortDescription: 'Curated',
      description: 'Curated description',
      image: 'assets/heritage.png',
      distanceKm: 0,
      rating: 4.8,
      reviewsCount: 10,
      latitude: 5.4200,
      longitude: 100.3400,
      address: 'Penang',
      hours: '',
    );
    final result = HeritageLocationNormalizer.deduplicate([database, local]);
    expect(result.single.id, 'way/2');
    expect(result.single.image, 'assets/heritage.png');
  });
}

HeritagePlace _place(
  String id,
  double lat,
  double lng, {
  required String address,
}) => HeritagePlace(
  id: id,
  osmId: id,
  name: 'Heritage Hall',
  category: 'Traditional Heritage Site',
  state: '',
  shortDescription: address,
  description: '',
  image: '',
  distanceKm: 0,
  rating: 0,
  reviewsCount: 0,
  latitude: lat,
  longitude: lng,
  address: address,
  hours: '',
);
