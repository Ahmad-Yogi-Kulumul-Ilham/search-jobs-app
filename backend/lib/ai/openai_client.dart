import 'package:http/http.dart' as http;

import 'ai_client.dart';

/// Calls the OpenAI Responses API with a JSON-schema answer format.
class OpenAiClient implements AiClient {
  OpenAiClient({
    required this.apiKey,
    required this.model,
    http.Client? client,
    this.timeout = const Duration(minutes: 5),
  }) : _client = client ?? http.Client();

  static final _endpoint = Uri.parse('https://api.openai.com/v1/responses');

  final String apiKey;
  final AiModel model;
  final Duration timeout;
  final http.Client _client;

  @override
  AiProvider get provider => AiProvider.openai;

  @override
  Future<AiResult> createJson({
    required String system,
    required List<AiPart> content,
    required Map<String, Object?> schema,
    String effort = 'high',
    int maxTokens = 16000,
  }) async {
    final decoded = await postAiJson(
      _client,
      provider: provider,
      uri: _endpoint,
      timeout: timeout,
      headers: {'authorization': 'Bearer $apiKey'},
      body: {
        'model': model.id,
        'instructions': system,
        'input': [
          {'role': 'user', 'content': content.expand(_parts).toList()},
        ],
        'text': {
          'format': {
            'type': 'json_schema',
            'name': 'answer',
            'schema': schema,
            'strict': true,
          },
        },
        // Reasoning tokens count against this limit too.
        'max_output_tokens': maxTokens * 2,
        // Do not keep the CV on OpenAI's side for later retrieval.
        'store': false,
      },
    );

    return _result(decoded);
  }

  @override
  Future<AiResult> searchJson({
    required String system,
    required String prompt,
    int maxSearches = 8,
  }) async {
    final decoded = await postAiJson(
      _client,
      provider: provider,
      uri: _endpoint,
      timeout: timeout,
      headers: {'authorization': 'Bearer $apiKey'},
      body: {
        'model': model.id,
        'instructions': system,
        'input': prompt,
        'tools': [
          {'type': 'web_search'},
        ],
        'max_tool_calls': maxSearches,
        'max_output_tokens': 32000,
        'store': false,
      },
    );
    final searches = [
      for (final item
          in decoded['output'] is List ? decoded['output'] as List : const [])
        if (item is Map && item['type'] == 'web_search_call') item,
    ].length;
    return _result(decoded, searches: searches);
  }

  /// Reads the answer text as JSON, and what the request cost.
  AiResult _result(Map<String, Object?> decoded, {int searches = 0}) {
    if (decoded['status'] == 'incomplete') {
      final details = decoded['incomplete_details'];
      final reason = details is Map ? details['reason'] : null;
      throw AiException(
        reason == 'max_output_tokens'
            ? 'Jawaban ChatGPT terpotong karena terlalu panjang.'
            : 'ChatGPT menolak memproses permintaan ini. Coba periksa isi CV '
                  'atau lowongannya.',
      );
    }
    final text = StringBuffer();
    for (final item
        in decoded['output'] is List ? decoded['output'] as List : const []) {
      if (item is! Map || item['type'] != 'message') continue;
      for (final part
          in item['content'] is List ? item['content'] as List : const []) {
        if (part is! Map) continue;
        if (part['type'] == 'refusal') {
          throw const AiException(
            'ChatGPT menolak memproses permintaan ini. Coba periksa isi CV '
            'atau lowongannya.',
          );
        }
        if (part['type'] == 'output_text') text.write(part['text']);
      }
    }
    final json = decodeAnswer(provider, text.toString());

    final usage = decoded['usage'] is Map ? decoded['usage'] as Map : const {};
    final input = (usage['input_tokens'] as num?)?.toInt() ?? 0;
    final output = (usage['output_tokens'] as num?)?.toInt() ?? 0;
    return AiResult(
      json: json,
      model: decoded['model'] as String? ?? model.id,
      inputTokens: input,
      outputTokens: output,
      costUsd: model.costUsd(input, output) + searches * provider.webSearchUsd,
    );
  }
}

List<Map<String, Object?>> _parts(AiPart part) => switch (part) {
  AiText(:final text) => [
    {'type': 'input_text', 'text': text},
  ],
  AiDocument(pdf: _?) => [
    {'type': 'input_text', 'text': part.title},
    {
      'type': 'input_file',
      'filename': part.fileName,
      'file_data': part.pdfDataUrl,
    },
  ],
  AiDocument() => [
    {'type': 'input_text', 'text': part.asText},
  ],
};
