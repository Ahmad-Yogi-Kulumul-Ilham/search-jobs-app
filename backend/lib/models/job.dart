/// A job posting, normalized from one of the job-board sources.
class Job {
  const Job({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.company,
    required this.url,
    this.location = '',
    this.category = '',
    this.tags = const [],
    this.jobType = '',
    this.salary = '',
    this.descriptionHtml = '',
    this.publishedAt,
  });

  /// Unique across sources: `<sourceId>:<id given by the source>`.
  final String id;
  final String sourceId;
  final String title;
  final String company;

  /// The posting on the source's own site. Applying always goes through it.
  final String url;
  final String location;
  final String category;
  final List<String> tags;
  final String jobType;
  final String salary;

  /// Empty for jobs loaded as list rows; the database returns it separately.
  final String descriptionHtml;
  final DateTime? publishedAt;
}
