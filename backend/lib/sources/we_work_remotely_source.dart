import 'package:xml/xml.dart';

import '../models/job.dart';
import '../util/format.dart';
import 'job_source.dart';

class WeWorkRemotelySource extends JobSource {
  const WeWorkRemotelySource();

  @override
  String get id => 'weworkremotely';

  @override
  String get name => 'We Work Remotely';

  @override
  Uri get endpoint => Uri.parse('https://weworkremotely.com/remote-jobs.rss');

  @override
  List<Job> parse(String body) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(body);
    } on XmlException catch (error) {
      throw FormatException('RSS tidak valid: ${error.message}');
    }
    final jobs = <Job>[];
    for (final item in document.findAllElements('item')) {
      String field(String name) =>
          item.getElement(name)?.innerText.trim() ?? '';

      final url = field('link').isNotEmpty ? field('link') : field('guid');
      // Feed titles look like "Company: Job title".
      final heading = plainText(field('title'));
      final separator = heading.indexOf(': ');
      final title = separator < 0 ? heading : heading.substring(separator + 2);
      if (title.isEmpty || url.isEmpty) continue;
      jobs.add(
        Job(
          id: '$id:${field('guid').isNotEmpty ? field('guid') : url}',
          sourceId: id,
          title: title,
          company: separator < 0 ? '' : heading.substring(0, separator),
          url: url,
          location: plainText(field('region')),
          category: plainText(field('category')),
          jobType: jobTypeLabel(field('type')),
          descriptionHtml: field('description'),
          publishedAt: parseRfc822(field('pubDate')),
        ),
      );
    }
    return jobs;
  }
}
