import 'dart:convert';

import '../models/applicant_profile.dart';
import '../models/cv.dart';
import '../models/job.dart';

/// A form question the filler could not answer from the profile.
class FormQuestion {
  const FormQuestion({
    required this.index,
    required this.label,
    required this.required,
    required this.multiline,
  });

  factory FormQuestion.fromJson(Map<String, Object?> json) => FormQuestion(
    index: (json['index'] as num?)?.toInt() ?? -1,
    label: '${json['label'] ?? ''}',
    required: json['required'] == true,
    multiline: json['multiline'] == true,
  );

  /// Identifies the field for [answerQuestionScript].
  final int index;
  final String label;
  final bool required;

  /// A text area, which usually wants a longer answer.
  final bool multiline;
}

/// What a run of [fillFormScript] did on the page.
class FillReport {
  const FillReport({
    required this.filled,
    required this.resumeAttached,
    required this.resumeFieldFound,
    required this.questions,
  });

  /// Parses the script's result, which WebView2 may hand back either as the
  /// object or as its JSON text. Returns null for anything else.
  static FillReport? parse(Object? result) {
    Object? value = result;
    for (var i = 0; i < 2 && value is String; i++) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return null;
      }
    }
    if (value is! Map) return null;
    return FillReport(
      filled: [
        for (final item
            in value['filled'] is List ? value['filled'] as List : const [])
          '$item',
      ],
      resumeAttached: value['resumeAttached'] == true,
      resumeFieldFound: value['resumeFieldFound'] == true,
      questions: [
        for (final item
            in value['questions'] is List
                ? value['questions'] as List
                : const [])
          if (item is Map<String, Object?>) FormQuestion.fromJson(item),
      ],
    );
  }

  /// Names of the profile fields that were written, such as `email`.
  final List<String> filled;
  final bool resumeAttached;
  final bool resumeFieldFound;
  final List<FormQuestion> questions;
}

const _stopWords = {
  'a', 'an', 'and', 'are', 'as', 'at', 'be', 'do', 'does', 'for', 'from', //
  'have', 'how', 'i', 'in', 'is', 'it', 'me', 'my', 'of', 'on', 'or', //
  'our', 'please', 'tell', 'that', 'the', 'this', 'to', 'us', 'we', 'what', //
  'when', 'which', 'who', 'why', 'will', 'with', 'would', 'you', 'your', //
  'apa', 'anda', 'dan', 'di', 'ini', 'itu', 'kami', 'ke', 'yang',
};

Set<String> _words(String text) => {
  for (final word in text.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
    if (word.length > 1 && !_stopWords.contains(word)) word,
};

/// The saved answer whose question shares the most words with [question],
/// or null when none shares at least half of them.
SavedAnswer? bestSavedAnswer(String question, List<SavedAnswer> answers) {
  final asked = _words(question);
  if (asked.isEmpty) return null;
  SavedAnswer? best;
  var bestScore = 0.0;
  for (final answer in answers) {
    final saved = _words(answer.question);
    if (saved.isEmpty) continue;
    final shared = asked.intersection(saved).length;
    // Overlap relative to the shorter question, so a short saved question
    // still matches a long form label that contains it.
    final score =
        shared / (asked.length < saved.length ? asked.length : saved.length);
    if (score > bestScore) {
      bestScore = score;
      best = answer;
    }
  }
  return bestScore >= 0.5 ? best : null;
}

/// The page where the job's application form is, for the job boards whose
/// form lives at a known address. Other jobs open their posting page.
String applicationUrl(Job job) {
  final uri = Uri.tryParse(job.url);
  if (uri == null) return job.url;
  final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  if (uri.host == 'jobs.lever.co' && !path.endsWith('/apply')) {
    return uri.replace(path: '$path/apply').toString();
  }
  if (uri.host == 'jobs.ashbyhq.com' && !path.endsWith('/application')) {
    return uri.replace(path: '$path/application').toString();
  }
  return job.url;
}

/// JavaScript that fills an application form with [profile] and attaches
/// [cv], then reports what it did as JSON. It only types into empty fields
/// and never submits the form.
String fillFormScript(ApplicantProfile profile, {Cv? cv}) {
  final data = jsonEncode({
    'profile': {
      ...profile.toJson(),
      'firstName': profile.firstName,
      'lastName': profile.lastName,
    },
    'resume': cv == null
        ? null
        : {
            'name': cv.fileName,
            'type': cv.format.mimeType,
            'base64': base64Encode(cv.bytes),
          },
  });
  return _fillTemplate.replaceFirst('__DATA__', data);
}

/// JavaScript that types [answer] into the question at [index] from a
/// previous [fillFormScript] run. Evaluates to whether the field was found.
String answerQuestionScript(int index, String answer) => _answerTemplate
    .replaceFirst('__INDEX__', '$index')
    .replaceFirst('__ANSWER__', jsonEncode(answer));

const _setValueFunction = r'''
  function setValue(el, value) {
    const proto = el.tagName === 'TEXTAREA'
      ? HTMLTextAreaElement.prototype
      : HTMLInputElement.prototype;
    // React and similar frameworks track the value themselves, so set it
    // through the native setter and announce the change.
    Object.getOwnPropertyDescriptor(proto, 'value').set.call(el, value);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    el.dispatchEvent(new Event('blur', { bubbles: true }));
  }
''';

const _fillTemplate =
    '''
(function () {
  const data = __DATA__;
  const profile = data.profile;
  const report = { filled: [], resumeAttached: false, resumeFieldFound: false, questions: [] };
$_setValueFunction
  function clean(text) {
    return (text || '').replace(/\\s+/g, ' ').trim();
  }

  // Everything that names a field: its label, nearby question text, and
  // its own attributes.
  function describe(el) {
    const parts = [];
    if (el.id) {
      for (const label of document.querySelectorAll('label[for="' + CSS.escape(el.id) + '"]')) {
        parts.push(label.innerText);
      }
    }
    const wrapping = el.closest('label');
    if (wrapping) parts.push(wrapping.innerText);
    const labelledBy = el.getAttribute('aria-labelledby');
    if (labelledBy) {
      for (const id of labelledBy.split(/\\s+/)) {
        const node = document.getElementById(id);
        if (node) parts.push(node.innerText);
      }
    }
    if (parts.length === 0) {
      const field = el.closest('.application-question, .field, .form-group, fieldset, li, [class*="field"], [class*="Field"], [class*="question"]');
      const label = field && field.querySelector('label, legend, .application-label, .text');
      if (label) parts.push(label.innerText);
    }
    return {
      label: clean(parts.join(' ')),
      attributes: [el.name, el.id, el.getAttribute('aria-label'), el.placeholder, el.getAttribute('autocomplete')]
        .filter(Boolean).join(' '),
    };
  }

  const exclude = /company|employer|school|university|college|reference|referr|recruiter|manager|pronoun|preferred name|nickname|emergency|hiring/i;
  // Checked in order; the first match decides.
  const rules = [
    ['firstName', /first.?name|given.?name|nama depan|\\bfname\\b/i],
    ['lastName', /last.?name|family.?name|surname|nama belakang|\\blname\\b/i],
    ['email', /e-?mail/i],
    ['phone', /phone|mobile|telepon|whats ?app|\\btel\\b/i],
    ['linkedin', /linked.?in/i],
    ['github', /git.?hub/i],
    ['portfolio', /portfolio|website|personal (site|url)|blog|other (link|url)/i],
    ['salaryExpectation', /salary|compensation|expected (pay|rate)|gaji|rate expectation/i],
    ['noticePeriod', /notice period|earliest start|start date|when can you start/i],
    ['location', /location|city|where are you (based|located)|current address|country of residence|domisili/i],
    ['fullName', /full.?name|^\\s*name\\b|\\byour name\\b|nama lengkap|^\\s*nama\\b|candidate.?name/i],
  ];

  function profileKey(el, info) {
    const auto = (el.getAttribute('autocomplete') || '').toLowerCase();
    const byAutocomplete = { 'given-name': 'firstName', 'family-name': 'lastName', 'name': 'fullName', 'email': 'email', 'tel': 'phone' };
    if (byAutocomplete[auto]) return byAutocomplete[auto];
    if (el.type === 'email') return 'email';
    if (el.type === 'tel') return 'phone';
    for (const text of [info.label, info.attributes]) {
      if (!text || exclude.test(text)) continue;
      for (const [key, pattern] of rules) {
        if (pattern.test(text)) return key;
      }
    }
    return null;
  }

  function visible(el) {
    const style = window.getComputedStyle(el);
    return style.display !== 'none' && style.visibility !== 'hidden' && el.getClientRects().length > 0;
  }

  const textTypes = ['', 'text', 'email', 'tel', 'url', 'search'];
  const fields = Array.from(document.querySelectorAll('input, textarea')).filter(function (el) {
    if (el.disabled || el.readOnly) return false;
    if (el.tagName === 'TEXTAREA') return visible(el);
    return textTypes.includes((el.getAttribute('type') || '').toLowerCase()) && visible(el);
  });

  let questionIndex = 0;
  for (const el of fields) {
    if (el.value) continue;
    const info = describe(el);
    const key = profileKey(el, info);
    if (key) {
      // An empty profile value, such as the last name of a one-word name,
      // leaves the field for the user.
      if (profile[key]) {
        setValue(el, profile[key]);
        report.filled.push(key);
      }
      continue;
    }
    const label = info.label || clean(el.getAttribute('aria-label') || el.placeholder || '');
    if (!label) continue;
    el.setAttribute('data-sja-question', String(questionIndex));
    report.questions.push({
      index: questionIndex,
      label: label.slice(0, 300),
      required: el.required || el.getAttribute('aria-required') === 'true' || /\\*\\s*\$/.test(label),
      multiline: el.tagName === 'TEXTAREA',
    });
    questionIndex++;
  }

  // The CV goes into a file input that mentions a resume or CV, or into the
  // only file input on the page.
  const fileInputs = Array.from(document.querySelectorAll('input[type="file"]')).filter(function (el) {
    return !el.disabled;
  });
  let resumeInput = fileInputs.find(function (el) {
    const info = describe(el);
    return /resume|r[eé]sum[eé]|\\bcv\\b|curriculum/i.test(info.label + ' ' + info.attributes);
  });
  if (!resumeInput && fileInputs.length === 1) resumeInput = fileInputs[0];
  report.resumeFieldFound = Boolean(resumeInput);
  if (resumeInput && data.resume && resumeInput.files.length === 0) {
    try {
      const binary = atob(data.resume.base64);
      const bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
      const transfer = new DataTransfer();
      transfer.items.add(new File([bytes], data.resume.name, { type: data.resume.type }));
      resumeInput.files = transfer.files;
      resumeInput.dispatchEvent(new Event('input', { bubbles: true }));
      resumeInput.dispatchEvent(new Event('change', { bubbles: true }));
      report.resumeAttached = resumeInput.files.length === 1;
    } catch (error) {
      report.resumeAttached = false;
    }
  }
  return JSON.stringify(report);
})();
''';

const _answerTemplate =
    '''
(function () {
$_setValueFunction
  const el = document.querySelector('[data-sja-question="__INDEX__"]');
  if (!el) return false;
  setValue(el, __ANSWER__);
  el.scrollIntoView({ block: 'center' });
  return true;
})();
''';
