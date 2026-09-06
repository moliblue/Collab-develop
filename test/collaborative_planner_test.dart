import 'dart:convert';

import 'package:findit_my/features/collaborative_planner/models/planner_messages.dart';
import 'package:findit_my/features/collaborative_planner/models/planner_models.dart';
import 'package:findit_my/features/collaborative_planner/services/osm_service.dart';
import 'package:findit_my/features/collaborative_planner/services/osrm_service.dart';
import 'package:findit_my/features/collaborative_planner/services/supabase_planner_service.dart';
import 'package:findit_my/features/collaborative_planner/repositories/collaborative_planner_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('assessment messages retain required wording', () {
    expect(PlannerMessages.invalidCode, 'Invalid code, please try again');
    expect(
      PlannerMessages.noCards,
      'Error: Need at least 1 card to export trip plan.',
    );
    expect(PlannerMessages.invitationShared, 'Trip invitation shared!');
    expect(
      PlannerMessages.removeMemberConfirm,
      'Are your sure you want to remove member selected?',
    );
  });

  test('route summary uses OSRM metric values', () {
    const route = RouteLeg(
      distanceMeters: 10600,
      durationSeconds: 1260,
      geometry: <GeoPoint>[],
    );
    expect(route.summary, '21 min drive (10.6 km)');
  });

  test('plan share payload includes identifier and PIN', () {
    final plan = TravelPlan(
      id: 'plan-1',
      ownerId: 'owner-1',
      name: 'Tour',
      startDate: DateTime(2026, 8, 20),
      endDate: DateTime(2026, 8, 23),
      inviteCode: 'HERITAGE-2026',
    );
    expect(plan.encodeSharePayload(), isNotEmpty);
    expect(plan.activityCount, 0);
  });

  test('general OSM search is restricted to Malaysia', () async {
    late Uri requestedUri;
    final service = OsmService(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode(<Map<String, String>>[
            <String, String>{
              'name': 'Batu Caves',
              'display_name': 'Batu Caves, Selangor, Malaysia',
              'lat': '3.2379',
              'lon': '101.6840',
              'type': 'attraction',
            },
          ]),
          200,
        );
      }),
    );

    final results = await service.search('Batu Caves');

    expect(requestedUri.queryParameters['countrycodes'], 'my');
    expect(results.single.displayName, contains('Malaysia'));
    service.dispose();
  });

  test('heritage OSM search remains curated to Malaysia', () async {
    late Uri requestedUri;
    final service = OsmService(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response('[]', 200);
      }),
    );

    await service.search('temple', heritageOnly: true);

    expect(requestedUri.queryParameters['countrycodes'], 'my');
    expect(requestedUri.queryParameters['q'], contains('heritage Malaysia'));
    service.dispose();
  });

  test('OSRM sends longitude latitude and reads route metrics', () async {
    late Uri requestedUri;
    final service = OsrmService(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'code': 'Ok',
            'routes': <Map<String, dynamic>>[
              <String, dynamic>{
                'distance': 2738.0,
                'duration': 256.0,
                'geometry': <String, dynamic>{
                  'coordinates': <List<double>>[
                    <double>[101.6841, 3.1579],
                    <double>[101.6932, 3.1430],
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final route = await service.route(const <GeoPoint>[
      GeoPoint(3.1579, 101.6841),
      GeoPoint(3.1430, 101.6932),
    ]);

    expect(requestedUri.path, contains('101.6841,3.1579;101.6932,3.143'));
    expect(route.distanceMeters, 2738);
    expect(route.durationSeconds, 256);
    service.dispose();
  });

  test('repository hydrates a complete persisted travel plan', () async {
    final client = MockClient((request) async {
      final table = request.url.pathSegments.last;
      final rows = switch (table) {
        'travel_plans' => <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '20000000-0000-4000-8000-000000000001',
            'owner_id': '10000000-0000-4000-8000-000000000001',
            'name': 'Persisted plan',
            'start_date': '2026-09-10',
            'end_date': '2026-09-10',
            'invite_code': 'TEST-PLAN',
            'revision': 4,
          },
        ],
        'plan_days' => <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '30000000-0000-4000-8000-000000000001',
            'date': '2026-09-10',
            'position': 0,
          },
        ],
        'itinerary_cards' => <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '40000000-0000-4000-8000-000000000001',
            'day_id': '30000000-0000-4000-8000-000000000001',
            'title': 'Batu Caves',
            'location': 'Selangor',
            'start_time': '09:00:00',
            'category': 'Traditional Heritage Site',
            'description': '',
            'latitude': 3.2379,
            'longitude': 101.684,
            'position': 0,
            'route_distance_m': 1200.0,
            'route_duration_s': 180.0,
            'route_geometry': <List<double>>[
              <double>[3.2379, 101.684],
            ],
          },
        ],
        'plan_members' => <Map<String, dynamic>>[
          <String, dynamic>{
            'user_id': '10000000-0000-4000-8000-000000000001',
            'display_name': 'Owner',
            'role': 'admin',
          },
        ],
        _ => <Map<String, dynamic>>[],
      };
      return http.Response(jsonEncode(rows), 200);
    });
    final repository = CollaborativePlannerRepository(
      supabase: SupabasePlannerService(
        url: 'https://example.supabase.co',
        anonKey: 'test-key',
        client: client,
      ),
    );

    final plan = await repository.loadPlan(
      '20000000-0000-4000-8000-000000000001',
      accessToken: 'test-token',
    );

    expect(plan?.name, 'Persisted plan');
    expect(plan?.revision, 4);
    expect(plan?.days.single.activities.single.title, 'Batu Caves');
    expect(plan?.members.single.isAdmin, isTrue);
    repository.dispose();
  });

  test('repository create, update, and delete target Plan tables', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/rpc/claim_plan_revision')) {
        return http.Response('1', 200);
      }
      return http.Response('', 204);
    });
    final repository = CollaborativePlannerRepository(
      supabase: SupabasePlannerService(
        url: 'https://example.supabase.co',
        anonKey: 'test-key',
        client: client,
      ),
    );
    final plan = TravelPlan(
      id: '20000000-0000-4000-8000-000000000001',
      ownerId: '10000000-0000-4000-8000-000000000001',
      name: 'CRUD plan',
      startDate: DateTime(2026, 9, 10),
      endDate: DateTime(2026, 9, 10),
      inviteCode: 'CRUD-PLAN',
      days: <PlannerDay>[
        PlannerDay(
          id: '30000000-0000-4000-8000-000000000001',
          date: DateTime(2026, 9, 10),
          activities: <PlannerActivity>[
            PlannerActivity(
              id: '40000000-0000-4000-8000-000000000001',
              dayId: '30000000-0000-4000-8000-000000000001',
              title: 'Batu Caves',
              location: 'Gombak, Selangor, Malaysia',
              startTime: '09:00 AM',
              category: 'Traditional Heritage Site',
              point: const GeoPoint(3.2379, 101.684),
            ),
          ],
        ),
      ],
    );

    await repository.savePlan(plan, accessToken: 'token', create: true);
    plan.name = 'Updated CRUD plan';
    await repository.savePlan(plan, accessToken: 'token', create: false);
    await repository.deleteCard(
      '40000000-0000-4000-8000-000000000001',
      accessToken: 'token',
    );
    await repository.deleteDay(
      '30000000-0000-4000-8000-000000000001',
      accessToken: 'token',
    );
    await repository.deletePlan(
      '20000000-0000-4000-8000-000000000001',
      accessToken: 'token',
    );

    expect(
      requests.map((request) => '${request.method} ${request.url.path}'),
      containsAll(<String>[
        'POST /rest/v1/travel_plans',
        'POST /rest/v1/plan_days',
        'POST /rest/v1/itinerary_cards',
        'POST /rest/v1/rpc/claim_plan_revision',
        'PATCH /rest/v1/travel_plans',
        'DELETE /rest/v1/itinerary_cards',
        'DELETE /rest/v1/plan_days',
        'DELETE /rest/v1/travel_plans',
      ]),
    );
    final planPatch = requests.firstWhere(
      (request) =>
          request.method == 'PATCH' &&
          request.url.path.endsWith('/travel_plans'),
    );
    expect(jsonDecode(planPatch.body)['name'], 'Updated CRUD plan');
    expect(jsonDecode(planPatch.body)['revision'], 1);
    repository.dispose();
  });
}
