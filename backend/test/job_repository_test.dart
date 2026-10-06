import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:search_jobs_backend/data/job_database.dart';
import 'package:search_jobs_backend/data/job_repository.dart';
import 'package:search_jobs_backend/models/job.dart';
import 'package:search_jobs_backend/sources/jobicy_source.dart';
import 'package:search_jobs_backend/sources/remote_ok_source.dart';

const _remoteOkBody = '''
[
  {"legal": "API Terms of Service"},
  {"id": "1", "epoch": 1791129603, "company": "Fortanix",
   "position": "Rust Engineer", "tags": ["rust", "backend"],
   "description": "<p>Rust</p>", "location": "Worldwide",
   "url": "https://remoteok.com/remote-jobs/1"},
  {"id": "2", "epoch": 1791129000, "company": "Acme",
   "position": "Product Designer", "tags": ["figma"],
   "description": "<p>Design</p>", "location": "Europe",
   "url": "https://remoteok.com/remote-jobs/2"}
]
''';

Job _job(String id, {String title = 'Engineer', DateTime? publishedAt}) => Job(
  id: 'remoteok:$id',
  sourceId: 'remoteok',
  title: title,
  company: 'Acme',
  url: 'https://remoteok.com/remote-jobs/$id',
  descriptionHtml: '<p>$title</p>',
  publishedAt: publishedAt,
);

void main() {
  late JobDatabase database;
  late DateTime now;

  setUp(() {
    database = JobDatabase.inMemory();
    now = DateTime(2026, 10, 6, 9);
  });

  tearDown(() => database.close());

  JobRepository repository(MockClientHandler handler) => JobRepository(
    database: database,
    sources: const [RemoteOkSource(), JobicySource()],
    client: MockClient(handler),
    clock: () => now,
  );

  group('JobDatabase', () {
    test('search matches every word across fields, newest first', () {
      database.saveFetch('remoteok', [
        _job('1', title: 'Rust Engineer', publishedAt: DateTime(2026, 10, 1)),
        _job(
          '2',
          title: 'Senior Rust Engineer',
          publishedAt: DateTime(2026, 10, 5),
        ),
        _job('3', title: 'Designer'),
      ], now);

      expect(database.search().map((job) => job.id), [
        'remoteok:2',
        'remoteok:1',
        'remoteok:3',
      ]);
      expect(database.search(query: 'rust acme'), hasLength(2));
      expect(database.search(query: 'senior rust').single.id, 'remoteok:2');
      expect(database.search(query: '100%'), isEmpty);
      expect(database.search(excludedSources: {'remoteok'}), isEmpty);
    });

    test('list rows omit the description; descriptionOf returns it', () {
      database.saveFetch('remoteok', [_job('1', title: 'Writer')], now);

      expect(database.search().single.descriptionHtml, isEmpty);
      expect(database.descriptionOf('remoteok:1'), '<p>Writer</p>');
      expect(database.descriptionOf('remoteok:missing'), isEmpty);
    });

    test('a refetch updates jobs and drops ones unseen past retention', () {
      database.saveFetch('remoteok', [_job('1'), _job('2')], now);
      final later = now.add(JobDatabase.retention + const Duration(days: 1));
      database.saveFetch('remoteok', [_job('2', title: 'Renamed')], later);

      final jobs = database.search();
      expect(jobs.single.id, 'remoteok:2');
      expect(jobs.single.title, 'Renamed');
      expect(database.lastFetchedAt('remoteok'), later);
    });
  });

  group('JobRepository.refresh', () {
    test('stores fetched jobs and keeps going when one source fails', () async {
      final result = await repository((request) async {
        if (request.url.host == 'remoteok.com') {
          expect(request.headers['User-Agent'], isNotEmpty);
          return http.Response(_remoteOkBody, 200);
        }
        return http.Response('Service Unavailable', 503);
      }).refresh(manual: false);

      expect(result.fetched, {'Remote OK': 2});
      expect(result.errors, {'Jobicy': 'HTTP 503'});
      expect(database.search().map((job) => job.title), [
        'Rust Engineer',
        'Product Designer',
      ]);
      expect(database.lastFetchedAt('remoteok'), now);
      // A failed source is not marked as fetched, so it is retried next time.
      expect(database.lastFetchedAt('jobicy'), isNull);
    });

    test('skips sources that were fetched recently', () async {
      var requests = 0;
      final repo = repository((request) async {
        requests++;
        return request.url.host == 'remoteok.com'
            ? http.Response(_remoteOkBody, 200)
            : http.Response('{"jobs": []}', 200);
      });

      await repo.refresh(manual: true);
      expect(requests, 2);

      now = now.add(const Duration(minutes: 10));
      final soon = await repo.refresh(manual: true);
      expect(requests, 2);
      expect(soon.skipped, ['Remote OK', 'Jobicy']);

      // Past the sources' own minimum, a manual refresh fetches again while
      // an automatic one still waits.
      now = now.add(const Duration(hours: 2));
      await repo.refresh(manual: false);
      expect(requests, 2);
      await repo.refresh(manual: true);
      expect(requests, 4);
    });

    test('reports an unreadable body without touching stored jobs', () async {
      database.saveFetch('remoteok', [
        _job('1'),
      ], now.subtract(const Duration(days: 1)));

      final result = await repository(
        (request) async => http.Response('<html>blocked</html>', 200),
      ).refresh(manual: true);

      expect(result.errors.keys, containsAll(['Remote OK', 'Jobicy']));
      expect(result.errors['Remote OK'], 'format data tidak dikenali');
      expect(database.search().single.id, 'remoteok:1');
    });
  });
}
