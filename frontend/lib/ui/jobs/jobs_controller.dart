import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import '../../app_services.dart';

/// State of the jobs screen: the filtered list and the open job.
class JobsController extends ChangeNotifier {
  JobsController(this._services) {
    _services.addListener(load);
    load();
  }

  final AppServices _services;
  Timer? _searchDebounce;

  /// The user's own filter. Switched-off sources are excluded on top of it.
  JobFilter filter = const JobFilter();
  List<Job> jobs = const [];
  Job? selected;
  String selectedDescriptionHtml = '';

  /// Reloads the list and the open job from the local database.
  void load() {
    final store = _services.database.jobs;
    jobs = store.search(
      filter: filter.copyWith(
        excludedSources: {
          ...filter.excludedSources,
          ..._services.registry.disabledIds(),
        },
      ),
    );
    final open = selected;
    if (open != null) selected = store.find(open.id);
    notifyListeners();
  }

  void setQuery(String value) {
    filter = filter.copyWith(query: value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), load);
  }

  void setFilter(JobFilter value) {
    filter = value;
    load();
  }

  void select(Job job) {
    selected = job;
    selectedDescriptionHtml = _services.database.jobs.descriptionOf(job.id);
    notifyListeners();
  }

  /// Saves an untracked job for later, or drops a job that was only saved.
  void toggleSaved(Job job) {
    final applications = _services.database.applications;
    if (job.trackedStatus == null) {
      applications.track(job, now: DateTime.now());
    } else if (job.trackedStatus == ApplicationStatus.saved) {
      applications.delete(job.id);
    }
    _services.dataChanged();
  }

  void setStatus(Job job, ApplicationStatus status) {
    _services.database.applications.track(
      job,
      status: status,
      now: DateTime.now(),
    );
    _services.dataChanged();
  }

  void untrack(Job job) {
    _services.database.applications.delete(job.id);
    _services.dataChanged();
  }

  void hide(Job job) {
    _services.database.jobs.setHidden(job.id, true);
    _closeIf((open) => open.id == job.id);
    _services.dataChanged();
  }

  void unhide(Job job) {
    _services.database.jobs.setHidden(job.id, false);
    _services.dataChanged();
  }

  void blockCompany(String company) {
    _services.database.jobs.blockCompany(company);
    _closeIf((open) => open.company.toLowerCase() == company.toLowerCase());
    _services.dataChanged();
  }

  void unblockCompany(String company) {
    _services.database.jobs.unblockCompany(company);
    _services.dataChanged();
  }

  void _closeIf(bool Function(Job open) test) {
    final open = selected;
    if (open != null && test(open)) {
      selected = null;
      selectedDescriptionHtml = '';
    }
  }

  @override
  void dispose() {
    _services.removeListener(load);
    _searchDebounce?.cancel();
    super.dispose();
  }
}
