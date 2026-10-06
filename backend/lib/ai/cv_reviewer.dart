import 'dart:convert';

import '../models/cv.dart';
import '../models/job.dart';
import 'claude_client.dart';

/// One suggested change to the CV.
class CvSuggestion {
  const CvSuggestion({
    required this.section,
    required this.original,
    required this.revised,
    required this.reason,
  });

  factory CvSuggestion.fromJson(Map<String, Object?> json) => CvSuggestion(
    section: '${json['section'] ?? ''}',
    original: '${json['original'] ?? ''}',
    revised: '${json['revised'] ?? ''}',
    reason: '${json['reason'] ?? ''}',
  );

  final String section;

  /// The current CV text, or empty when the suggestion adds a new line.
  final String original;
  final String revised;
  final String reason;

  Map<String, Object?> toJson() => {
    'section': section,
    'original': original,
    'revised': revised,
    'reason': reason,
  };
}

/// How well a CV fits one job, and how to tailor it.
class CvReview {
  const CvReview({
    required this.score,
    required this.verdict,
    required this.strengths,
    required this.gaps,
    required this.missingKeywords,
    required this.suggestions,
    required this.locationCheck,
  });

  factory CvReview.fromJson(Map<String, Object?> json) {
    List<String> strings(Object? value) => [
      for (final item in value is List ? value : const []) '$item',
    ];
    final score = json['score'];
    return CvReview(
      score: (score is num ? score.round() : 0).clamp(0, 100),
      verdict: '${json['verdict'] ?? ''}',
      strengths: strings(json['strengths']),
      gaps: strings(json['gaps']),
      missingKeywords: strings(json['missing_keywords']),
      suggestions: [
        for (final item
            in json['suggestions'] is List
                ? json['suggestions'] as List
                : const [])
          if (item is Map<String, Object?>) CvSuggestion.fromJson(item),
      ],
      locationCheck: '${json['location_check'] ?? ''}',
    );
  }

  /// 0 to 100.
  final int score;
  final String verdict;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> missingKeywords;
  final List<CvSuggestion> suggestions;

  /// What the posting says about hiring someone based in Indonesia.
  final String locationCheck;

  Map<String, Object?> toJson() => {
    'score': score,
    'verdict': verdict,
    'strengths': strengths,
    'gaps': gaps,
    'missing_keywords': missingKeywords,
    'suggestions': [for (final s in suggestions) s.toJson()],
    'location_check': locationCheck,
  };
}

/// A drafted cover letter.
class CoverLetter {
  const CoverLetter({required this.subject, required this.body});

  final String subject;
  final String body;
}

/// What a review or draft cost, for showing the user.
class AiUsage {
  const AiUsage({required this.model, required this.costUsd});

  final String model;
  final double costUsd;
}

/// The AI features built on Claude: reviewing a CV against a job, drafting a
/// cover letter, and drafting answers to application questions.
class CvReviewer {
  CvReviewer(this._client);

  final ClaudeClient _client;

  Future<(CvReview, AiUsage)> review({
    required Cv cv,
    required Job job,
    required String jobDescription,
  }) async {
    final result = await _client.createJson(
      system: _reviewSystem,
      content: [
        _cvBlock(cv),
        _jobBlock(job, jobDescription),
        {'type': 'text', 'text': 'Review my CV against this job posting.'},
      ],
      schema: _reviewSchema,
    );
    return (CvReview.fromJson(result.json), _usage(result));
  }

  Future<(CoverLetter, AiUsage)> coverLetter({
    required Cv cv,
    required Job job,
    required String jobDescription,
  }) async {
    final result = await _client.createJson(
      system: _coverLetterSystem,
      content: [
        _cvBlock(cv),
        _jobBlock(job, jobDescription),
        {'type': 'text', 'text': 'Write my cover letter for this job.'},
      ],
      schema: _coverLetterSchema,
      effort: 'medium',
    );
    return (
      CoverLetter(
        subject: '${result.json['subject'] ?? ''}',
        body: '${result.json['letter'] ?? ''}',
      ),
      _usage(result),
    );
  }

  /// Drafts an answer to an application question, tailored to [job] when
  /// given.
  Future<(String, AiUsage)> draftAnswer({
    required Cv cv,
    required String question,
    Job? job,
    String jobDescription = '',
  }) async {
    final result = await _client.createJson(
      system: _answerSystem,
      content: [
        _cvBlock(cv),
        if (job != null) _jobBlock(job, jobDescription),
        {'type': 'text', 'text': 'Question:\n$question'},
      ],
      schema: _answerSchema,
      effort: 'medium',
    );
    return ('${result.json['answer'] ?? ''}', _usage(result));
  }

  AiUsage _usage(AiResult result) =>
      AiUsage(model: result.model, costUsd: result.costUsd);
}

/// The CV as a document block: a PDF is passed as is for Claude to read,
/// other formats as their extracted text.
Map<String, Object?> _cvBlock(Cv cv) => {
  'type': 'document',
  'title': 'My CV (${cv.fileName})',
  'source': cv.format == CvFormat.pdf
      ? {
          'type': 'base64',
          'media_type': 'application/pdf',
          'data': base64Encode(cv.bytes),
        }
      : {'type': 'text', 'media_type': 'text/plain', 'data': cv.text},
};

Map<String, Object?> _jobBlock(Job job, String description) => {
  'type': 'document',
  'title': 'Job posting: ${job.title}',
  'source': {
    'type': 'text',
    'media_type': 'text/plain',
    'data': [
      'Title: ${job.title}',
      if (job.company.isNotEmpty) 'Company: ${job.company}',
      if (job.location.isNotEmpty) 'Location: ${job.location}',
      if (job.jobType.isNotEmpty) 'Job type: ${job.jobType}',
      if (job.salary.isNotEmpty) 'Salary: ${job.salary}',
      '',
      description.isEmpty ? '(No description provided.)' : description,
    ].join('\n'),
  },
};

const _honesty =
    'Never add experience, skills, employers, titles, dates, or numbers that '
    'the CV does not support: interviewers will ask about them. Rewriting may '
    'reorder, rephrase, and emphasize what is already there.';

const _reviewSystem =
    'You help a job seeker based in Indonesia apply for remote jobs at '
    'companies abroad. You receive their CV and one job posting, and assess '
    'how well the CV fits the posting and how to tailor it for this '
    'application.\n\n'
    'Be honest and specific: name the requirements the posting states and '
    'point to what in the CV does or does not back them up. $_honesty Where '
    'a gap cannot be closed honestly, list it as a gap rather than papering '
    'over it.\n\n'
    'Write explanations in Indonesian. Write rewritten CV text in the '
    "language of the CV, ready to paste.\n\n"
    'Also read what the posting says about where candidates may live, '
    'time-zone overlap, and work authorization, and say plainly whether '
    'someone in Indonesia can apply.';

const _coverLetterSystem =
    'You write cover letters for a job seeker based in Indonesia applying '
    'for remote jobs abroad. Write in the language of the job posting, in '
    'the first person, in a warm and direct professional tone, about 250 to '
    '350 words. Connect the two or three most relevant things from the CV to '
    "what this posting asks for, and say why this company and role. $_honesty "
    'Do not use placeholders except for facts only the candidate knows and '
    'the CV lacks, written in square brackets.';

const _answerSystem =
    'You draft answers to job application questions for a job seeker based '
    'in Indonesia applying for remote jobs abroad. Answer in the language of '
    'the question, in the first person, concisely: a few sentences unless '
    'the question needs more. Ground the answer in the CV and, when given, '
    "the job posting. $_honesty Where the answer depends on something only "
    'the candidate knows, such as salary expectations or notice period, '
    'leave a short placeholder in square brackets.';

const _reviewSchema = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': [
    'score',
    'verdict',
    'strengths',
    'gaps',
    'missing_keywords',
    'suggestions',
    'location_check',
  ],
  'properties': {
    'score': {
      'type': 'integer',
      'description':
          '0 to 100: how likely this CV, as written, is to pass screening '
          'for this role. 80 and up is a strong match, 60 to 79 reasonable '
          'with tailoring, 40 to 59 notable gaps, below 40 a poor fit.',
    },
    'verdict': {
      'type': 'string',
      'description': 'One or two sentences in Indonesian summing up the fit.',
    },
    'strengths': {
      'type': 'array',
      'items': {'type': 'string'},
      'description': 'Requirements the CV clearly meets, with the evidence.',
    },
    'gaps': {
      'type': 'array',
      'items': {'type': 'string'},
      'description': 'Requirements the CV does not show.',
    },
    'missing_keywords': {
      'type': 'array',
      'items': {'type': 'string'},
      'description':
          'Terms from the posting that applicant tracking systems may look '
          'for and the CV lacks, only where the candidate plausibly has '
          'them.',
    },
    'suggestions': {
      'type': 'array',
      'description': 'The most valuable edits, most important first.',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['section', 'original', 'revised', 'reason'],
        'properties': {
          'section': {'type': 'string'},
          'original': {
            'type': 'string',
            'description': 'Current CV text, or empty when adding a line.',
          },
          'revised': {'type': 'string'},
          'reason': {'type': 'string'},
        },
      },
    },
    'location_check': {
      'type': 'string',
      'description':
          'In Indonesian: what the posting says about location, time zones, '
          'or work authorization, and whether someone in Indonesia can '
          'apply.',
    },
  },
};

const _coverLetterSchema = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': ['subject', 'letter'],
  'properties': {
    'subject': {
      'type': 'string',
      'description': 'An email subject line for the application.',
    },
    'letter': {'type': 'string'},
  },
};

const _answerSchema = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': ['answer'],
  'properties': {
    'answer': {'type': 'string'},
  },
};
