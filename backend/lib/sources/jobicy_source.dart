import '../models/job.dart';
import '../util/format.dart';
import 'job_source.dart';

class JobicySource extends JobSource {
  const JobicySource();

  @override
  String get id => 'jobicy';

  @override
  String get name => 'Jobicy';

  @override
  Uri get endpoint =>
      Uri.parse('https://jobicy.com/api/v2/remote-jobs?count=100');

  @override
  List<Job> parse(String body) {
    final jobs = <Job>[];
    for (final item in decodeJobList(body, key: 'jobs')) {
      if (item is! Map) continue;
      final sourceJobId = asText(item['id']);
      final title = plainText(asText(item['jobTitle']));
      final url = asText(item['url']);
      if (sourceJobId.isEmpty || title.isEmpty || url.isEmpty) continue;
      final industries = asTextList(item['jobIndustry']).map(plainText);
      jobs.add(
        Job(
          id: '$id:$sourceJobId',
          sourceId: id,
          title: title,
          company: plainText(asText(item['companyName'])),
          url: url,
          location: plainText(asText(item['jobGeo'])),
          category: industries.join(', '),
          tags: [
            if (asText(item['jobLevel']).isNotEmpty) asText(item['jobLevel']),
          ],
          jobType: asTextList(item['jobType']).map(jobTypeLabel).join(', '),
          salary: formatSalary(
            asNum(item['salaryMin']),
            asNum(item['salaryMax']),
            currency: asText(item['salaryCurrency']),
            period: asText(item['salaryPeriod']),
          ),
          descriptionHtml: asText(item['jobDescription']),
          publishedAt: parseIsoUtc(asText(item['pubDate'])),
        ),
      );
    }
    return jobs;
  }
}
