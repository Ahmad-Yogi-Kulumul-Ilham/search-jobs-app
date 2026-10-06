import 'package:search_jobs_backend/search_jobs_backend.dart';
import 'package:test/test.dart';

void main() {
  test('Greenhouse: keeps remote jobs and unescapes the description', () {
    const source = GreenhouseSource(
      id: 'custom:1',
      name: 'GitLab Inc',
      board: 'gitlab',
    );
    expect(
      source.endpoint.toString(),
      'https://boards-api.greenhouse.io/v1/boards/gitlab/jobs?content=true',
    );

    final jobs = source.parse('''
      {"jobs": [
        {"id": 8860302002, "title": "Account Executive - France",
         "absolute_url": "https://job-boards.greenhouse.io/gitlab/jobs/8860302002",
         "location": {"name": "Remote, France"}, "company_name": "GitLab",
         "first_published": "2026-10-02T11:31:50-04:00",
         "updated_at": "2026-10-03T11:31:50-04:00",
         "content": "&lt;p&gt;GitLab is &lt;b&gt;remote&lt;/b&gt; &amp;amp; open.&lt;/p&gt;",
         "departments": [{"id": 1, "name": "Sales"}, {"id": 2, "name": "EMEA"}]},
        {"id": 2, "title": "Office Manager",
         "absolute_url": "https://job-boards.greenhouse.io/gitlab/jobs/2",
         "location": {"name": "Bangalore, India"}, "content": ""}
      ], "meta": {"total": 2}}
    ''');

    final job = jobs.single;
    expect(job.id, 'custom:1:8860302002');
    expect(job.company, 'GitLab');
    expect(job.location, 'Remote, France');
    expect(job.category, 'Sales, EMEA');
    expect(job.descriptionHtml, '<p>GitLab is <b>remote</b> &amp; open.</p>');
    expect(job.publishedAt, DateTime.utc(2026, 10, 2, 15, 31, 50));
    expect(job.regionFit, RegionFit.restricted);
  });

  test('Lever: uses the remote flag and stitches description sections', () {
    const source = LeverSource(
      id: 'custom:2',
      name: 'Spotify',
      board: 'spotify',
    );

    final jobs = source.parse('''
      [
        {"id": "aaa", "text": "Backend Engineer", "workplaceType": "remote",
         "hostedUrl": "https://jobs.lever.co/spotify/aaa",
         "categories": {"commitment": "Permanent", "team": "Platform",
                        "location": "London", "allLocations": ["London", "Stockholm"]},
         "createdAt": 1782214185805,
         "description": "<div>Intro</div>",
         "lists": [{"text": "What You'll Do", "content": "<li>Build</li>"}],
         "additional": "<div>Equal opportunity</div>"},
        {"id": "bbb", "text": "Designer", "workplaceType": "hybrid",
         "hostedUrl": "https://jobs.lever.co/spotify/bbb",
         "categories": {"location": "New York"}}
      ]
    ''');

    final job = jobs.single;
    expect(job.id, 'custom:2:aaa');
    expect(job.company, 'Spotify');
    expect(job.location, 'London, Stockholm');
    expect(job.category, 'Platform');
    expect(job.jobType, 'Penuh waktu');
    expect(
      job.descriptionHtml,
      "<div>Intro</div>\n<h3>What You'll Do</h3><ul><li>Build</li></ul>\n"
      '<div>Equal opportunity</div>',
    );
    expect(
      job.publishedAt,
      DateTime.fromMillisecondsSinceEpoch(1782214185805, isUtc: true),
    );
  });

  test('Ashby: reads compensation and skips unlisted jobs', () {
    const source = AshbySource(id: 'custom:3', name: 'Ashby', board: 'ashby');

    final jobs = source.parse('''
      {"apiVersion": "1", "jobs": [
        {"id": "7458", "title": "Engineering Manager - EU", "team": "EMEA Engineering",
         "department": "Engineering", "employmentType": "FullTime",
         "location": "Remote - European Union",
         "secondaryLocations": [{"location": "Spain"}],
         "publishedAt": "2024-03-04T14:29:08.532+00:00",
         "isListed": true, "isRemote": true,
         "jobUrl": "https://jobs.ashbyhq.com/ashby/7458",
         "descriptionHtml": "<p>Hi</p>",
         "compensation": {"compensationTierSummary": "€110K – €185K • Offers Equity"}},
        {"id": "hidden", "title": "Secret", "isListed": false, "isRemote": true,
         "jobUrl": "https://jobs.ashbyhq.com/ashby/hidden"},
        {"id": "office", "title": "Recruiter", "isRemote": false,
         "location": "San Francisco",
         "jobUrl": "https://jobs.ashbyhq.com/ashby/office",
         "compensation": {"compensationTierSummary": null}}
      ]}
    ''');

    final job = jobs.single;
    expect(job.id, 'custom:3:7458');
    expect(job.location, 'Remote - European Union, Spain');
    expect(job.jobType, 'Penuh waktu');
    expect(job.salary, '€110K – €185K • Offers Equity');
    expect(
      job.salaryRange,
      SalaryRange.of(
        110000,
        185000,
        currency: 'EUR',
        period: SalaryPeriod.year,
      ),
    );
  });

  group('RssSource', () {
    const source = RssSource(
      id: 'custom:4',
      name: 'Example',
      url: 'https://example.com/jobs.rss',
    );

    test('reads RSS 2.0 items', () {
      final jobs = source.parse('''
        <?xml version="1.0"?>
        <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/"
             xmlns:content="http://purl.org/rss/1.0/modules/content/">
          <channel>
            <title>Example jobs</title>
            <item>
              <title>Support Agent &amp; Writer</title>
              <link>https://example.com/jobs/1</link>
              <guid>job-1</guid>
              <dc:creator>Initech</dc:creator>
              <category>Support</category>
              <description>Short</description>
              <content:encoded><![CDATA[<p>Full text</p>]]></content:encoded>
              <pubDate>Mon, 05 Oct 2026 10:00:00 +0000</pubDate>
            </item>
            <item><title>No link</title></item>
          </channel>
        </rss>
      ''');

      final job = jobs.single;
      expect(job.id, 'custom:4:job-1');
      expect(job.title, 'Support Agent & Writer');
      expect(job.company, 'Initech');
      expect(job.url, 'https://example.com/jobs/1');
      expect(job.category, 'Support');
      expect(job.descriptionHtml, '<p>Full text</p>');
      expect(job.publishedAt, DateTime.utc(2026, 10, 5, 10));
    });

    test('reads Atom entries', () {
      final jobs = source.parse('''
        <?xml version="1.0" encoding="utf-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <title>Example</title>
          <entry>
            <title>Data Analyst</title>
            <link href="https://example.com/jobs/2"/>
            <id>urn:job:2</id>
            <updated>2026-10-05T10:00:00Z</updated>
            <author><name>Globex</name></author>
            <summary>Analyze data</summary>
          </entry>
        </feed>
      ''');

      final job = jobs.single;
      expect(job.id, 'custom:4:urn:job:2');
      expect(job.url, 'https://example.com/jobs/2');
      expect(job.company, 'Globex');
      expect(job.descriptionHtml, 'Analyze data');
      expect(job.publishedAt, DateTime.utc(2026, 10, 5, 10));
    });

    test('an empty feed is fine, but a web page is not a feed', () {
      expect(
        source.parse('<rss><channel><title>x</title></channel></rss>'),
        isEmpty,
      );
      expect(
        () => source.parse('<html><body>Jobs</body></html>'),
        throwsFormatException,
      );
      expect(() => source.parse('{"jobs": []}'), throwsFormatException);
    });
  });
}
