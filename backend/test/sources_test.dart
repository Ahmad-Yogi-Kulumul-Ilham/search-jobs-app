import 'package:test/test.dart';
import 'package:search_jobs_backend/sources/jobicy_source.dart';
import 'package:search_jobs_backend/sources/remote_ok_source.dart';
import 'package:search_jobs_backend/sources/remotive_source.dart';
import 'package:search_jobs_backend/sources/we_work_remotely_source.dart';

void main() {
  test('Remotive: maps fields and reads the date as UTC', () {
    final jobs = const RemotiveSource().parse('''
      {"0-legal-notice": "…", "job-count": 1, "jobs": [{
        "id": 2091149,
        "url": "https://remotive.com/remote-jobs/software-development/x-2091149",
        "title": "Software Engineer &amp; Trainer",
        "company_name": "CodeForAI",
        "category": "Software Development",
        "tags": ["api", "python"],
        "job_type": "full_time",
        "publication_date": "2026-10-05T05:15:43",
        "candidate_required_location": "Worldwide",
        "salary": "\$45-\$120/Hour",
        "description": "<p>Who should apply</p>"
      }]}
    ''');

    expect(jobs, hasLength(1));
    final job = jobs.single;
    expect(job.id, 'remotive:2091149');
    expect(job.title, 'Software Engineer & Trainer');
    expect(job.company, 'CodeForAI');
    expect(job.location, 'Worldwide');
    expect(job.tags, ['api', 'python']);
    expect(job.jobType, 'Penuh waktu');
    expect(job.salary, r'$45-$120/Hour');
    expect(job.descriptionHtml, '<p>Who should apply</p>');
    expect(job.publishedAt, DateTime.utc(2026, 10, 5, 5, 15, 43));
  });

  test('Remote OK: skips the legal notice and formats the salary', () {
    final jobs = const RemoteOkSource().parse('''
      [
        {"last_updated": 1791205202, "legal": "API Terms of Service…"},
        {"id": "1137463", "epoch": 1791129603, "company": "Fortanix",
         "position": "Business Development Director", "tags": ["exec"],
         "description": "<p>About</p>", "location": "",
         "salary_min": 60000, "salary_max": 90000,
         "url": "https://remoteOK.com/remote-jobs/x-1137463"},
        {"id": "1137464", "epoch": 1791129604, "company": "Acme",
         "position": "Designer", "salary_min": 0, "salary_max": 0,
         "url": "https://remoteOK.com/remote-jobs/x-1137464"}
      ]
    ''');

    expect(jobs.map((job) => job.id), ['remoteok:1137463', 'remoteok:1137464']);
    expect(jobs[0].salary, 'USD 60.000 – 90.000 / tahun');
    expect(
      jobs[0].publishedAt,
      DateTime.fromMillisecondsSinceEpoch(1791129603000, isUtc: true),
    );
    expect(jobs[1].salary, isEmpty);
  });

  test('Jobicy: joins list fields and tolerates missing salary', () {
    final jobs = const JobicySource().parse('''
      {"jobs": [{
        "id": 154681,
        "url": "https://jobicy.com/jobs/154681-senior-engineer",
        "jobTitle": "Senior Engineer",
        "companyName": "Five9",
        "jobIndustry": ["Sales &amp; Marketing", "Cybersecurity"],
        "jobType": ["Full-Time"],
        "jobGeo": "APAC",
        "jobLevel": "Senior",
        "jobDescription": "<p>Join us</p>",
        "pubDate": "2026-10-06T06:08:56+00:00"
      }]}
    ''');

    final job = jobs.single;
    expect(job.id, 'jobicy:154681');
    expect(job.category, 'Sales & Marketing, Cybersecurity');
    expect(job.jobType, 'Penuh waktu');
    expect(job.location, 'APAC');
    expect(job.tags, ['Senior']);
    expect(job.salary, isEmpty);
    expect(job.publishedAt, DateTime.utc(2026, 10, 6, 6, 8, 56));
  });

  test('We Work Remotely: splits company from title', () {
    final jobs = const WeWorkRemotelySource().parse('''
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss">
        <channel>
          <title>We Work Remotely</title>
          <item>
            <media:content url="https://example.com/logo.gif" type="image/png"/>
            <title>Semaphore: Senior Product Engineer</title>
            <region>Anywhere in the World</region>
            <category>Product</category>
            <type>Contract</type>
            <description>&lt;p&gt;Build things&lt;/p&gt;</description>
            <pubDate>Tue, 06 Oct 2026 08:44:40 +0000</pubDate>
            <guid>https://weworkremotely.com/remote-jobs/semaphore-spe</guid>
            <link>https://weworkremotely.com/remote-jobs/semaphore-spe</link>
          </item>
        </channel>
      </rss>
    ''');

    final job = jobs.single;
    expect(job.id, 'weworkremotely:https://weworkremotely.com/remote-jobs/semaphore-spe');
    expect(job.company, 'Semaphore');
    expect(job.title, 'Senior Product Engineer');
    expect(job.location, 'Anywhere in the World');
    expect(job.jobType, 'Kontrak');
    expect(job.descriptionHtml, '<p>Build things</p>');
    expect(job.publishedAt, DateTime.utc(2026, 10, 6, 8, 44, 40));
  });

  test('a body with an unexpected shape is a FormatException', () {
    expect(
      () => const RemotiveSource().parse('{"error": "rate limited"}'),
      throwsFormatException,
    );
    expect(
      () => const RemoteOkSource().parse('<html>blocked</html>'),
      throwsFormatException,
    );
    expect(
      () => const WeWorkRemotelySource().parse('not xml <'),
      throwsFormatException,
    );
  });
}
