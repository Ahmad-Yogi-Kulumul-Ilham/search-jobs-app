import '../util/region.dart';
import 'application.dart';
import 'salary.dart';

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
    this.salaryRange,
    this.descriptionHtml = '',
    this.publishedAt,
    this.trackedStatus,
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

  /// Salary as text for display; empty when the posting gives none.
  final String salary;

  /// The same salary in convertible form, when it could be worked out.
  final SalaryRange? salaryRange;

  /// Empty for jobs loaded as list rows; the database returns it separately.
  final String descriptionHtml;
  final DateTime? publishedAt;

  /// Where the user's application for this job stands, or null when the job
  /// is not in the tracker. Set only on jobs read from the database.
  final ApplicationStatus? trackedStatus;

  RegionFit get regionFit => classifyRegion(location);
}
