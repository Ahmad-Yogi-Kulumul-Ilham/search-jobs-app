import '../models/cv.dart';
import '../models/job.dart';
import 'ai_client.dart';

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

/// The kinds of interview question, in the order they are practised.
enum QuestionKind {
  behavioral('Pengalaman & perilaku'),
  technical('Teknis & keahlian'),
  role('Tentang peran & perusahaan'),
  remote('Kerja remote'),
  tricky('Pertanyaan sulit');

  const QuestionKind(this.label);

  final String label;

  static QuestionKind byName(Object? name) =>
      values.where((kind) => kind.name == name).firstOrNull ?? behavioral;
}

/// One likely interview question, with how to answer it.
class InterviewQuestion {
  const InterviewQuestion({
    required this.kind,
    required this.question,
    required this.why,
    required this.tips,
    required this.sampleAnswer,
  });

  factory InterviewQuestion.fromJson(Map<String, Object?> json) =>
      InterviewQuestion(
        kind: QuestionKind.byName(json['kind']),
        question: '${json['question'] ?? ''}',
        why: '${json['why'] ?? ''}',
        tips: '${json['tips'] ?? ''}',
        sampleAnswer: '${json['sample_answer'] ?? ''}',
      );

  final QuestionKind kind;

  /// In the language the interview will be held in, like the posting.
  final String question;

  /// Why interviewers ask it, in Indonesian.
  final String why;
  final String tips;

  /// A first-person answer built only from the CV.
  final String sampleAnswer;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'question': question,
    'why': why,
    'tips': tips,
    'sample_answer': sampleAnswer,
  };
}

/// Preparation for interviewing for one job with one CV.
class InterviewPrep {
  const InterviewPrep({
    required this.overview,
    required this.questions,
    required this.questionsToAsk,
    required this.toPrepare,
  });

  factory InterviewPrep.fromJson(Map<String, Object?> json) {
    List<Object?> list(String key) =>
        json[key] is List ? json[key] as List : const [];
    return InterviewPrep(
      overview: '${json['overview'] ?? ''}',
      questions: [
        for (final item in list('questions'))
          if (item is Map<String, Object?>) InterviewQuestion.fromJson(item),
      ],
      questionsToAsk: [for (final item in list('questions_to_ask')) '$item'],
      toPrepare: [for (final item in list('to_prepare')) '$item'],
    );
  }

  /// What the interviews will likely focus on, in Indonesian.
  final String overview;
  final List<InterviewQuestion> questions;

  /// Good questions for the candidate to ask the interviewer.
  final List<String> questionsToAsk;

  /// What to look up or get ready beforehand, in Indonesian.
  final List<String> toPrepare;

  Map<String, Object?> toJson() => {
    'overview': overview,
    'questions': [for (final q in questions) q.toJson()],
    'questions_to_ask': questionsToAsk,
    'to_prepare': toPrepare,
  };
}

/// A coach's view of one practice answer.
class AnswerFeedback {
  const AnswerFeedback({
    required this.rating,
    required this.summary,
    required this.strengths,
    required this.improvements,
    required this.improvedAnswer,
  });

  factory AnswerFeedback.fromJson(Map<String, Object?> json) {
    List<String> strings(Object? value) => [
      for (final item in value is List ? value : const []) '$item',
    ];
    final rating = json['rating'];
    return AnswerFeedback(
      rating: (rating is num ? rating.round() : 1).clamp(1, 5),
      summary: '${json['summary'] ?? ''}',
      strengths: strings(json['strengths']),
      improvements: strings(json['improvements']),
      improvedAnswer: '${json['improved_answer'] ?? ''}',
    );
  }

  /// 1 (weak) to 5 (ready for the interview).
  final int rating;
  final String summary;
  final List<String> strengths;
  final List<String> improvements;

  /// The user's answer reworked, keeping to what they and the CV said.
  final String improvedAnswer;
}

/// What a review or draft cost, for showing the user.
class AiUsage {
  const AiUsage({required this.model, required this.costUsd});

  final String model;
  final double costUsd;
}

/// The AI features: reviewing a CV against a job, drafting a cover letter,
/// and drafting answers to application questions, on whichever provider's
/// model the user picked.
class CvReviewer {
  CvReviewer(this._client);

  final AiClient _client;

  AiProvider get provider => _client.provider;

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
        const AiText('Review my CV against this job posting.'),
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
        const AiText('Write my cover letter for this job.'),
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
        AiText('Question:\n$question'),
      ],
      schema: _answerSchema,
      effort: 'medium',
    );
    return ('${result.json['answer'] ?? ''}', _usage(result));
  }

  /// Likely interview questions for [job], with answers drawn from [cv].
  Future<(InterviewPrep, AiUsage)> interviewPrep({
    required Cv cv,
    required Job job,
    required String jobDescription,
  }) async {
    final result = await _client.createJson(
      system: _interviewSystem,
      content: [
        _cvBlock(cv),
        _jobBlock(job, jobDescription),
        const AiText('Prepare me for the interviews for this job.'),
      ],
      schema: _interviewSchema,
    );
    return (InterviewPrep.fromJson(result.json), _usage(result));
  }

  /// Rates a practice [answer] to [question] and shows how to improve it.
  Future<(AnswerFeedback, AiUsage)> answerFeedback({
    required Cv cv,
    required Job job,
    required String jobDescription,
    required String question,
    required String answer,
  }) async {
    final result = await _client.createJson(
      system: _feedbackSystem,
      content: [
        _cvBlock(cv),
        _jobBlock(job, jobDescription),
        AiText('Interview question:\n$question\n\nMy answer:\n$answer'),
      ],
      schema: _feedbackSchema,
      effort: 'medium',
    );
    return (AnswerFeedback.fromJson(result.json), _usage(result));
  }

  AiUsage _usage(AiResult result) =>
      AiUsage(model: result.model, costUsd: result.costUsd);
}

/// The CV as a document: a PDF is passed as is for the model to read, other
/// formats as their extracted text.
AiDocument _cvBlock(Cv cv) => cv.format == CvFormat.pdf
    ? AiDocument.pdf(
        title: 'My CV (${cv.fileName})',
        pdf: cv.bytes,
        fileName: cv.fileName,
      )
    : AiDocument.text(title: 'My CV (${cv.fileName})', text: cv.text);

AiDocument _jobBlock(Job job, String description) => AiDocument.text(
  title: 'Job posting: ${job.title}',
  text: [
    'Title: ${job.title}',
    if (job.company.isNotEmpty) 'Company: ${job.company}',
    if (job.location.isNotEmpty) 'Location: ${job.location}',
    if (job.jobType.isNotEmpty) 'Job type: ${job.jobType}',
    if (job.salary.isNotEmpty) 'Salary: ${job.salary}',
    '',
    description.isEmpty ? '(No description provided.)' : description,
  ].join('\n'),
);

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

const _interviewSystem =
    'You coach a job seeker based in Indonesia for interviews for a remote '
    'job at a company abroad. You receive their CV and the job posting.\n\n'
    'List the 10 to 12 questions they are most likely to be asked for this '
    'role, specific to this posting rather than generic: experience and '
    'behaviour, technical skills the posting names, the role and company, '
    'working remotely across time zones from Indonesia, and the hard ones '
    '(gaps the CV shows against the posting, salary expectations, why leave '
    'the current job). For each, say why interviewers ask it and how to '
    'answer well, and write a sample answer in the first person, about 120 '
    'to 200 words, using the STAR shape for behavioural questions. '
    '$_honesty Where the CV has nothing to draw on, write the answer around '
    'a placeholder in square brackets for the candidate to fill in, rather '
    'than inventing a story.\n\n'
    'Write questions, sample answers, and questions to ask in the language '
    'of the job posting, since the interview will be in it. Write the '
    'overview, the reasons, the tips, and what to prepare in Indonesian.';

const _feedbackSystem =
    'You coach a job seeker based in Indonesia for an interview for a '
    'remote job abroad. You receive their CV, the job posting, one likely '
    'interview question, and their practice answer.\n\n'
    'Judge the answer as the interviewer would: does it answer the '
    'question, is it specific, does it show impact, is it the right length '
    'for a spoken answer, and does it connect to what this posting needs. '
    'Be encouraging but honest. Write the summary, strengths, and '
    'improvements in Indonesian. Then rewrite the answer in the language of '
    'the question, keeping to what the answer and the CV say. $_honesty '
    'Mark anything the candidate should add from their own experience with '
    'a short placeholder in square brackets.';

const _interviewSchema = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': ['overview', 'questions', 'questions_to_ask', 'to_prepare'],
  'properties': {
    'overview': {
      'type': 'string',
      'description':
          'Two or three sentences in Indonesian on what these interviews '
          'will likely focus on.',
    },
    'questions': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['kind', 'question', 'why', 'tips', 'sample_answer'],
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['behavioral', 'technical', 'role', 'remote', 'tricky'],
          },
          'question': {'type': 'string'},
          'why': {'type': 'string'},
          'tips': {'type': 'string'},
          'sample_answer': {'type': 'string'},
        },
      },
    },
    'questions_to_ask': {
      'type': 'array',
      'items': {'type': 'string'},
      'description': 'Three to five good questions to ask the interviewer.',
    },
    'to_prepare': {
      'type': 'array',
      'items': {'type': 'string'},
      'description':
          'In Indonesian: what to research or get ready, such as the '
          'company product, time-zone overlap, or a salary range in USD.',
    },
  },
};

const _feedbackSchema = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': [
    'rating',
    'summary',
    'strengths',
    'improvements',
    'improved_answer',
  ],
  'properties': {
    'rating': {
      'type': 'integer',
      'description':
          '1 to 5: 1 misses the question, 3 acceptable, 5 ready for the '
          'interview.',
    },
    'summary': {'type': 'string'},
    'strengths': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'improvements': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'improved_answer': {'type': 'string'},
  },
};

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
