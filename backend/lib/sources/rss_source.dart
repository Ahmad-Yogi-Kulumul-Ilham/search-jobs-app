import 'package:xml/xml.dart';

import '../models/job.dart';
import '../util/format.dart';
import 'job_source.dart';

/// Any job feed in RSS 2.0 or Atom format, added by the user.
class RssSource extends JobSource {
  const RssSource({required this.id, required this.name, required this.url});

  @override
  final String id;

  @override
  final String name;

  final String url;

  @override
  Uri get endpoint => Uri.parse(url);

  @override
  List<Job> parse(String body) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(body);
    } on XmlException catch (error) {
      throw FormatException('Feed tidak valid: ${error.message}');
    }
    final items = [
      ...document.findAllElements('item'),
      ...document.findAllElements('entry'),
    ];
    if (items.isEmpty &&
        document.findAllElements('channel').isEmpty &&
        document.findAllElements('feed').isEmpty) {
      throw const FormatException('Bukan feed RSS atau Atom');
    }
    final jobs = <Job>[];
    for (final item in items) {
      String field(String name) =>
          item.getElement(name)?.innerText.trim() ?? '';

      // RSS puts the address in the element text, Atom in an attribute.
      final link = field('link').isNotEmpty
          ? field('link')
          : item.getElement('link')?.getAttribute('href') ?? '';
      final url = link.isNotEmpty ? link : field('guid');
      final title = plainText(field('title'));
      if (title.isEmpty || !url.startsWith('http')) continue;
      final key = [
        field('guid'),
        field('id'),
        url,
      ].firstWhere((value) => value.isNotEmpty);
      final description = [
        item.getElement('content:encoded')?.innerText ?? '',
        field('description'),
        field('content'),
        field('summary'),
      ].firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
      jobs.add(
        Job(
          id: '$id:$key',
          sourceId: id,
          title: title,
          company: plainText(
            item.getElement('dc:creator')?.innerText ??
                item.getElement('author')?.getElement('name')?.innerText ??
                '',
          ),
          url: url,
          category: plainText(field('category')),
          descriptionHtml: description.trim(),
          publishedAt:
              parseRfc822(field('pubDate')) ??
              parseIsoUtc(field('updated')) ??
              parseIsoUtc(field('published')),
        ),
      );
    }
    return jobs;
  }
}
