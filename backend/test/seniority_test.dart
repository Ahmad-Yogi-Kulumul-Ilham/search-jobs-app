import 'package:search_jobs_backend/search_jobs_backend.dart';
import 'package:test/test.dart';

void main() {
  test('reads the level a title names', () {
    expect(seniorityOf('Senior Flutter Engineer'), Seniority.senior);
    expect(seniorityOf('Sr. Data Analyst'), Seniority.senior);
    expect(seniorityOf('Junior Payroll Assistant'), Seniority.junior);
    expect(seniorityOf('QA Tester Entry Level'), Seniority.junior);
    expect(seniorityOf('Intermediate Laravel Developer'), Seniority.mid);
    expect(seniorityOf('Staff Software Engineer'), Seniority.lead);
    expect(seniorityOf('Senior Staff Product Manager'), Seniority.lead);
    expect(seniorityOf('Tech Lead, Payments'), Seniority.lead);
    expect(seniorityOf('Director of Design'), Seniority.executive);
    expect(seniorityOf('Head of Growth'), Seniority.executive);
    expect(seniorityOf('Marketing Intern'), Seniority.intern);
    expect(seniorityOf('Software Engineer II'), Seniority.mid);
    expect(seniorityOf('Support Engineer III (Remote)'), Seniority.senior);
    expect(seniorityOf('Product Designer'), isNull);
  });

  test('ignores words that only look like levels', () {
    expect(seniorityOf('Lead Generation Specialist'), isNull);
    expect(seniorityOf('Staff Accountant'), isNull);
    expect(seniorityOf('Account Executive, Mid-Market'), isNull);
    expect(seniorityOf('AI Researcher'), isNull);
    // "Staff" as in employee, which Indonesian titles use a lot.
    expect(seniorityOf('Staff Data Entry'), isNull);
    expect(seniorityOf('Staff Security'), isNull);
    expect(seniorityOf('Staff Research Assistant'), isNull);
    expect(seniorityOf('Staff Data Scientist'), Seniority.lead);
    expect(seniorityOf('Staff Full-Stack Developer'), Seniority.lead);
    // Assistants to executives are not executives.
    expect(seniorityOf('Executive Assistant to the CEO'), isNull);
    expect(seniorityOf('Personal Assistant to the Director'), isNull);
    expect(
      seniorityOf('Senior Executive Assistant to the CEO'),
      Seniority.senior,
    );
    // Regions and sales segments are not mid level.
    expect(seniorityOf('Territory Sales Manager - Mid-Atlantic'), isNull);
    expect(seniorityOf('Account Executive, Mid-Size Business'), isNull);
    expect(seniorityOf('Account Executive, Mid Market'), isNull);
    expect(seniorityOf('Mid-Level Backend Developer'), Seniority.mid);
    expect(seniorityOf('Mid Frontend Engineer'), Seniority.mid);
    // Sales "lead gen" is not a lead role, but GenAI leads are.
    expect(seniorityOf('Lead-Gen Specialist'), isNull);
    expect(seniorityOf('Lead GenAI Engineer'), Seniority.lead);
    expect(seniorityOf('Lead Generative AI Engineer'), Seniority.lead);
    // Running an internship programme is not an internship.
    expect(seniorityOf('Head of Internship Program'), Seniority.executive);
    expect(seniorityOf('Internship Program Manager'), isNull);
    // Dribbble names the company first; here the company is "Junior".
    expect(
      seniorityOf('Junior is hiring for a position of Product Designer'),
      isNull,
    );
    expect(
      seniorityOf('Acme is hiring for a position of Senior Designer'),
      Seniority.senior,
    );
  });

  test('filters and counts the job list by level', () {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    Job job(String id, String title) => Job(
      id: 'remoteok:$id',
      sourceId: 'remoteok',
      title: title,
      company: 'Acme',
      url: 'https://remoteok.com/remote-jobs/$id',
    );
    database.jobs.saveFetch('remoteok', [
      job('1', 'Senior Flutter Engineer'),
      job('2', 'Junior Designer'),
      job('3', 'Product Designer'),
      job('4', 'Sr. Writer'),
    ], DateTime(2026, 10, 7));

    List<String> titles(Set<String> levels) => [
      for (final job in database.jobs.search(filter: JobFilter(levels: levels)))
        job.title,
    ]..sort();

    expect(titles({'senior'}), ['Senior Flutter Engineer', 'Sr. Writer']);
    expect(titles({'junior', unspecifiedSeniority}), [
      'Junior Designer',
      'Product Designer',
    ]);
    expect(database.jobs.levelCounts(), {
      'senior': 2,
      'junior': 1,
      unspecifiedSeniority: 1,
    });

    const filter = JobFilter(levels: {'senior', unspecifiedSeniority});
    expect(JobFilter.fromJson(filter.toJson()).levels, filter.levels);
    expect(filter.describe(), 'Senior/Tidak disebut');
  });
}
