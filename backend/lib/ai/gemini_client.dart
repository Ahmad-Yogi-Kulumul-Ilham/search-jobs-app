import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_client.dart';

/// Calls the Gemini API's generateContent with a JSON-schema response.
class GeminiClient implements AiClient {
  GeminiClient({
    required this.apiKey,
    required this.model,
    http.Client? client,
    this.timeout = const Duration(minutes: 5),
  }) : _client = client ?? http.Client();

  final String apiKey;
  final AiModel model;
  final Duration timeout;
  final http.Client _client;

  /// Finish reasons that mean Gemini declined rather than finished.
  static const _blocked = {
    'SAFETY',
    'RECITATION',
    'BLOCKLIST',
    'PROHIBITED_CONTENT',
    'SPII',
  };

  @override
  AiProvider get provider => AiProvider.gemini;

  @override
  Future<AiResult> createJson({
    required String system,
    required List<AiPart> content,
    required Map<String, Object?> schema,
    String effort = 'high',
    int maxTokens = 16000,
  }) async {
    final decoded = await _generate({
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
      'contents': [
        {'role': 'user', 'parts': content.expand(_parts).toList()},
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseJsonSchema': schema,
        // Thinking tokens count against this limit too.
        'maxOutputTokens': maxTokens * 2,
      },
    });
    return _result(decoded);
  }

  @override
  Future<AiResult> searchJson({
    required String system,
    required String prompt,
    int maxSearches = 8,
  }) async {
    // Gemini decides how many searches to run; there is no cap to set.
    final decoded = await _generate({
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'tools': [
        {'google_search': <String, Object?>{}},
      ],
      'generationConfig': {'maxOutputTokens': 32000},
    });
    final candidates = decoded['candidates'];
    final grounding = candidates is List && candidates.isNotEmpty
        ? (candidates.first as Map)['groundingMetadata']
        : null;
    final queries = grounding is Map ? grounding['webSearchQueries'] : null;
    return _result(decoded, searches: queries is List ? queries.length : 0);
  }

  Future<Map<String, Object?>> _generate(Map<String, Object?> body) =>
      postAiJson(
        _client,
        provider: provider,
        uri: Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/'
          '${model.id}:generateContent',
        ),
        timeout: timeout,
        headers: {'x-goog-api-key': apiKey},
        body: body,
      );

  /// Reads the answer text as JSON, and what the request cost.
  AiResult _result(Map<String, Object?> decoded, {int searches = 0}) {
    const refused = AiException(
      'Gemini menolak memproses permintaan ini. Coba periksa isi CV atau '
      'lowongannya.',
    );
    final feedback = decoded['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] != null) throw refused;
    final candidates = decoded['candidates'];
    final candidate = candidates is List && candidates.isNotEmpty
        ? candidates.first
        : null;
    if (candidate is! Map) throw refused;
    final finish = candidate['finishReason'];
    if (finish == 'MAX_TOKENS') {
      throw const AiException(
        'Jawaban Gemini terpotong karena terlalu panjang.',
      );
    }
    if (_blocked.contains(finish)) throw refused;
    final body = candidate['content'];
    final parts = body is Map && body['parts'] is List
        ? body['parts'] as List
        : const [];
    final text = [
      for (final part in parts)
        if (part is Map && part['thought'] != true && part['text'] is String)
          part['text'] as String,
    ].join();
    final json = decodeAnswer(provider, text);

    final usage = decoded['usageMetadata'] is Map
        ? decoded['usageMetadata'] as Map
        : const {};
    int tokens(String key) => (usage[key] as num?)?.toInt() ?? 0;
    final input = tokens('promptTokenCount');
    // Thinking is billed as output.
    final output =
        tokens('candidatesTokenCount') + tokens('thoughtsTokenCount');
    return AiResult(
      json: json,
      model: decoded['modelVersion'] as String? ?? model.id,
      inputTokens: input,
      outputTokens: output,
      costUsd: model.costUsd(input, output) + searches * provider.webSearchUsd,
    );
  }
}

List<Map<String, Object?>> _parts(AiPart part) => switch (part) {
  AiText(:final text) => [
    {'text': text},
  ],
  AiDocument(:final pdf?) => [
    {'text': part.title},
    {
      'inlineData': {'mimeType': 'application/pdf', 'data': base64Encode(pdf)},
    },
  ],
  AiDocument() => [
    {'text': part.asText},
  ],
};
