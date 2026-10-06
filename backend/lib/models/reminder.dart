import '../util/format.dart';
import 'application.dart';

/// In the order reminders are listed: the most time-critical first.
enum ReminderKind { interview, followUp }

/// Something about a tracked application that needs the user's attention.
class Reminder {
  const Reminder({
    required this.kind,
    required this.application,
    required this.message,
    required this.key,
  });

  final ReminderKind kind;
  final Application application;
  final String message;

  /// Identifies this occurrence, so it is announced only once. A new follow-up
  /// or a rescheduled interview gives a new key.
  final String key;
}

/// How long an application can go without news before a follow-up is due.
const followUpAfter = Duration(days: 7);

/// Reminders due at [now]: applications with no news for [followUpAfter]
/// since applying or the last follow-up, and interviews in the next 24 hours.
List<Reminder> dueReminders(List<Application> applications, DateTime now) {
  final reminders = <Reminder>[];
  for (final application in applications) {
    final interviewAt = application.interviewAt;
    if (application.status == ApplicationStatus.interview &&
        interviewAt != null &&
        interviewAt.isAfter(now) &&
        interviewAt.difference(now) <= const Duration(hours: 24)) {
      reminders.add(
        Reminder(
          kind: ReminderKind.interview,
          application: application,
          message: 'Interview ${shortDateTime(interviewAt)}',
          key:
              'interview:${application.jobId}:'
              '${interviewAt.millisecondsSinceEpoch}',
        ),
      );
    }
    final lastContact = application.lastContactAt;
    if (application.status == ApplicationStatus.applied &&
        lastContact != null &&
        now.difference(lastContact) >= followUpAfter) {
      final days = now.difference(lastContact).inDays;
      reminders.add(
        Reminder(
          kind: ReminderKind.followUp,
          application: application,
          message: application.followedUpAt == null
              ? 'Belum ada kabar $days hari sejak melamar'
              : 'Belum ada kabar $days hari sejak follow-up terakhir',
          key:
              'followup:${application.jobId}:'
              '${lastContact.millisecondsSinceEpoch}',
        ),
      );
    }
  }
  reminders.sort((a, b) => a.kind.index.compareTo(b.kind.index));
  return reminders;
}
