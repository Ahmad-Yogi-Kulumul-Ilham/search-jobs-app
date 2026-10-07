import 'package:search_jobs_backend/search_jobs_backend.dart';
import 'package:test/test.dart';

Job _job(String id, String location) => Job(
  id: 'remoteok:$id',
  sourceId: 'remoteok',
  title: 'Job $id',
  company: 'Acme',
  url: 'https://remoteok.com/remote-jobs/$id',
  location: location,
);

void main() {
  test('reads countries, regions, and "anywhere" from locations', () {
    expect(placesIn('Remote - USA'), {'US'});
    expect(placesIn('Austin, TX'), {'US'});
    expect(placesIn('Remote, Canada; Remote, United States'), {'US', 'CA'});
    expect(placesIn('Asia, Hong Kong, Taiwan, Taipei'), {'R-APAC', 'HK', 'TW'});
    expect(placesIn('North America, APJ, EMEA'), {'R-NA', 'R-APAC', 'R-EU'});
    expect(placesIn('Home based - Worldwide'), {'WW'});
    expect(placesIn('Remote - Singapore'), {'SG'});
    expect(placesIn('Bengaluru'), {'IN'});
    expect(placesIn('London, UK'), {'GB'});
    expect(placesIn('Remote'), isEmpty);
    expect(placesIn(''), isEmpty);
  });

  test('avoids look-alike names', () {
    // "Wales" inside New South Wales is not the UK.
    expect(placesIn('New South Wales'), {'AU'});
    // "Latin America" is a region, not the United States.
    expect(placesIn('Latin America'), {'R-LATAM'});
    // A country code after a comma is not a US state.
    expect(placesIn('Jakarta, ID'), {'ID'});
    // "us" in lowercase is a word, not the country.
    expect(placesIn('Join us anywhere'), {'WW'});
    expect(placesIn('Indiana'), {'US'});
    expect(placesIn('India'), {'IN'});
  });

  group('the job list', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.inMemory();
      database.jobs.saveFetch('remoteok', [
        _job('1', 'Remote - USA'),
        _job('2', 'Remote - Singapore'),
        _job('3', 'Anywhere in the World'),
        _job('4', 'Remote, Canada; Remote, United States'),
        _job('5', 'Remote'),
      ], DateTime(2026, 10, 7));
    });
    tearDown(() => database.close());

    List<String> ids(Set<String> places) => [
      for (final job in database.jobs.search(filter: JobFilter(places: places)))
        job.id.split(':').last,
    ]..sort();

    test('keeps jobs that name any picked place', () {
      expect(ids({'US'}), ['1', '4']);
      expect(ids({'SG', 'WW'}), ['2', '3']);
      expect(ids({}), ['1', '2', '3', '4', '5']);
    });

    test('counts jobs per place for the menu', () {
      expect(database.jobs.placeCounts(), {'US': 2, 'SG': 1, 'WW': 1, 'CA': 1});
      // Hidden jobs are not counted.
      database.jobs.setHidden('remoteok:1', true);
      expect(database.jobs.placeCounts()['US'], 1);
    });
  });

  test('a saved search keeps its countries', () {
    const filter = JobFilter(query: 'flutter', places: {'SG', 'WW'});
    final restored = JobFilter.fromJson(filter.toJson());
    expect(restored.places, {'SG', 'WW'});
    expect(filter.activeCount, 1);
    expect(filter.describe(), '"flutter" · Singapura/Seluruh dunia');
  });
}
