import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// The Claude models the user can pick for reviews, with their prices.
enum AiModel {
  opus(
    id: 'claude-opus-5-5',
    label: 'Claude Opus 5.5 (paling teliti)',
    inputUsdPerMillion: 4,
    outputUsdPerMillion: 20,
    supportsEffort: true,
    supportsFallbacks: true,
  ),
  sonnet(
    id: 'claude-sonnet-5-5',
    label: 'Claude Sonnet 5.5 (seimbang, lebih hemat)',
    inputUsdPerMillion: 2,
    outputUsdPerMillion: 10,
    supportsEffort: true,
    supportsFallbacks: true,
  ),
  haiku(
    id: 'claude-haiku-4-5',
    label: 'Claude Haiku 4.5 (paling hemat)',
    inputUsdPerMillion: 1,
    outputUsdPerMillion: 5,
    supportsEffort: false,
    supportsFallbacks: false,
  );

  const AiModel({
    required this.id,
    required this.label,
    required this.inputUsdPerMillion,
    required this.outputUsdPerMillion,
    required this.supportsEffort,
    required this.supportsFallbacks,
  });

  final String id;
  final String label;
  final double inputUsdPerMillion;
  final double outputUsdPerMillion;

  /// Haiku 4.5 rejects `output_config.effort`.
  final bool supportsEffort;

  /// Whether the request may opt into server-side refusal fallbacks.
  final bool supportsFallbacks;

  static AiModel byName(String? name) =>
      values.where((model) => model.name == name).firstOrNull ?? opus;
}

/// A failed request, with a message fit to show the user.
class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A structured answer from Claude and what it cost.
class AiResult {
  const AiResult({
    required this.json,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.costUsd,
  });

  final Map<String, Object?> json;

  /// The model that actually answered; a fallback may differ from the one
  /// requested.
  final String model;
  final int inputTokens;
  final int outputTokens;
  final double costUsd;
}

/// Calls the Claude Messages API over HTTP. Dart has no official Anthropic
/// SDK, so this follows the documented REST shape.
class ClaudeClient {
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

  /// Sends one request whose answer must match [schema], a JSON schema in
  /// the subset structured outputs accept (every object needs
  /// `additionalProperties: false`).
  Future<AiResult> createJson({
    required String system,
    required List<Map<String, Object?>> content,
    required Map<String, Object?> schema,
    String effort = 'high',
    int maxTokens = 16000,
  }) async {
    final body = <String, Object?>{
      'model': model.id,
      'max_tokens': maxTokens,
      'system': system,
      'messages': [
        {'role': 'user', 'content': content},
      ],
      'output_config': {
        if (model.supportsEffort) 'effort': effort,
        'format': {'type': 'json_schema', 'schema': schema},
      },
      // If a safety classifier declines, the API retries on its recommended
      // fallback model within the same call.
      if (model.supportsFallbacks) 'fallbacks': 'default',
    };
    final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              if (model.supportsFallbacks)
                'anthropic-beta': 'server-side-fallback-2026-07-01',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException(
        'Claude tidak menjawab dalam 5 menit. Coba lagi.',
      );
    } on SocketException {
      throw const AiException(
        'Tidak bisa terhubung ke Claude. Periksa internet.',
      );
    } on http.ClientException {
      throw const AiException(
        'Tidak bisa terhubung ke Claude. Periksa internet.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw AiException(
        'Jawaban Claude tidak terbaca (HTTP ${response.statusCode}).',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const AiException('Jawaban Claude tidak terbaca.');
    }
    if (response.statusCode != 200) {
      throw AiException(_describeError(response.statusCode, decoded));
    }

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
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const AiException('Jawaban Claude tidak sesuai format.');
    }
    if (json is! Map<String, Object?>) {
      throw const AiException('Jawaban Claude tidak sesuai format.');
    }

    final usage = decoded['usage'] is Map ? decoded['usage'] as Map : const {};
    int tokens(String key) => (usage[key] as num?)?.toInt() ?? 0;
    final input =
        tokens('input_tokens') +
        tokens('cache_creation_input_tokens') +
        tokens('cache_read_input_tokens');
    final output = tokens('output_tokens');
    final answeredBy = decoded['model'] as String? ?? model.id;
    // A fallback bills at its own rates; those are not tracked here, so the
    // cost is estimated at the requested model's rates.
    return AiResult(
      json: json,
      model: answeredBy,
      inputTokens: input,
      outputTokens: output,
      costUsd:
          input / 1e6 * model.inputUsdPerMillion +
          output / 1e6 * model.outputUsdPerMillion,
    );
  }
}

String _describeError(int status, Map<String, Object?> body) {
  final error = body['error'];
  final detail = error is Map ? '${error['message'] ?? ''}' : '';
  return switch (status) {
    401 => 'API key ditolak. Periksa kembali API key di Pengaturan.',
    403 => 'API key ini tidak punya izin untuk model tersebut.',
    429 =>
      'Terlalu banyak permintaan atau saldo/limit API habis. Coba lagi '
          'nanti, atau periksa saldo di console.anthropic.com.',
    529 || 503 || 502 || 500 =>
      'Server Claude sedang sibuk (HTTP $status). Coba lagi sebentar lagi.',
    _ =>
      'Permintaan ke Claude gagal (HTTP $status)'
          '${detail.isEmpty ? '' : ': $detail'}',
  };
}
