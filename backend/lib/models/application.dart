/// The stages a tracked job moves through.
enum ApplicationStatus {
  saved('Disimpan'),
  applied('Dilamar'),
  interview('Interview'),
  offer('Tawaran'),
  rejected('Ditolak');

  const ApplicationStatus(this.label);

  final String label;

  static ApplicationStatus? byName(String? name) {
    for (final status in values) {
      if (status.name == name) return status;
    }
    return null;
  }
}

/// A job the user is tracking, from "saved for later" through to an outcome.
///
/// It carries its own copy of the job's headline fields, so the record stays
/// readable after the source stops listing the job, and so jobs found
/// elsewhere (LinkedIn, a referral) can be tracked by hand.
class Application {
  const Application({
    required this.jobId,
    required this.status,
    required this.title,
    required this.company,
    required this.url,
    required this.createdAt,
    required this.updatedAt,
    this.sourceId = manualSourceId,
    this.location = '',
    this.notes = '',
    this.appliedAt,
    this.interviewAt,
    this.followedUpAt,
  });

  /// Source id of applications the user typed in rather than picked from a
  /// fetched job.
  static const manualSourceId = 'manual';

  final String jobId;
  final ApplicationStatus status;
  final String title;
  final String company;
  final String url;
  final String sourceId;
  final String location;
  final String notes;
  final DateTime createdAt;

  /// When the status first reached [ApplicationStatus.applied].
  final DateTime? appliedAt;
  final DateTime? interviewAt;

  /// When the user last chased the company for news.
  final DateTime? followedUpAt;

  /// Last time the status or details changed.
  final DateTime updatedAt;

  bool get isManual => sourceId == manualSourceId;

  /// The later of applying and the last follow-up, or null before applying.
  DateTime? get lastContactAt {
    final applied = appliedAt, followedUp = followedUpAt;
    if (applied == null || followedUp == null) return applied ?? followedUp;
    return followedUp.isAfter(applied) ? followedUp : applied;
  }

  Application copyWith({
    ApplicationStatus? status,
    String? title,
    String? company,
    String? url,
    String? notes,
    DateTime? appliedAt,
    DateTime? Function()? interviewAt,
    DateTime? followedUpAt,
    DateTime? updatedAt,
  }) => Application(
    jobId: jobId,
    status: status ?? this.status,
    title: title ?? this.title,
    company: company ?? this.company,
    url: url ?? this.url,
    sourceId: sourceId,
    location: location,
    notes: notes ?? this.notes,
    createdAt: createdAt,
    appliedAt: appliedAt ?? this.appliedAt,
    interviewAt: interviewAt == null ? this.interviewAt : interviewAt(),
    followedUpAt: followedUpAt ?? this.followedUpAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
