import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// The companies whose models can run the AI features. Each needs its own
/// API key, billed per use.
enum AiProvider {
  anthropic(
    label: 'Claude (Anthropic)',
    shortName: 'Claude',
    keyPrefix: 'sk-ant-',
    consoleUrl: 'console.anthropic.com',
  ),
  openai(
    label: 'ChatGPT (OpenAI)',
    shortName: 'ChatGPT',
    keyPrefix: 'sk-',
    consoleUrl: 'platform.openai.com',
  ),
  gemini(
    label: 'Gemini (Google)',
    shortName: 'Gemini',
    keyPrefix: 'AIza',
    consoleUrl: 'aistudio.google.com',
  ),
  openrouter(
    label: 'OpenRouter (DeepSeek, Llama, Qwen, Mistral, dll.)',
    shortName: 'OpenRouter',
    keyPrefix: 'sk-or-',
    consoleUrl: 'openrouter.ai',
  );

  const AiProvider({
    required this.label,
    required this.shortName,
    required this.keyPrefix,
    required this.consoleUrl,
  });

  final String label;

  /// Used in messages, such as "Gemini sedang membaca CV".
  final String shortName;

  /// How this provider's API keys start, to catch a key pasted for the
  /// wrong provider.
  final String keyPrefix;

  /// Where the user creates a key and tops up credit.
  final String consoleUrl;

  /// What one web search costs on top of tokens, in US dollars, from each
  /// pricing page in October 2026. Gemini's first 5,000 searches a month
  /// are free, so this overstates it until then; OpenRouter reports the
  /// search fee in its own bill.
  double get webSearchUsd => switch (this) {
    anthropic || openai => 0.01,
    gemini => 0.014,
    openrouter => 0,
  };

  List<AiModel> get models => [
    for (final model in AiModel.values)
      if (model.provider == this) model,
  ];

  /// The model picked when the user switches to this provider: the
  /// balanced one, so switching does not land on the priciest.
  AiModel get defaultModel => switch (this) {
    anthropic => AiModel.opus,
    openai => AiModel.gpt61Sol,
    gemini => AiModel.gemini38Flash,
    openrouter => AiModel.openRouter,
  };
}

/// The models the user can pick, with their prices per million tokens.
/// Prices are from each provider's pricing page in October 2026.
enum AiModel {
  opus(
    provider: AiProvider.anthropic,
    id: 'claude-opus-5-5',
    label: 'Claude Opus 5.5 (paling teliti)',
    inputUsdPerMillion: 4,
    outputUsdPerMillion: 20,
    supportsEffort: true,
    supportsFallbacks: true,
  ),
  sonnet(
    provider: AiProvider.anthropic,
    id: 'claude-sonnet-5-5',
    label: 'Claude Sonnet 5.5 (seimbang, lebih hemat)',
    inputUsdPerMillion: 2,
    outputUsdPerMillion: 10,
    supportsEffort: true,
    supportsFallbacks: true,
  ),
  haiku(
    provider: AiProvider.anthropic,
    id: 'claude-haiku-4-5',
    label: 'Claude Haiku 4.5 (paling hemat)',
    inputUsdPerMillion: 1,
    outputUsdPerMillion: 5,
  ),
  gpt6Astra(
    provider: AiProvider.openai,
    id: 'gpt-6-astra',
    label: 'GPT-6 Astra (paling teliti, mahal)',
    inputUsdPerMillion: 10,
    outputUsdPerMillion: 50,
  ),
  gpt61Sol(
    provider: AiProvider.openai,
    id: 'gpt-6.1-sol',
    label: 'GPT-6.1 Sol (seimbang)',
    inputUsdPerMillion: 2,
    outputUsdPerMillion: 10,
  ),
  gpt6Luna(
    provider: AiProvider.openai,
    id: 'gpt-6-luna',
    label: 'GPT-6 Luna (paling hemat)',
    inputUsdPerMillion: 0.1,
    outputUsdPerMillion: 0.5,
  ),
  gemini31Pro(
    provider: AiProvider.gemini,
    id: 'gemini-3.1-pro-preview',
    label: 'Gemini 3.1 Pro (paling teliti, versi preview)',
    inputUsdPerMillion: 2,
    outputUsdPerMillion: 12,
  ),
  // Introductory price until 31 December 2026; it doubles after that.
  gemini38Flash(
    provider: AiProvider.gemini,
    id: 'gemini-3.8-flash',
    label: 'Gemini 3.8 Flash (seimbang)',
    inputUsdPerMillion: 0.75,
    outputUsdPerMillion: 3.75,
  ),
  gemini31FlashLite(
    provider: AiProvider.gemini,
    id: 'gemini-3.1-flash-lite',
    label: 'Gemini 3.1 Flash-Lite (paling hemat)',
    inputUsdPerMillion: 0.25,
    outputUsdPerMillion: 1.5,
  ),

  /// Any model on OpenRouter; the user types its id, and the cost comes
  /// from OpenRouter's own bill for each request.
  openRouter(
    provider: AiProvider.openrouter,
    id: '',
    label: 'Model pilihan sendiri (isi ID model)',
    inputUsdPerMillion: 0,
    outputUsdPerMillion: 0,
  );

  const AiModel({
    required this.provider,
    required this.id,
    required this.label,
    required this.inputUsdPerMillion,
    required this.outputUsdPerMillion,
    this.supportsEffort = false,
    this.supportsFallbacks = false,
  });

  final AiProvider provider;
  final String id;
  final String label;
  final double inputUsdPerMillion;
  final double outputUsdPerMillion;

  /// Claude Haiku 4.5 rejects `output_config.effort`; other providers do not
  /// take it at all.
  final bool supportsEffort;

  /// Whether a Claude request may opt into server-side refusal fallbacks.
  final bool supportsFallbacks;

  static AiModel byName(String? name) =>
      values.where((model) => model.name == name).firstOrNull ?? opus;

  double costUsd(int inputTokens, int outputTokens) =>
      inputTokens / 1e6 * inputUsdPerMillion +
      outputTokens / 1e6 * outputUsdPerMillion;
}

/// A failed request, with a message fit to show the user.
class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A structured answer from a model and what it cost.
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

/// One piece of a request, in a form every provider can be given.
sealed class AiPart {
  const AiPart();
}

class AiText extends AiPart {
  const AiText(this.text);

  final String text;
}

/// A titled document: plain text, or a PDF passed as is for the model to
/// read.
class AiDocument extends AiPart {
  const AiDocument.text({required this.title, required String this.text})
    : pdf = null,
      fileName = null;

  const AiDocument.pdf({
    required this.title,
    required Uint8List this.pdf,
    required String this.fileName,
  }) : text = null;

  final String title;
  final String? text;
  final Uint8List? pdf;
  final String? fileName;

  /// The title and, for a text document, its contents, for providers that
  /// take documents as plain text.
  String get asText => text == null ? title : '$title\n\n$text';

  /// The PDF as a `data:` URL, as OpenAI and OpenRouter take files.
  String get pdfDataUrl => 'data:application/pdf;base64,${base64Encode(pdf!)}';
}

/// A model that answers with JSON matching a schema.
abstract class AiClient {
  AiProvider get provider;

  /// Sends one request whose answer must match [schema], a JSON schema in
  /// the subset all providers accept: every object lists all its properties
  /// as required and sets `additionalProperties: false`. [effort] is used
  /// only by models that take it.
  Future<AiResult> createJson({
    required String system,
    required List<AiPart> content,
    required Map<String, Object?> schema,
    String effort = 'high',
    int maxTokens = 16000,
  });

  /// Lets the model search the web, up to about [maxSearches] times, and
  /// reads its final answer as a JSON object. Providers do not reliably
  /// combine web search with schema-enforced output, so [system] must
  /// describe the JSON shape and the answer is parsed leniently.
  Future<AiResult> searchJson({
    required String system,
    required String prompt,
    int maxSearches = 8,
  });
}

/// Posts [body] as JSON and returns the decoded answer, turning network and
/// HTTP failures into an [AiException] that names [provider].
Future<Map<String, Object?>> postAiJson(
  http.Client client, {
  required AiProvider provider,
  required Uri uri,
  required Map<String, String> headers,
  required Map<String, Object?> body,
  required Duration timeout,
}) async {
  final name = provider.shortName;
  final http.Response response;
  try {
    response = await client
        .post(
          uri,
          headers: {'content-type': 'application/json', ...headers},
          body: jsonEncode(body),
        )
        .timeout(timeout);
  } on TimeoutException {
    throw AiException(
      '$name tidak menjawab dalam ${timeout.inMinutes} menit. Coba lagi.',
    );
  } on SocketException {
    throw AiException('Tidak bisa terhubung ke $name. Periksa internet.');
  } on http.ClientException {
    throw AiException('Tidak bisa terhubung ke $name. Periksa internet.');
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(response.bodyBytes));
  } on FormatException {
    throw AiException(
      'Jawaban $name tidak terbaca (HTTP ${response.statusCode}).',
    );
  }
  if (decoded is! Map<String, Object?>) {
    throw AiException('Jawaban $name tidak terbaca.');
  }
  if (response.statusCode != 200) {
    final error = decoded['error'];
    final detail = error is Map ? '${error['message'] ?? ''}'.trim() : '';
    throw AiException(_describeError(provider, response.statusCode, detail));
  }
  return decoded;
}

/// Reads the model's answer text as a JSON object. Models without native
/// structured output sometimes wrap it in a Markdown code fence or put a
/// sentence before it, so the outermost braces are tried last.
Map<String, Object?> decodeAnswer(AiProvider provider, String text) {
  var body = text.trim();
  final fenced = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$').firstMatch(body);
  if (fenced != null) body = fenced.group(1)!;
  final start = body.indexOf('{');
  final end = body.lastIndexOf('}');
  for (final candidate in [
    body,
    if (start >= 0 && end > start) body.substring(start, end + 1),
  ]) {
    try {
      final json = jsonDecode(candidate);
      if (json is Map<String, Object?>) return json;
    } on FormatException {
      // Try the next candidate, then report below.
    }
  }
  throw AiException('Jawaban ${provider.shortName} tidak sesuai format.');
}

String _describeError(AiProvider provider, int status, String detail) {
  final name = provider.shortName;
  // Gemini answers a bad key with 400 rather than 401.
  if (status == 401 || (status == 400 && detail.contains('API key'))) {
    return 'API key ditolak. Periksa kembali API key $name di Pengaturan.';
  }
  return switch (status) {
    402 =>
      'Saldo $name habis. Isi saldo di ${provider.consoleUrl}, lalu coba '
          'lagi.',
    403 => 'API key ini tidak punya izin untuk model tersebut.',
    404
        when provider == AiProvider.openrouter &&
            detail.toLowerCase().contains('parameter') =>
      'Model ini tidak bisa menjawab dalam format terstruktur (JSON). Pilih '
          'model lain di Pengaturan.',
    404 => 'Model tidak ditemukan. Periksa pilihan model di Pengaturan.',
    429 =>
      'Terlalu banyak permintaan atau saldo/limit API habis. Coba lagi '
          'nanti, atau periksa saldo di ${provider.consoleUrl}.',
    529 ||
    503 ||
    502 ||
    500 => 'Server $name sedang sibuk (HTTP $status). Coba lagi sebentar lagi.',
    _ =>
      'Permintaan ke $name gagal (HTTP $status)'
          '${detail.isEmpty ? '' : ': $detail'}',
  };
}
