import '../models/planner_models.dart';
import '../services/osm_service.dart';
import '../services/osrm_service.dart';
import '../services/supabase_planner_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CollaborativePlannerRepository {
  CollaborativePlannerRepository({
    SupabasePlannerService? supabase,
    OsmService? osm,
    OsrmService? osrm,
  }) : supabase = supabase ?? SupabasePlannerService(),
       osm = osm ?? OsmService(),
       osrm = osrm ?? OsrmService();
  final SupabasePlannerService supabase;
  final OsmService osm;
  final OsrmService osrm;
  SupabaseSession? _session;
  SupabaseSession? get session => _session;

  Future<SupabaseSession?> authenticate() async {
    if (!supabase.isConfigured) return null;
    _session = await supabase.authenticatedSession();
    return _session;
  }

  Future<List<OsmPlace>> searchLocations(
    String query, {
    bool heritageOnly = false,
  }) async {
    final term = query.trim();
    if (term.length < 3) return <OsmPlace>[];
    if (supabase.isConfigured) {
      try {
        final encodedPattern = Uri.encodeQueryComponent('*$term*');
        final rows = await supabase.select(
          'heritage_locations',
          query: 'select=osm_id,name,address,category,latitude,longitude'
              '&is_active=eq.true'
              '&or=(name.ilike.$encodedPattern,address.ilike.$encodedPattern,state.ilike.$encodedPattern)'
              '&order=name.asc&limit=8',
          accessToken: (await authenticate())?.accessToken,
        );
        final catalogueCandidates = rows.map((row) => OsmPlace(
          name: '${row['name']}',
          displayName: '${row['address']}'.trim().isEmpty
              ? '${row['name']}'
              : '${row['name']}, ${row['address']}',
          point: GeoPoint(
            (row['latitude'] as num).toDouble(),
            (row['longitude'] as num).toDouble(),
          ),
          type: '${row['category']}',
        )).toList();
        final catalogueByKey = <String, OsmPlace>{};
        for (final place in catalogueCandidates) {
          final key = '${place.name.trim().toLowerCase()}|'
              '${place.point.latitude.toStringAsFixed(4)}|'
              '${place.point.longitude.toStringAsFixed(4)}';
          catalogueByKey.putIfAbsent(key, () => place);
        }
        final catalogue = catalogueByKey.values.toList();
        if (catalogue.isNotEmpty) return catalogue;
      } catch (_) {
        // Fall through to Nominatim when the catalogue is unavailable.
      }
    }
    return osm.search(term, heritageOnly: heritageOnly);
  }

  Future<RouteLeg> calculateRoute(List<PlannerActivity> activities) =>
      osrm.route(activities.map((a) => a.point).toList());

  Future<List<TravelPlan>> loadPlans({String? accessToken}) async {
    if (!supabase.isConfigured) return <TravelPlan>[];
    final active = accessToken ?? (await authenticate())?.accessToken;
    final rows = await supabase.select(
      'travel_plans',
      query: 'select=*&order=updated_at.desc',
      accessToken: active,
    );
    return rows.map(TravelPlan.fromJson).toList();
  }

  Future<TravelPlan?> loadPlan(String planId, {String? accessToken}) async {
    if (!supabase.isConfigured) return null;
    final active = accessToken ?? (await authenticate())?.accessToken;
    final plans = await supabase.select(
      'travel_plans',
      query: 'select=*&id=eq.$planId&limit=1',
      accessToken: active,
    );
    if (plans.isEmpty) return null;
    final plan = TravelPlan.fromJson(plans.first);
    final dayRows = await supabase.select(
      'plan_days',
      query: 'select=*&plan_id=eq.$planId&order=position.asc,date.asc',
      accessToken: active,
    );
    for (final dayRow in dayRows) {
      final day = PlannerDay(
        id: '${dayRow['id']}',
        date: DateTime.parse('${dayRow['date']}'),
      );
      final cardRows = await supabase.select(
        'itinerary_cards',
        query: 'select=*&day_id=eq.${day.id}&order=position.asc,start_time.asc',
        accessToken: active,
      );
      day.activities.addAll(cardRows.map(PlannerActivity.fromJson));
      plan.days.add(day);
    }
    final memberRows = await supabase.select(
      'plan_members',
      query: 'select=*&plan_id=eq.$planId&order=joined_at.asc',
      accessToken: active,
    );
    plan.members.addAll(memberRows.map(PlannerMember.fromJson));
    return plan;
  }

  RealtimeChannel? watchPlan(void Function() onChange) {
    if (!supabase.isConfigured) return null;
    final channel = Supabase.instance.client
        .channel('planner-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'travel_plans',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'plan_days',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'itinerary_cards',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'plan_members',
          callback: (_) => onChange(),
        );
    channel.subscribe();
    return channel;
  }

  Future<void> unwatchPlan(RealtimeChannel? channel) async {
    if (channel != null) await Supabase.instance.client.removeChannel(channel);
  }

  Future<int> savePlan(
    TravelPlan plan, {
    String? accessToken,
    required bool create,
  }) async {
    if (!supabase.isConfigured) return plan.revision;
    final active = accessToken ?? (await authenticate())?.accessToken;
    if (create) {
      try {
        await supabase.insert(
          'travel_plans',
          plan.toJson(),
          accessToken: active,
        );
      } catch (error) {
        final message = '$error';
        if (!message.contains('23505') && !message.contains('duplicate key')) {
          rethrow;
        }
        await supabase.update(
          'travel_plans',
          'id=eq.${plan.id}',
          plan.toJson(),
          accessToken: active,
        );
      }
    } else {
      final claimed = await supabase.rpc(
        'claim_plan_revision',
        <String, dynamic>{
          'target_plan': plan.id,
          'expected_revision': plan.revision,
        },
        accessToken: active,
      );
      if (claimed == null) {
        throw StateError(
          'This plan changed on another device. It has been reloaded; please retry your change.',
        );
      }
      plan.revision = (claimed as num).toInt();
    }
    for (final day in plan.days) {
      await supabase.upsert('plan_days', <String, dynamic>{
        'id': day.id,
        'plan_id': plan.id,
        'date': day.date.toIso8601String().substring(0, 10),
        'position': plan.days.indexOf(day),
      }, accessToken: active);
      for (final activity in day.activities) {
        await supabase.upsert(
          'itinerary_cards',
          activity.toJson(),
          accessToken: active,
        );
      }
    }
    return plan.revision;
  }

  Future<void> deletePlan(String planId, {String? accessToken}) async {
    await supabase.delete(
      'travel_plans',
      'id=eq.$planId',
      accessToken: accessToken,
    );
  }

  Future<void> deleteDay(String dayId, {String? accessToken}) async {
    await supabase.delete(
      'plan_days',
      'id=eq.$dayId',
      accessToken: accessToken,
    );
  }

  Future<void> deleteCard(String cardId, {String? accessToken}) async {
    await supabase.delete(
      'itinerary_cards',
      'id=eq.$cardId',
      accessToken: accessToken,
    );
  }

  Future<dynamic> joinPlan(String inviteCode, {String? accessToken}) =>
      supabase.rpc('join_travel_plan', <String, dynamic>{
        'invite_pin': inviteCode,
      }, accessToken: accessToken);
  Future<void> updateMemberRole(
    String planId,
    String userId,
    String role, {
    String? accessToken,
  }) async {
    await supabase.update(
      'plan_members',
      'plan_id=eq.$planId&user_id=eq.$userId',
      <String, dynamic>{'role': role},
      accessToken: accessToken,
    );
  }

  Future<void> removeMember(
    String planId,
    String userId, {
    String? accessToken,
  }) async {
    await supabase.delete(
      'plan_members',
      'plan_id=eq.$planId&user_id=eq.$userId',
      accessToken: accessToken,
    );
  }

  Future<void> leavePlan(
    String planId, {
    String? newOwnerId,
    String? accessToken,
  }) async {
    final session = await authenticate();
    if (session == null) throw StateError('Authentication required.');
    await supabase.rpc('leave_travel_plan', <String, dynamic>{
      'target_plan': planId,
      'new_owner': newOwnerId,
    }, accessToken: accessToken ?? session.accessToken);
  }

  void dispose() {
    supabase.dispose();
    osm.dispose();
    osrm.dispose();
  }
}
