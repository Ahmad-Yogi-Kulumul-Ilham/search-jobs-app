/// How senior a role is, as its title says.
enum Seniority {
  intern('Magang'),
  junior('Junior'),
  mid('Menengah'),
  senior('Senior'),
  lead('Lead / Principal'),
  executive('Pimpinan (Head, Director, VP)');

  const Seniority(this.label);

  final String label;

  static Seniority? byName(String? name) =>
      values.where((level) => level.name == name).firstOrNull;
}

/// Shown for titles that name no level, and stored in filters as this key.
const unspecifiedSeniority = 'none';
const unspecifiedSeniorityLabel = 'Tidak disebut';

/// The label for a level key as stored in filters.
String seniorityLabel(String key) =>
    Seniority.byName(key)?.label ?? unspecifiedSeniorityLabel;

RegExp _words(String pattern) => RegExp(pattern, caseSensitive: false);

/// Checked from the most specific level down, so "Senior Staff Engineer"
/// is lead and "Director, Senior Programs" is executive.
final _rules = <(Seniority, RegExp)>[
  // Not "Internship Program Manager" or "Intern Recruiter": those run the
  // programme rather than join it.
  (
    Seniority.intern,
    _words(
      r'\b(intern|interns|internship|magang|trainee|apprentice(ship)?)\b'
      r'(?!\s+(programs?|coordinator|manager|recruit(er|ing)?)\b)',
    ),
  ),
  (
    Seniority.executive,
    _words(
      r'\b(head of|director|vice president|s?vp|chief|cto|ceo|cfo|coo|cmo|'
      r'cpo|ciso)\b',
    ),
  ),
  (
    Seniority.lead,
    // "Lead gen" is sales work (but "Lead GenAI Engineer" is a lead), and
    // "staff" alone often just means an employee ("Staff Accountant",
    // "Staff Data Entry"), so only staff in engineering-type roles.
    _words(
      r'\blead(?![\s-]*gen(eration)?\b)\b|\bleader\b|\bprincipal\b|'
      r'\bdistinguished\b|'
      r'\bstaff\s+(software|engineer|developer|data\s+(scientist|engineer)|'
      r'machine\s+learning|ml|product\s+(manager|designer)|designer|'
      r'scientist|frontend|front-end|backend|back-end|full[- ]?stack|'
      r'site\s+reliability|security\s+engineer|platform|infrastructure|'
      r'mobile|ios|android|research\s+(scientist|engineer))\b',
    ),
  ),
  (Seniority.senior, _words(r'\b(senior|sr|snr)\b\.?')),
  // A bare "mid" only, not "Mid-Atlantic", "Mid-Size" or "Mid Market",
  // which are regions and sales segments.
  (
    Seniority.mid,
    _words(
      r'\b(midlevel|intermediate|'
      r'mid(?:[- ]?level|[- ]?senior)?(?![-\w])(?!\s+market))\b',
    ),
  ),
  (
    Seniority.junior,
    _words(r'\b(junior|jr|entry[- ]level|graduate|new grad)\b\.?'),
  ),
];

/// Roman level suffixes, as in "Software Engineer II", in capitals only.
final _roman = RegExp(r'\b(I{1,3}|IV)\b(?!\.)\s*(\(|,|-|$)');

/// Feeds such as Dribbble's put the company first: "Junior is hiring for a
/// position of Product Designer" names a company called Junior.
final _hiringPrefix = RegExp(
  r'^.*\bis hiring for a position of\s+',
  caseSensitive: false,
);

/// Who an assistant supports: "Executive Assistant to the CEO" is not a
/// chief executive's job.
final _supportedRole = RegExp(
  r'\b(to|for|supporting)\s+(the\s+|our\s+)?(ceo|cfo|coo|cto|cmo|cpo|'
  r'founders?|directors?|vp|vice president|president|chief|head of|'
  r'executives?|leadership)\b.*$',
  caseSensitive: false,
);

/// The level a job title names, or null when it names none.
Seniority? seniorityOf(String jobTitle) {
  final title = jobTitle
      .replaceFirst(_hiringPrefix, '')
      .replaceFirst(_supportedRole, '');
  for (final (level, pattern) in _rules) {
    if (pattern.hasMatch(title)) return level;
  }
  return switch (_roman.firstMatch(title)?.group(1)) {
    'I' => Seniority.junior,
    'II' => Seniority.mid,
    'III' => Seniority.senior,
    'IV' => Seniority.lead,
    _ => null,
  };
}
