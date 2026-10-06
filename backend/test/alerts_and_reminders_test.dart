import 'package:search_jobs_backend/search_jobs_backend.dart';
import 'package:test/test.dart';

Job _job(
  String id, {
  required String title,
  String company = 'Acme',
  String location = 'Worldwide',
  String descriptionHtml = '<p>A normal job.</p>',
  SalaryRange? salary,
}) => Job(
  id: 'remoteok:$id',
  sourceId: 'remoteok',
  title: title,
  company: company,
  url: 'https://remoteok.com/remote-jobs/$id',
  location: location,
  descriptionHtml: descriptionHtml,
  salary: salary?.label ?? '',
  salaryRange: salary,
);

void main() {
  group('scamWarnings', () {
    List<String> check(String description, {String company = 'Acme'}) =>
        scamWarnings(
          title: 'Data Entry Assistant',
          company: company,
          descriptionText: description,
        );

    test('flags common fake-offer patterns', () {
      expect(check('There is a registration fee of \$50.'), [
        contains('membayar biaya'),
      ]);
      expect(check('You must pay upfront for the training materials.'), [
        contains('membayar biaya'),
      ]);
      expect(check('Contact our HR manager on Telegram to start.'), [
        contains('Telegram'),
      ]);
      expect(check('Apply at https://t.me/hiring_now'), [contains('Telegram')]);
      expect(check('We will send a cashier\'s check for equipment.'), [
        contains('kripto'),
      ]);
      expect(check('Your salary is paid in USDT every Friday.'), [
        contains('kripto'),
      ]);
      expect(check('Please purchase Apple gift cards for the client.'), [
        contains('kripto'),
      ]);
      expect(check('Earn \$500 per day from home!'), [
        contains('penghasilan besar'),
      ]);
      expect(check('Send your CV to hiring.team2026@gmail.com'), [
        contains('email pribadi'),
      ]);
      expect(check('A normal job.', company: ''), [
        'Nama perusahaan tidak disebutkan',
      ]);
    });

    test('leaves ordinary postings alone', () {
      for (final description in [
        'We cover training and equipment costs. Apply via our careers page.',
        'Experience with WhatsApp Business API integrations is a plus.',
        'Salary: \$90,000 - \$120,000 per year. Equity offered.',
        'Email jobs@acme.com with questions.',
        // Both seen on real postings: a perk, and a company's own product.
        'Wellness Program with gift card redemption and challenges.',
        'The platform built for businesses to send payouts: gift cards and '
            'money to anyone.',
        'Nobody checks every box. We have helped members earn \$85+ million.',
      ]) {
        expect(check(description), isEmpty, reason: description);
      }
    });
  });

  group('dueReminders', () {
    final now = DateTime(2026, 10, 20, 9);

    Application application(
      String id, {
      required ApplicationStatus status,
      DateTime? appliedAt,
      DateTime? followedUpAt,
      DateTime? interviewAt,
    }) => Application(
      jobId: id,
      status: status,
      title: 'Job $id',
      company: 'Acme',
      url: '',
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      appliedAt: appliedAt,
      followedUpAt: followedUpAt,
      interviewAt: interviewAt,
    );

    test('follow-up after a quiet week, counted from the last contact', () {
      final reminders = dueReminders([
        application(
          'old',
          status: ApplicationStatus.applied,
          appliedAt: now.subtract(const Duration(days: 9)),
        ),
        application(
          'recent',
          status: ApplicationStatus.applied,
          appliedAt: now.subtract(const Duration(days: 3)),
        ),
        application(
          'chased',
          status: ApplicationStatus.applied,
          appliedAt: now.subtract(const Duration(days: 20)),
          followedUpAt: now.subtract(const Duration(days: 2)),
        ),
        application(
          'chased-long-ago',
          status: ApplicationStatus.applied,
          appliedAt: now.subtract(const Duration(days: 30)),
          followedUpAt: now.subtract(const Duration(days: 8)),
        ),
        application(
          'rejected',
          status: ApplicationStatus.rejected,
          appliedAt: now.subtract(const Duration(days: 30)),
        ),
      ], now);

      expect(reminders.map((r) => r.application.jobId), [
        'old',
        'chased-long-ago',
      ]);
      expect(reminders.first.message, 'Belum ada kabar 9 hari sejak melamar');
      expect(reminders.last.message, contains('sejak follow-up terakhir'));
    });

    test('interviews in the next 24 hours come first', () {
      final reminders = dueReminders([
        application(
          'quiet',
          status: ApplicationStatus.applied,
          appliedAt: now.subtract(const Duration(days: 10)),
        ),
        application(
          'tomorrow',
          status: ApplicationStatus.interview,
          interviewAt: now.add(const Duration(hours: 20)),
        ),
        application(
          'next-week',
          status: ApplicationStatus.interview,
          interviewAt: now.add(const Duration(days: 6)),
        ),
        application(
          'yesterday',
          status: ApplicationStatus.interview,
          interviewAt: now.subtract(const Duration(days: 1)),
        ),
      ], now);

      expect(reminders.map((r) => r.application.jobId), ['tomorrow', 'quiet']);
      expect(reminders.first.kind, ReminderKind.interview);
      expect(reminders.first.message, 'Interview 21 Okt 2026 05.00');
    });
  });

  group('Announcer', () {
    late AppDatabase database;
    late Announcer announcer;
    final now = DateTime(2026, 10, 20, 9);

    setUp(() {
      database = AppDatabase.inMemory();
      announcer = Announcer(database);
    });

    tearDown(() => database.close());

    test('announces new jobs per matching saved search', () {
      database.alerts.add('Flutter', const JobFilter(query: 'flutter'));
      database.alerts.add(
        'Bisa dari Indonesia',
        const JobFilter(openToIndonesiaOnly: true),
      );
      database.alerts.add('Golang', const JobFilter(query: 'golang'));
      final newIds = database.jobs.saveFetch('remoteok', [
        _job('1', title: 'Flutter Developer', company: 'Lemon.io'),
        _job('2', title: 'Senior Flutter Engineer', location: 'USA'),
        _job('3', title: 'Designer'),
      ], now);

      final announcements = announcer.forNewJobs(newIds);
      expect(announcements.map((a) => a.title), [
        '2 lowongan baru: Bisa dari Indonesia',
        '2 lowongan baru: Flutter',
      ]);
      expect(
        announcements.last.body,
        'Flutter Developer · Lemon.io · dan 1 lainnya',
      );
      expect(announcer.forNewJobs(const []), isEmpty);
      expect(
        announcer.forNewJobs(newIds, excludedSources: {'remoteok'}),
        isEmpty,
      );
    });

    test('saved searches survive a round trip', () {
      const filter = JobFilter(
        query: 'react',
        openToIndonesiaOnly: true,
        jobTypes: {'Kontrak'},
        excludedSources: {'remotive'},
        withSalaryOnly: true,
      );
      final saved = database.alerts.add(' React ', filter);
      final loaded = database.alerts.all().single;

      expect(loaded.id, saved.id);
      expect(loaded.name, 'React');
      expect(loaded.filter.toJson(), filter.toJson());
      expect(
        loaded.filter.describe(),
        '"react" · bisa dari Indonesia · ada gaji · Kontrak · '
        '1 sumber dimatikan',
      );

      database.alerts.delete(saved.id);
      expect(database.alerts.all(), isEmpty);
    });

    test('announces each reminder once', () {
      final applied = database.applications.addManual(
        title: 'Data Analyst',
        company: 'Initech',
        url: '',
        status: ApplicationStatus.applied,
        now: now.subtract(const Duration(days: 8)),
      );

      final first = announcer.forReminders(now);
      expect(first.single.title, 'Saatnya follow-up');
      expect(
        first.single.body,
        'Data Analyst · Initech · Belum ada kabar 8 hari sejak melamar',
      );
      expect(
        announcer.forReminders(now.add(const Duration(hours: 1))),
        isEmpty,
      );

      // Following up restarts the clock; a week later it is due again.
      database.applications.markFollowedUp(applied.jobId, now: now);
      expect(announcer.forReminders(now.add(const Duration(days: 1))), isEmpty);
      expect(
        announcer.forReminders(now.add(const Duration(days: 7))).single.body,
        contains('sejak follow-up terakhir'),
      );
    });
  });

  test('stored jobs carry their scam warnings', () {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    database.jobs.saveFetch('remoteok', [
      _job(
        '1',
        title: 'Remote Assistant',
        descriptionHtml: '<p>Message us on <b>Telegram</b> to get started.</p>',
      ),
      _job('2', title: 'Engineer'),
    ], DateTime(2026, 10, 20));

    expect(database.jobs.find('remoteok:1')!.warnings, [contains('Telegram')]);
    expect(database.jobs.find('remoteok:2')!.warnings, isEmpty);
    expect(
      database.jobs.search(onlyIds: ['remoteok:2']).single.title,
      'Engineer',
    );
    expect(database.jobs.search(onlyIds: const []), isEmpty);
  });
}
