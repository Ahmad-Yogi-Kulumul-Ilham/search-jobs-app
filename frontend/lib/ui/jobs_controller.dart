import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

/// State of the jobs screen: the filtered list, the open job, and refreshes.
class JobsController extends ChangeNotifier {
  JobsController(this._repository);

  final JobRepository _repository;
  Timer? _searchDebounce;

  List<Job> jobs = const [];
  Job? selected;
  String selectedDescriptionHtml = '';
  String query = '';
  final Set<String> excludedSources = {};
  bool refreshing = false;
  DateTime? lastUpdated;

  /// Reloads the list from the local database with the current filters.
  void load() {
    jobs = _repository.database.search(
      query: query,
      excludedSources: excludedSources,
    );
    lastUpdated = _repository.database.latestFetch();
    notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), load);
  }

  void toggleSource(String sourceId) {
    if (!excludedSources.remove(sourceId)) excludedSources.add(sourceId);
    load();
  }

  void select(Job job) {
    selected = job;
    selectedDescriptionHtml = _repository.database.descriptionOf(job.id);
    notifyListeners();
  }

  Future<RefreshResult> refresh({required bool manual}) async {
    if (refreshing) return const RefreshResult();
    refreshing = true;
    notifyListeners();
    try {
      return await _repository.refresh(manual: manual);
    } finally {
      refreshing = false;
      load();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
