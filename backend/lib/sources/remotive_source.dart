import '../models/job.dart';
import '../util/format.dart';
import 'job_source.dart';

class RemotiveSource extends JobSource {
  const RemotiveSource();

  @override
  String get id => 'remotive';

  @override
  String get name => 'Remotive';

  @override
  Uri get endpoint => Uri.parse('https://remotive.com/api/remote-jobs');

  /// Remotive's API terms ask for at most four requests a day.
  @override
  Duration get minRefreshInterval => const Duration(hours: 6);

  @override
  List<Job> parse(String body) {
    final jobs = <Job>[];
    for (final item in decodeJobList(body, key: 'jobs')) {
      if (item is! Map) continue;
      final sourceJobId = asText(item['id']);
      final title = plainText(asText(item['title']));
      final url = asText(item['url']);
      if (sourceJobId.isEmpty || title.isEmpty || url.isEmpty) continue;
      jobs.add(
        Job(
          id: '$id:$sourceJobId',
          sourceId: id,
          title: title,
          company: plainText(asText(item['company_name'])),
          url: url,
          location: plainText(asText(item['candidate_required_location'])),
          category: plainText(asText(item['category'])),
          tags: asTextList(item['tags']),
          jobType: jobTypeLabel(asText(item['job_type'])),
          salary: plainText(asText(item['salary'])),
          descriptionHtml: asText(item['description']),
          publishedAt: parseIsoUtc(asText(item['publication_date'])),
        ),
      );
    }
    return jobs;
  }
}
