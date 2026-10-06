import 'package:flutter/foundation.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import 'notifier.dart';

/// The backend objects every page shares. It notifies its listeners whenever
/// stored data changes, so each page can reload what it shows.
class AppServices extends ChangeNotifier {
  AppServices({
    required this.database,
    required this.repository,
    Notifier? notifier,
    DateTime Function()? clock,
  }) : notifier = notifier ?? RecordingNotifier(),
       _clock = clock ?? DateTime.now,
       announcer = Announcer(database) {
    rates = repository.exchangeRates();
  }

  static const _notificationsKey = 'notifications_enabled';

  final AppDatabase database;
  final JobRepository repository;
  final Notifier notifier;
  final Announcer announcer;
  final DateTime Function() _clock;

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
