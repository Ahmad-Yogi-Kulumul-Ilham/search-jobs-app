/// The details application forms ask for, entered once by the user.
class ApplicantProfile {
  const ApplicantProfile({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.linkedin = '',
    this.github = '',
    this.portfolio = '',
    this.salaryExpectation = '',
    this.noticePeriod = '',
  });

  factory ApplicantProfile.fromJson(Map<String, Object?> json) {
    String text(String key) => '${json[key] ?? ''}';
    return ApplicantProfile(
      fullName: text('fullName'),
      email: text('email'),
      phone: text('phone'),
      location: text('location'),
      linkedin: text('linkedin'),
      github: text('github'),
      portfolio: text('portfolio'),
      salaryExpectation: text('salaryExpectation'),
      noticePeriod: text('noticePeriod'),
    );
  }

  final String fullName;
  final String email;

  /// With country code, such as `+62 812 3456 7890`.
  final String phone;

  /// Such as `Jakarta, Indonesia`.
  final String location;
  final String linkedin;
  final String github;
  final String portfolio;
  final String salaryExpectation;
  final String noticePeriod;

  /// Everything before the last word of [fullName].
  String get firstName {
    final parts = _nameParts;
    return parts.length <= 1
        ? fullName.trim()
        : parts.sublist(0, parts.length - 1).join(' ');
  }

  /// The last word of [fullName], or empty for a single-word name (common in
  /// Indonesia).
  String get lastName {
    final parts = _nameParts;
    return parts.length <= 1 ? '' : parts.last;
  }

  List<String> get _nameParts =>
      fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

  bool get isEmpty => fullName.trim().isEmpty && email.trim().isEmpty;

  Map<String, Object?> toJson() => {
    'fullName': fullName.trim(),
    'email': email.trim(),
    'phone': phone.trim(),
    'location': location.trim(),
    'linkedin': linkedin.trim(),
    'github': github.trim(),
    'portfolio': portfolio.trim(),
    'salaryExpectation': salaryExpectation.trim(),
    'noticePeriod': noticePeriod.trim(),
  };
}
