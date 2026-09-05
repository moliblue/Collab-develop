import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleTranslateService {
  GoogleTranslateService({String? apiKey, http.Client? client})
    : apiKey =
          apiKey ?? const String.fromEnvironment('GOOGLE_TRANSLATE_API_KEY'),
      _client = client ?? http.Client();
  final String apiKey;
  final http.Client _client;
  bool get isConfigured => apiKey.isNotEmpty;
  Future<String> translate(
    String text, {
    required String target,
    String source = 'en',
  }) async {
    if (text.trim().isEmpty || target == source) return text;
    if (!isConfigured) {
      throw StateError(
        'Google Translate is not configured. Supply GOOGLE_TRANSLATE_API_KEY with --dart-define.',
      );
    }
    final uri = Uri.parse(
      'https://translation.googleapis.com/language/translate/v2',
    ).replace(queryParameters: <String, String>{'key': apiKey});
    final response = await _client
        .post(
          uri,
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, dynamic>{
            'q': text,
            'source': source,
            'target': target,
            'format': 'text',
          }),
        )
        .timeout(const Duration(seconds: 15));
    final value =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError('Google Translate ${response.statusCode}: $value');
    }
    return ((((value['data'] as Map<String, dynamic>)['translations']
                    as List<dynamic>)
                .first
            as Map<String, dynamic>)['translatedText']
        as String);
  }

  void dispose() => _client.close();
}
