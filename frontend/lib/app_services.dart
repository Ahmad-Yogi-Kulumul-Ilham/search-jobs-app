import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:search_jobs_backend/search_jobs_backend.dart';

import 'file_picking.dart';
import 'form_browser.dart';
import 'notifier.dart';
import 'secret_box.dart';

/// The backend objects every page shares. It notifies its listeners whenever
/// stored data changes, so each page can reload what it shows.
class AppServices extends ChangeNotifier {
  AppServices({
    required this.database,
    required this.repository,
    Notifier? notifier,
    SecretBox? secretBox,
    this.aiHttpClient,
    this.chooseCvFile = pickCvFile,
    this.createBrowser = WebviewFormBrowser.new,
    DateTime Function()? clock,
  }) : notifier = notifier ?? RecordingNotifier(),
       secretBox = secretBox ?? PlainSecretBox(),
       _clock = clock ?? DateTime.now,
       announcer = Announcer(database) {
    rates = repository.exchangeRates();
  }

  static const _notificationsKey = 'notifications_enabled';
  static const _modelKey = 'ai_model';
  static const _openRouterModelKey = 'openrouter_model';

  /// Where each provider's encrypted key is stored. The Anthropic name
  /// predates the other providers and is kept so saved keys still work.
  static const _apiKeyKeys = {
    AiProvider.anthropic: 'anthropic_api_key_sealed',
    AiProvider.openai: 'openai_api_key_sealed',
    AiProvider.gemini: 'gemini_api_key_sealed',
    AiProvider.openrouter: 'openrouter_api_key_sealed',
  };

  final AppDatabase database;
  final JobRepository repository;
  final Notifier notifier;
  final SecretBox secretBox;
  final Announcer announcer;

  /// Used for AI requests; null uses a default client.
  final http.Client? aiHttpClient;
  final DateTime Function() _clock;

  /// Asks the user for a CV file.
  final Future<PickedFile?> Function() chooseCvFile;

  /// Makes the in-app browser for application forms.
  final FormBrowser Function() createBrowser;

  static const _profileKey = 'applicant_profile';

  ApplicantProfile get applicantProfile {
    final json = database.settings.getJson(_profileKey);
    return json is Map<String, Object?>
        ? ApplicantProfile.fromJson(json)
        : const ApplicantProfile();
  }

  set applicantProfile(ApplicantProfile profile) {
    database.settings.setJson(_profileKey, profile.toJson());
    notifyListeners();
  }

  bool refreshing = false;

  /// The latest exchange rates, or null until the first refresh succeeds.
  ExchangeRates? rates;

  SourceRegistry get registry => repository.registry;

  DateTime now() => _clock();

  bool get notificationsEnabled =>
      database.settings.get(_notificationsKey) != 'false';

  set notificationsEnabled(bool enabled) {
    database.settings.set(_notificationsKey, '$enabled');
    notifyListeners();
  }

  /// The API key for the chosen model's provider, or null when none is set
  /// or it can no longer be decrypted.
  String? get apiKey => apiKeyFor(aiModel.provider);

  String? apiKeyFor(AiProvider provider) {
    final sealed = database.settings.get(_apiKeyKeys[provider]!);
    return sealed == null ? null : secretBox.open(sealed);
  }

  /// Stores the key for [provider], by default the chosen model's,
  /// encrypted; null or empty removes it.
  void setApiKey(String? key, {AiProvider? provider}) {
    final setting = _apiKeyKeys[provider ?? aiModel.provider]!;
    final trimmed = key?.trim() ?? '';
    if (trimmed.isEmpty) {
      database.settings.remove(setting);
    } else {
      database.settings.set(setting, secretBox.seal(trimmed));
    }
    notifyListeners();
  }

  AiModel get aiModel => AiModel.byName(database.settings.get(_modelKey));

  set aiModel(AiModel model) {
    database.settings.set(_modelKey, model.name);
    notifyListeners();
  }

  /// The OpenRouter model id the user typed, such as
  /// `deepseek/deepseek-chat`; empty until set.
  String get openRouterModel =>
      database.settings.get(_openRouterModelKey) ?? '';

  set openRouterModel(String id) {
    database.settings.set(_openRouterModelKey, id.trim());
    notifyListeners();
  }

  /// Whether the AI features can run: a key for the chosen provider, and
  /// for OpenRouter a model id too.
  bool get aiReady =>
      apiKey != null &&
      (aiModel != AiModel.openRouter || openRouterModel.isNotEmpty);

  /// The AI features, or null until [aiReady].
  CvReviewer? reviewer() {
    final client = aiClient();
    return client == null ? null : CvReviewer(client);
  }

  /// The chosen model's client, or null until [aiReady].
  AiClient? aiClient() {
    final key = apiKey;
    if (key == null || !aiReady) return null;
    final model = aiModel;
    final client = aiHttpClient;
    return switch (model.provider) {
      AiProvider.anthropic => ClaudeClient(
        apiKey: key,
        model: model,
        client: client,
      ),
      AiProvider.openai => OpenAiClient(
        apiKey: key,
        model: model,
        client: client,
      ),
      AiProvider.gemini => GeminiClient(
        apiKey: key,
        model: model,
        client: client,
      ),
      AiProvider.openrouter => OpenRouterClient(
        apiKey: key,
        modelId: openRouterModel,
        client: client,
      ),
    };
  }

  /// Records what an AI request cost.
  void recordSpend(AiUsage usage) {
    database.cvs.recordSpend(usage.costUsd, now());
    notifyListeners();
  }

  /// An amount in US dollars as text, with a rupiah estimate when rates are
  /// known, such as `USD 0,08 (≈ Rp 1.440)`.
  String formatUsd(double usd) {
    final dollars =
        'USD ${usd.toStringAsFixed(usd < 1 ? 3 : 2).replaceAll('.', ',')}';
    final rupiah = rates?.convert(usd, from: 'USD', to: 'IDR');
    return rupiah == null ? dollars : '$dollars (≈ Rp ${thousands(rupiah)})';
  }

  /// Reminders that need attention now, for the tracker and its badge.
  List<Reminder> reminders() =>
      dueReminders(database.applications.all(), now());

  /// Call after writing to the database.
  void dataChanged() {
    rates = repository.exchangeRates();
    notifyListeners();
  }

  /// Fetches due sources, then announces new jobs that match saved searches.
  Future<RefreshResult> refresh({required bool manual}) async {
    if (refreshing) return const RefreshResult();
    refreshing = true;
    notifyListeners();
    try {
      final result = await repository.refresh(manual: manual);
      await _announce(
        announcer.forNewJobs(
          result.newJobIds,
          excludedSources: registry.disabledIds(),
        ),
      );
      return result;
    } finally {
      refreshing = false;
      dataChanged();
    }
  }

  /// Announces reminders that became due since the last check.
  Future<void> checkReminders() => _announce(announcer.forReminders(now()));

  Future<void> _announce(List<Announcement> announcements) async {
    if (!notificationsEnabled) return;
    for (final announcement in announcements) {
      await notifier.show(announcement);
    }
  }
}

/// The message to show after a refresh, or null when there is nothing worth
/// saying. An automatic refresh stays quiet unless something failed.
String? refreshMessage(RefreshResult result, {required bool manual}) {
  if (result.errors.isNotEmpty) {
    final failures = result.errors.entries
        .map((entry) => '${entry.key} (${entry.value})')
        .join(', ');
    return 'Gagal memperbarui: $failures';
  }
  if (!manual) return null;
  if (result.fetched.isEmpty) {
    return 'Semua sumber baru saja diperbarui. Coba lagi nanti.';
  }
  final total = result.fetched.values.fold(0, (sum, count) => sum + count);
  return 'Diperbarui: $total lowongan dari ${result.fetched.length} sumber, '
      '${result.newJobIds.length} di antaranya baru.';
}
