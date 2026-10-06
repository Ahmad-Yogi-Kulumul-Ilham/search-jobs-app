import 'package:flutter/foundation.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

/// The backend objects every page shares. It notifies its listeners whenever
/// stored data changes, so each page can reload what it shows.
class AppServices extends ChangeNotifier {
  AppServices({required this.database, required this.repository}) {
    rates = repository.exchangeRates();
  }

  final AppDatabase database;
  final JobRepository repository;

  bool refreshing = false;

  /// The latest exchange rates, or null until the first refresh succeeds.
  ExchangeRates? rates;

  SourceRegistry get registry => repository.registry;

  /// Call after writing to the database.
  void dataChanged() {
    rates = repository.exchangeRates();
    notifyListeners();
  }

  Future<RefreshResult> refresh({required bool manual}) async {
    if (refreshing) return const RefreshResult();
    refreshing = true;
    notifyListeners();
    try {
      return await repository.refresh(manual: manual);
    } finally {
      refreshing = false;
      dataChanged();
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
