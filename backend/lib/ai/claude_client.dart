import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_client.dart';

/// Calls the Claude Messages API over HTTP. Dart has no official Anthropic
/// SDK, so this follows the documented REST shape.
class ClaudeClient implements AiClient {
  ClaudeClient({
    required this.apiKey,
    required this.model,
    http.Client? client,
    this.timeout = const Duration(minutes: 5),
  }) : _client = client ?? http.Client();

  static final _endpoint = Uri.parse('https://api.anthropic.com/v1/messages');

  final String apiKey;
  final AiModel model;
  final Duration timeout;
  final http.Client _client;

  @override
  AiProvider get provider => AiProvider.anthropic;

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
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        if (model.supportsFallbacks)
          'anthropic-beta': 'server-side-fallback-2026-07-01',
      },
      body: {
        'model': model.id,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': content.map(_block).toList()},
        ],
        'output_config': {
          if (model.supportsEffort) 'effort': effort,
          'format': {'type': 'json_schema', 'schema': schema},
        },
        // If a safety classifier declines, the API retries on its
        // recommended fallback model within the same call.
        if (model.supportsFallbacks) 'fallbacks': 'default',
      },
    );

    final stopReason = decoded['stop_reason'];
    if (stopReason == 'refusal') {
      throw const AiException(
        'Claude menolak memproses permintaan ini. Coba periksa isi CV atau '
        'lowongannya.',
      );
    }
    if (stopReason == 'max_tokens') {
      throw const AiException(
        'Jawaban Claude terpotong karena terlalu panjang.',
      );
    }
    final text = [
      for (final block
          in decoded['content'] is List ? decoded['content'] as List : const [])
        if (block is Map && block['type'] == 'text') block['text'] as String,
    ].join();
    final json = decodeAnswer(provider, text);

    final usage = decoded['usage'] is Map ? decoded['usage'] as Map : const {};
    int tokens(String key) => (usage[key] as num?)?.toInt() ?? 0;
    final input =
        tokens('input_tokens') +
        tokens('cache_creation_input_tokens') +
        tokens('cache_read_input_tokens');
    final output = tokens('output_tokens');
    // A fallback bills at its own rates; those are not tracked here, so the
    // cost is estimated at the requested model's rates.
    return AiResult(
      json: json,
      model: decoded['model'] as String? ?? model.id,
      inputTokens: input,
      outputTokens: output,
      costUsd: model.costUsd(input, output),
    );
  }

  @override
  Future<AiResult> searchJson({
    required String system,
    required String prompt,
    int maxSearches = 8,
  }) async {
    final messages = <Map<String, Object?>>[
      {'role': 'user', 'content': prompt},
    ];
    var input = 0;
    var output = 0;
    var searches = 0;
    // A long search turn can pause; sending it back unchanged resumes it.
    for (var turn = 0; turn < 4; turn++) {
      final decoded = await postAiJson(
        _client,
        provider: provider,
        uri: _endpoint,
        timeout: timeout,
        headers: {'x-api-key': apiKey, 'anthropic-version': '2023-06-01'},
        body: {
          'model': model.id,
          'max_tokens': 16000,
          'system': system,
          'messages': messages,
          'tools': [
            {
              'type': 'web_search_20250305',
              'name': 'web_search',
              'max_uses': maxSearches,
            },
          ],
        },
      );
      final usage = decoded['usage'] is Map
          ? decoded['usage'] as Map
          : const {};
      int tokens(String key) => (usage[key] as num?)?.toInt() ?? 0;
      input +=
          tokens('input_tokens') +
          tokens('cache_creation_input_tokens') +
          tokens('cache_read_input_tokens');
      output += tokens('output_tokens');
      final server = usage['server_tool_use'];
      searches += server is Map
          ? (server['web_search_requests'] as num?)?.toInt() ?? 0
          : 0;
      final blocks = decoded['content'] is List
          ? decoded['content'] as List
          : const [];

      switch (decoded['stop_reason']) {
        case 'pause_turn':
          messages.add({'role': 'assistant', 'content': blocks});
          continue;
        case 'refusal':
          throw const AiException('Claude menolak memproses permintaan ini.');
        case 'max_tokens':
          throw const AiException(
            'Jawaban Claude terpotong karena terlalu panjang.',
          );
      }
      // The answer is the text after the last search result; earlier text
      // narrates the searching.
      final lastResult = blocks.lastIndexWhere(
        (block) => block is Map && block['type'] == 'web_search_tool_result',
      );
      final text = [
        for (final block in blocks.skip(lastResult + 1))
          if (block is Map && block['type'] == 'text') block['text'] as String,
      ].join();
      return AiResult(
        json: decodeAnswer(provider, text),
        model: decoded['model'] as String? ?? model.id,
        inputTokens: input,
        outputTokens: output,
        costUsd:
            model.costUsd(input, output) + searches * provider.webSearchUsd,
      );
    }
    throw const AiException('Claude terlalu lama mencari. Coba lagi.');
  }
}

Map<String, Object?> _block(AiPart part) => switch (part) {
  AiText(:final text) => {'type': 'text', 'text': text},
  AiDocument(:final title, :final pdf?) => {
    'type': 'document',
    'title': title,
    'source': {
      'type': 'base64',
      'media_type': 'application/pdf',
      'data': base64Encode(pdf),
    },
  },
  AiDocument(:final title, :final text) => {
    'type': 'document',
    'title': title,
    'source': {'type': 'text', 'media_type': 'text/plain', 'data': text},
  },
};
