import 'package:local_notifier/local_notifier.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

/// Shows announcements outside the app window.
abstract class Notifier {
  Future<void> show(Announcement announcement);
}

/// Windows toast notifications.
///
/// Windows only shows toasts from apps it can find in the Start menu, so
/// setting up creates a Start menu shortcut for the app when there is none.
class DesktopNotifier implements Notifier {
  bool _ready = false;

  /// Returns whether notifications can be shown. Failure is not fatal: the
  /// app still shows everything in its own window.
  Future<bool> initialize() async {
    try {
      await localNotifier.setup(appName: 'Pencari Kerja Remote');
      _ready = true;
    } on Exception {
      _ready = false;
    }
    return _ready;
  }

  @override
  Future<void> show(Announcement announcement) async {
    if (!_ready) return;
    try {
      await LocalNotification(
        title: announcement.title,
        body: announcement.body,
      ).show();
    } on Exception {
      return;
    }
  }
}

/// Keeps announcements to itself; for tests and when notifications fail.
class RecordingNotifier implements Notifier {
  final List<Announcement> shown = [];

  @override
  Future<void> show(Announcement announcement) async =>
      shown.add(announcement);
}
