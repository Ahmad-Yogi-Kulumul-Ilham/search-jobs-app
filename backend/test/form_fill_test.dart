import 'dart:convert';
import 'dart:typed_data';

import 'package:search_jobs_backend/search_jobs_backend.dart';
import 'package:test/test.dart';

Job _job(String url) =>
    Job(id: 'x:1', sourceId: 'x', title: 'Engineer', company: 'Acme', url: url);

SavedAnswer _answer(int id, String question) => SavedAnswer(
  id: id,
  question: question,
  answer: 'Answer $id',
  updatedAt: DateTime(2026),
);

void main() {
  test('applicationUrl points at the form for known job boards', () {
    expect(
      applicationUrl(_job('https://jobs.lever.co/spotify/abc')),
      'https://jobs.lever.co/spotify/abc/apply',
    );
    expect(
      applicationUrl(_job('https://jobs.lever.co/spotify/abc/apply')),
      'https://jobs.lever.co/spotify/abc/apply',
    );
    expect(
      applicationUrl(_job('https://jobs.ashbyhq.com/linear/d3bc/')),
      'https://jobs.ashbyhq.com/linear/d3bc/application',
    );
    // Greenhouse shows the form on the posting page itself.
    expect(
      applicationUrl(_job('https://job-boards.greenhouse.io/gitlab/jobs/1')),
      'https://job-boards.greenhouse.io/gitlab/jobs/1',
    );
    expect(
      applicationUrl(_job('https://remoteok.com/remote-jobs/1')),
      'https://remoteok.com/remote-jobs/1',
    );
  });

  test('ApplicantProfile splits names the way forms ask for them', () {
    const full = ApplicantProfile(fullName: '  Budi Santoso  Wibowo ');
    expect(full.firstName, 'Budi Santoso');
    expect(full.lastName, 'Wibowo');
    const single = ApplicantProfile(fullName: 'Sukarno');
    expect(single.firstName, 'Sukarno');
    expect(single.lastName, isEmpty);
    expect(const ApplicantProfile().isEmpty, isTrue);

    final json = const ApplicantProfile(
      fullName: 'Budi',
      email: ' budi@example.com ',
      linkedin: 'linkedin.com/in/budi',
    ).toJson();
    final back = ApplicantProfile.fromJson(json);
    expect(back.email, 'budi@example.com');
    expect(back.linkedin, 'linkedin.com/in/budi');
  });

  test('fillFormScript embeds the data as JSON', () {
    final cv = Cv(
      id: 1,
      name: 'CV',
      fileName: 'Budi "CV".pdf',
      format: CvFormat.pdf,
      bytes: Uint8List.fromList([37, 80, 68, 70]),
      text: '',
      createdAt: DateTime(2026),
    );
    final script = fillFormScript(
      const ApplicantProfile(fullName: "Budi O'Brien", email: 'b@x.io'),
      cv: cv,
    );
    final data = RegExp(r'const data = (.*);\n').firstMatch(script)![1]!;
    final decoded = jsonDecode(data) as Map<String, Object?>;
    final profile = decoded['profile'] as Map;
    expect(profile['fullName'], "Budi O'Brien");
    expect(profile['firstName'], 'Budi');
    expect(profile['lastName'], "O'Brien");
    final resume = decoded['resume'] as Map;
    expect(resume['name'], 'Budi "CV".pdf');
    expect(resume['type'], 'application/pdf');
    expect(base64Decode(resume['base64'] as String), [37, 80, 68, 70]);
    expect(script, isNot(contains('__DATA__')));
    expect(script, isNot(contains('submit()')));

    expect(
      answerQuestionScript(0, 'x'),
      contains('[data-sja-question="0"]'),
    );
    expect(
      answerQuestionScript(3, 'He said "hi"\n'),
      contains(r'"He said \"hi\"\n"'),
    );
  });

  test('FillReport.parse accepts the object or its JSON text', () {
    const raw =
        '{"filled":["email"],"resumeAttached":true,"resumeFieldFound":true,'
        '"questions":[{"index":0,"label":"Why us?*","required":true,"multiline":true}]}';
    for (final result in [raw, jsonEncode(raw), jsonDecode(raw)]) {
      final report = FillReport.parse(result)!;
      expect(report.filled, ['email']);
      expect(report.resumeAttached, isTrue);
      expect(report.questions.single.label, 'Why us?*');
      expect(report.questions.single.multiline, isTrue);
    }
    expect(FillReport.parse(null), isNull);
    expect(FillReport.parse('not json'), isNull);
    expect(FillReport.parse(42), isNull);
  });

  test('bestSavedAnswer matches questions by shared words', () {
    final answers = [
      _answer(1, 'Why do you want to work here?'),
      _answer(2, 'What are your salary expectations?'),
      _answer(3, 'Tell us about yourself'),
    ];

    expect(
      bestSavedAnswer('What are your salary expectations (USD)?*', answers)?.id,
      2,
    );
    expect(
      bestSavedAnswer('Why do you want to work at GitLab?', answers)?.id,
      1,
    );
    expect(bestSavedAnswer('Tell us about yourself.', answers)?.id, 3);
    expect(bestSavedAnswer('What timezone are you in?', answers), isNull);
    expect(bestSavedAnswer('', answers), isNull);
    expect(bestSavedAnswer('Salary?', const []), isNull);
  });
}
