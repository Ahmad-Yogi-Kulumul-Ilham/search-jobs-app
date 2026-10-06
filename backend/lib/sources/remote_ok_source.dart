import '../models/job.dart';
import '../models/salary.dart';
import '../util/format.dart';
import 'job_source.dart';

class RemoteOkSource extends JobSource {
  const RemoteOkSource();

  @override
  String get id => 'remoteok';

  @override
  String get name => 'Remote OK';

  @override
  Uri get endpoint => Uri.parse('https://remoteok.com/api');

  @override
  List<Job> parse(String body) {
    final jobs = <Job>[];
    for (final item in decodeJobList(body)) {
      // The first element is a legal notice, not a job; it has no id.
      if (item is! Map) continue;
      final sourceJobId = asText(item['id']);
      final title = plainText(asText(item['position']));
      final url = asText(item['url']);
      if (sourceJobId.isEmpty || title.isEmpty || url.isEmpty) continue;
      final epoch = item['epoch'];
      // Remote OK reports salaries as yearly USD amounts.
      final salary = SalaryRange.of(
        asNum(item['salary_min']),
        asNum(item['salary_max']),
        currency: 'USD',
        period: SalaryPeriod.year,
      );
      jobs.add(
        Job(
          id: '$id:$sourceJobId',
          sourceId: id,
          title: title,
          company: plainText(asText(item['company'])),
          url: url,
          location: plainText(asText(item['location'])),
          tags: asTextList(item['tags']),
          salary: salary?.label ?? '',
          salaryRange: salary,
          descriptionHtml: asText(item['description']),
          publishedAt: epoch is int
              ? DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true)
              : parseIsoUtc(asText(item['date'])),
        ),
      );
    }
    return jobs;
  }
}
