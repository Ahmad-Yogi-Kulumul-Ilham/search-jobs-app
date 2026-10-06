/// A pattern common in fake remote job offers.
class _Rule {
  const _Rule(this.warning, this.pattern);

  final String warning;
  final RegExp pattern;
}

final _rules = [
  _Rule(
    'Meminta pelamar membayar biaya (pendaftaran, pelatihan, atau peralatan)',
    RegExp(
      r'\b(registration|application|training|onboarding|processing|starter[- ]kit)\s+fee\b|'
      r'\bpay\b.{0,40}\b(for|upfront)\b.{0,30}\b(training|equipment|kit|registration|certification|background check)\b|'
      r'\b(refundable )?deposit\b.{0,40}\b(required|to start|before)\b|'
      r'\bbiaya (pendaftaran|pelatihan|administrasi)\b',
      caseSensitive: false,
    ),
  ),
  _Rule(
    'Kontak hanya lewat Telegram atau WhatsApp',
    RegExp(
      r'\b(contact|message|text|reach|dm|chat with|interview (via|on|over))\b.{0,40}\b(telegram|whatsapp|signal)\b|'
      r'\bt\.me/|\bwa\.me/',
      caseSensitive: false,
    ),
  ),
  _Rule(
    'Pembayaran lewat kripto, kartu hadiah, atau cek',
    RegExp(
      // Gift cards and crypto are ordinary as benefits or products, so only
      // being paid in them, or told to buy them, counts.
      r"\b(paid|pay you|payment|salary|compensation)\b.{0,30}\b(in|via|with|through)\s+(gift ?cards?|bitcoin|crypto|usdt)\b|"
      r"\b(buy|purchase)\b.{0,30}\bgift ?cards?\b|"
      r"\bcashier.?s check\b|\bmobile check deposit\b|"
      r"\bcheck (to|for) (buy|purchase)\b",
      caseSensitive: false,
    ),
  ),
  _Rule(
    'Menjanjikan penghasilan besar dengan mudah',
    RegExp(
      r'\b(earn|make)\s+(up to\s+)?\$\s?\d[\d,]{2,}\s*(\+\s*)?(per|a|/)\s*(day|week)\b|'
      r'\b(no experience|no skills?) (needed|required)\b.{0,80}\$\s?\d[\d,]{2,}|'
      r'\b(get rich|financial freedom|be your own boss)\b',
      caseSensitive: false,
    ),
  ),
  _Rule(
    'Rekrutmen lewat email pribadi (Gmail, Yahoo, dan sejenisnya)',
    RegExp(
      r'[\w.+-]+@(gmail|yahoo|hotmail|outlook|aol|proton|protonmail)\.(com|me)\b',
      caseSensitive: false,
    ),
  ),
];

/// Warnings for patterns often seen in fraudulent remote job offers. These
/// are hints for the user to look closer, not a verdict: a real posting can
/// trip one, and a fake one can avoid them all.
///
/// Salary size alone is deliberately not a signal: on real job boards it
/// flagged only genuine senior and executive roles.
List<String> scamWarnings({
  required String title,
  required String company,
  required String descriptionText,
}) {
  final text = '$title\n$descriptionText';
  return [
    for (final rule in _rules)
      if (rule.pattern.hasMatch(text)) rule.warning,
    if (company.trim().isEmpty) 'Nama perusahaan tidak disebutkan',
  ];
}
