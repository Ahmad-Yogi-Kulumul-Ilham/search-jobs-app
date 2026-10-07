import 'package:http/http.dart' as http;

import 'ai_client.dart';

/// Calls OpenRouter's OpenAI-compatible chat completions, which reach many
/// models (DeepSeek, Llama, Qwen, Mistral, and more) with one key.
class OpenRouterClient implements AiClient {
  OpenRouterClient({
    required this.apiKey,
    required this.modelId,
    http.Client? client,
    this.timeout = const Duration(minutes: 5),
  }) : _client = client ?? http.Client();

  static final _endpoint = Uri.parse(
    'https://openrouter.ai/api/v1/chat/completions',
  );

  final String apiKey;

  /// An OpenRouter model id, such as `deepseek/deepseek-chat`.
  final String modelId;
  final Duration timeout;
  final http.Client _client;

  @override
  AiProvider get provider => AiProvider.openrouter;

  @override
  Future<AiResult> createJson({
    required String system,
    required List<AiPart> content,
    required Map<String, Object?> schema,
    String effort = 'high',
    int maxTokens = 16000,
  }) async {
    return _result(
      await _complete({
        'model': modelId,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': content.expand(_parts).toList()},
        ],
        'response_format': {
          'type': 'json_schema',
          'json_schema': {'name': 'answer', 'strict': true, 'schema': schema},
        },
        // Route only to hosts that honour response_format, so the answer is
        // JSON rather than prose.
        'provider': {'require_parameters': true},
      }),
    );
  }

  @override
  Future<AiResult> searchJson({
    required String system,
    required String prompt,
    int maxSearches = 8,
  }) async => _result(
    await _complete({
      'model': modelId,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': prompt},
      ],
      // OpenRouter runs one search and passes the results to any model.
      'plugins': [
        {'id': 'web', 'max_results': maxSearches},
      ],
    }),
  );

  Future<Map<String, Object?>> _complete(Map<String, Object?> body) =>
      postAiJson(
        _client,
        provider: provider,
        uri: _endpoint,
        timeout: timeout,
        headers: {
          'authorization': 'Bearer $apiKey',
          'x-title': 'Pencari Kerja Remote',
        },
        body: body,
      );

  /// Reads the answer text as JSON, and what OpenRouter billed for it.
  AiResult _result(Map<String, Object?> decoded) {
    final choices = decoded['choices'];
    final choice = choices is List && choices.isNotEmpty ? choices.first : null;
    final message = choice is Map ? choice['message'] : null;
    if (choice is! Map || message is! Map) {
      throw const AiException('Jawaban OpenRouter tidak terbaca.');
    }
    if (choice['finish_reason'] == 'length') {
      throw const AiException(
        'Jawaban OpenRouter terpotong karena terlalu panjang.',
      );
    }
    final refusal = message['refusal'];
    if (refusal is String && refusal.isNotEmpty) {
      throw const AiException(
        'Model menolak memproses permintaan ini. Coba periksa isi CV atau '
        'lowongannya.',
      );
    }
    final json = decodeAnswer(provider, '${message['content'] ?? ''}');

    final usage = decoded['usage'] is Map ? decoded['usage'] as Map : const {};
    return AiResult(
      json: json,
      model: decoded['model'] as String? ?? modelId,
      inputTokens: (usage['prompt_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (usage['completion_tokens'] as num?)?.toInt() ?? 0,
      // OpenRouter reports what it billed, in US dollars of credit.
      costUsd: (usage['cost'] as num?)?.toDouble() ?? 0,
    );
  }
}

List<Map<String, Object?>> _parts(AiPart part) => switch (part) {
  AiText(:final text) => [
    {'type': 'text', 'text': text},
  ],
  // OpenRouter reads PDFs for any model, natively or by parsing them first.
  AiDocument(pdf: _?) => [
    {'type': 'text', 'text': part.title},
    {
      'type': 'file',
      'file': {'filename': part.fileName, 'file_data': part.pdfDataUrl},
    },
  ],
  AiDocument() => [
    {'type': 'text', 'text': part.asText},
  ],
};
