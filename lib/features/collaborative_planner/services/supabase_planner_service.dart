import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSession {
  const SupabaseSession({required this.accessToken, required this.userId});
  final String accessToken;
  final String userId;
}

class SupabasePlannerService {
  SupabasePlannerService({String? url, String? anonKey, http.Client? client})
    : url = url ?? const String.fromEnvironment('SUPABASE_URL'),
      anonKey = anonKey ?? const String.fromEnvironment('SUPABASE_ANON_KEY'),
      _client = client ?? http.Client();
  final String url;
  final String anonKey;
  final http.Client _client;
  bool get isConfigured => url.startsWith('https://') && anonKey.isNotEmpty;

  Future<SupabaseSession> signInAnonymously() async {
    if (!isConfigured) throw StateError('Supabase is not configured.');
    final client = Supabase.instance.client;
    var session = client.auth.currentSession;
    session ??= (await client.auth.signInAnonymously()).session;
    if (session == null) {
      throw StateError('Supabase did not return an anonymous session.');
    }
    return SupabaseSession(
      accessToken: session.accessToken,
      userId: session.user.id,
    );
  }

  Future<String> _activeAccessToken(String? fallback) async {
    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;
    if (session == null) {
      session = (await auth.signInAnonymously()).session;
    }
    if (session == null) return fallback ?? anonKey;

    final expiresAt = session.expiresAt;
    final refreshBefore = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;
    if (expiresAt != null && expiresAt <= refreshBefore) {
      session = (await auth.refreshSession()).session ?? session;
    }
    return session.accessToken;
  }

  Future<List<Map<String, dynamic>>> select(
    String table, {
    String query = '',
    String? accessToken,
  }) async {
    final value = await _request(
      'GET',
      table,
      query: query,
      accessToken: accessToken,
    );
    return (value as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> insert(
    String table,
    Map<String, dynamic> value, {
    String? accessToken,
  }) async {
    await _request(
      'POST',
      table,
      body: value,
      accessToken: accessToken,
      prefer: 'return=minimal',
    );
  }

  Future<void> upsert(
    String table,
    Map<String, dynamic> value, {
    String onConflict = 'id',
    String? accessToken,
  }) async {
    await _request(
      'POST',
      table,
      query: 'on_conflict=$onConflict',
      body: value,
      accessToken: accessToken,
      prefer: 'resolution=merge-duplicates',
    );
  }

  Future<void> update(
    String table,
    String filter,
    Map<String, dynamic> value, {
    String? accessToken,
  }) async {
    await _request(
      'PATCH',
      table,
      query: filter,
      body: value,
      accessToken: accessToken,
    );
  }

  Future<void> delete(
    String table,
    String filter, {
    String? accessToken,
  }) async {
    await _request('DELETE', table, query: filter, accessToken: accessToken);
  }

  Future<dynamic> rpc(
    String function,
    Map<String, dynamic> parameters, {
    String? accessToken,
  }) => _request(
    'POST',
    'rpc/$function',
    body: parameters,
    accessToken: accessToken,
  );

  Future<dynamic> _request(
    String method,
    String path, {
    String query = '',
    Map<String, dynamic>? body,
    String? accessToken,
    String? prefer,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'Supabase is not configured. Supply SUPABASE_URL and SUPABASE_ANON_KEY with --dart-define.',
      );
    }
    final uri = Uri.parse(
      '$url/rest/v1/$path${query.isEmpty ? '' : '?$query'}',
    );
    // Never keep using the token captured when the repository was created.
    // Supabase may rotate it in the background while the app remains open.
    final token = await _activeAccessToken(accessToken);
    final headers = <String, String>{
      'apikey': anonKey,
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    if (prefer != null) headers['Prefer'] = prefer;
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamed);
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Supabase $path ${response.statusCode}: $text');
    }
    return text.isEmpty ? null : jsonDecode(text);
  }

  void dispose() => _client.close();
}
