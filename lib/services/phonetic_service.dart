import 'dart:convert';
import 'dart:io';

class PhoneticService {
  PhoneticService._();

  static final PhoneticService instance = PhoneticService._();

  Future<String?> fetchPhonetic(String word) async {
    final String normalizedWord = word.trim();
    if (normalizedWord.isEmpty) {
      return null;
    }

    final HttpClient client = HttpClient();
    try {
      final Uri uri = Uri.parse(
        'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(normalizedWord)}',
      );
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final String rawBody = await utf8.decodeStream(response);
      final dynamic decoded = jsonDecode(rawBody);
      if (decoded is! List || decoded.isEmpty) {
        return null;
      }

      for (final dynamic entry in decoded) {
        if (entry is! Map<String, dynamic>) {
          continue;
        }

        final dynamic phonetics = entry['phonetics'];
        if (phonetics is List) {
          for (final dynamic item in phonetics) {
            if (item is! Map<String, dynamic>) {
              continue;
            }

            final String? text = item['text']?.toString().trim();
            if (text != null && text.isNotEmpty) {
              return text;
            }
          }
        }

        final String? rootPhonetic = entry['phonetic']?.toString().trim();
        if (rootPhonetic != null && rootPhonetic.isNotEmpty) {
          return rootPhonetic;
        }
      }

      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
