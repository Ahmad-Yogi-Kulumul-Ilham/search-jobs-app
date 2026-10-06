import 'package:html/parser.dart' as html_parser;

import '../models/job.dart';
import '../models/salary.dart';
import '../util/format.dart';
import '../util/region.dart';
import 'job_source.dart';

/// One company's public job board on an applicant-tracking service. These
/// boards list office jobs too, so only postings that look remote are kept.
abstract class CompanyBoardSource extends JobSource {
  const CompanyBoardSource({
    required this.id,
    required this.name,
    required this.board,
  });

  @override
  final String id;

  /// The company's display name.
  @override
  final String name;

  /// The company's identifier in the service's URLs, such as `gitlab`.
  final String board;
}

class GreenhouseSource extends CompanyBoardSource {
  const GreenhouseSource({
    required super.id,
    required super.name,
    required super.board,
  });

  @override
  Uri get endpoint => Uri.parse(
    'https://boards-api.greenhouse.io/v1/boards/$board/jobs?content=true',
  );

  @override
  List<Job> parse(String body) {
    final jobs = <Job>[];
    for (final item in decodeJobList(body, key: 'jobs')) {
      if (item is! Map) continue;
      final sourceJobId = asText(item['id']);
      final title = plainText(asText(item['title']));
      final url = asText(item['absolute_url']);
      final place = item['location'];
      final location = asText(place is Map ? place['name'] : null);
      if (sourceJobId.isEmpty || title.isEmpty || url.isEmpty) continue;
      if (!looksRemote(location)) continue;
      final company = asText(item['company_name']);
      final published = asText(item['first_published']);
      jobs.add(
        Job(
          id: '$id:$sourceJobId',
          sourceId: id,
          title: title,
          company: company.isEmpty ? name : company,
          url: url,
          location: location,
          category: _names(item['departments']),
          // The API returns the description as entity-escaped HTML.
          descriptionHtml:
              html_parser.parseFragment(asText(item['content'])).text ?? '',
          publishedAt: parseIsoUtc(
            published.isEmpty ? asText(item['updated_at']) : published,
          ),
        ),
      );
    }
    return jobs;
  }
}

class LeverSource extends CompanyBoardSource {
  const LeverSource({
    required super.id,
    required super.name,
    required super.board,
  });

  @override
  Uri get endpoint =>
      Uri.parse('https://api.lever.co/v0/postings/$board?mode=json');

  @override
  List<Job> parse(String body) {
    final jobs = <Job>[];
    for (final item in decodeJobList(body)) {
      if (item is! Map) continue;
      final sourceJobId = asText(item['id']);
      final title = plainText(asText(item['text']));
      final url = asText(item['hostedUrl']);
      final categories = item['categories'];
      final details = categories is Map ? categories : const {};
      final places = asTextList(details['allLocations']);
      final location = places.isEmpty
          ? asText(details['location'])
          : places.join(', ');
      if (sourceJobId.isEmpty || title.isEmpty || url.isEmpty) continue;
      if (asText(item['workplaceType']) != 'remote' && !looksRemote(location)) {
        continue;
      }
      final created = item['createdAt'];
      final sections = [
        for (final section
            in item['lists'] is List ? item['lists'] as List : [])
          if (section is Map)
            '<h3>${asText(section['text'])}</h3>'
                '<ul>${asText(section['content'])}</ul>',
      ];
      jobs.add(
        Job(
          id: '$id:$sourceJobId',
          sourceId: id,
          title: title,
          company: name,
          url: url,
          location: location,
          category: asText(details['team']).isEmpty
              ? asText(details['department'])
              : asText(details['team']),
          jobType: jobTypeLabel(asText(details['commitment'])),
          descriptionHtml: [
            asText(item['description']),
            ...sections,
            asText(item['additional']),
          ].join('\n'),
          publishedAt: created is int
              ? DateTime.fromMillisecondsSinceEpoch(created, isUtc: true)
              : null,
        ),
      );
    }
    return jobs;
  }
}

class AshbySource extends CompanyBoardSource {
  const AshbySource({
    required super.id,
    required super.name,
    required super.board,
  });

  @override
  Uri get endpoint => Uri.parse(
    'https://api.ashbyhq.com/posting-api/job-board/$board'
    '?includeCompensation=true',
  );

  @override
  List<Job> parse(String body) {
    final jobs = <Job>[];
    for (final item in decodeJobList(body, key: 'jobs')) {
      if (item is! Map || item['isListed'] == false) continue;
      final sourceJobId = asText(item['id']);
      final title = plainText(asText(item['title']));
      final url = asText(item['jobUrl']);
      final secondary = item['secondaryLocations'];
      final location = [
        asText(item['location']),
        for (final place in secondary is List ? secondary : [])
          if (place is Map) asText(place['location']),
      ].where((place) => place.isNotEmpty).join(', ');
      if (sourceJobId.isEmpty || title.isEmpty || url.isEmpty) continue;
      if (item['isRemote'] != true && !looksRemote(location)) continue;
      final compensation = item['compensation'];
      final salary = compensation is Map
          ? asText(compensation['compensationTierSummary'])
          : '';
      jobs.add(
        Job(
          id: '$id:$sourceJobId',
          sourceId: id,
          title: title,
          company: name,
          url: url,
          location: location,
          category: asText(item['team']).isEmpty
              ? asText(item['department'])
              : asText(item['team']),
          jobType: jobTypeLabel(asText(item['employmentType'])),
          salary: salary,
          salaryRange: parseSalaryText(salary),
          descriptionHtml: asText(item['descriptionHtml']),
          publishedAt: parseIsoUtc(asText(item['publishedAt'])),
        ),
      );
    }
    return jobs;
  }
}

String _names(Object? list) => [
  for (final entry in list is List ? list : [])
    if (entry is Map && asText(entry['name']).isNotEmpty) asText(entry['name']),
].join(', ');
