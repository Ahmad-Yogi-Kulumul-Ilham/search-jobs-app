import '../models/reminder.dart';
import 'app_database.dart';

/// A desktop notification to show.
class Announcement {
  const Announcement({required this.title, required this.body});

  final String title;
  final String body;
}

/// Decides which notifications to show, and remembers which reminders were
/// already announced so each is shown once.
class Announcer {
  Announcer(this._database);

  static const _announcedKey = 'announced_reminders';

  /// Keys older than the most recent [_keep] are forgotten. Reminders that
  /// old are long past, so they cannot come back.
  static const _keep = 300;

  final AppDatabase _database;

  /// One notification per saved search that matches any of [newJobIds].
  /// Jobs from [excludedSources] do not count.
  List<Announcement> forNewJobs(
    List<String> newJobIds, {
    Set<String> excludedSources = const {},
  }) {
    if (newJobIds.isEmpty) return const [];
    final announcements = <Announcement>[];
    for (final alert in _database.alerts.all()) {
      final matches = _database.jobs.search(
        filter: alert.filter.copyWith(
          excludedSources: {
            ...alert.filter.excludedSources,
            ...excludedSources,
          },
        ),
        onlyIds: newJobIds,
      );
      if (matches.isEmpty) continue;
      final first = matches.first;
      announcements.add(
        Announcement(
          title: '${matches.length} lowongan baru: ${alert.name}',
          body: [
            first.title,
            if (first.company.isNotEmpty) first.company,
            if (matches.length > 1) 'dan ${matches.length - 1} lainnya',
          ].join(' · '),
        ),
      );
    }
    return announcements;
  }

  /// Reminders due at [now] that were not announced before. Calling this
  /// marks them as announced.
  List<Announcement> forReminders(DateTime now) {
    final due = dueReminders(_database.applications.all(), now);
    final stored = _database.settings.getJson(_announcedKey);
    final announced = <String>[
      for (final key in stored is List ? stored : const []) '$key',
    ];
    final fresh = [
      for (final reminder in due)
        if (!announced.contains(reminder.key)) reminder,
    ];
    if (fresh.isEmpty) return const [];
    announced.addAll(fresh.map((reminder) => reminder.key));
    _database.settings.setJson(
      _announcedKey,
      announced.sublist(
        announced.length > _keep ? announced.length - _keep : 0,
      ),
    );
    return [
      for (final reminder in fresh)
        Announcement(
          title: switch (reminder.kind) {
            ReminderKind.interview => 'Interview segera',
            ReminderKind.followUp => 'Saatnya follow-up',
          },
          body: [
            reminder.application.title,
            if (reminder.application.company.isNotEmpty)
              reminder.application.company,
            reminder.message,
          ].join(' · '),
        ),
    ];
  }
}
