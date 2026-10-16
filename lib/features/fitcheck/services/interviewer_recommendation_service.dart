import '../fitcheck_api_service.dart';

class InterviewerRecommendation {
  final FitCheckInterviewer interviewer;
  final int matchScore; // 0 to 100
  final bool isTopMatch;
  final String badgeText;
  final String headline;
  final List<String> rationalePoints;

  const InterviewerRecommendation({
    required this.interviewer,
    required this.matchScore,
    required this.isTopMatch,
    required this.badgeText,
    required this.headline,
    required this.rationalePoints,
  });
}

class InterviewerRecommendationService {
  /// Computes transparent, deterministic recommendation metrics for interviewers based on job context.
  static List<InterviewerRecommendation> rankInterviewers({
    required List<FitCheckInterviewer> interviewers,
    FitCheckJob? job,
    String? customJobTitle,
    String? customJobDescription,
    FitCheckCandidate? candidate,
  }) {
    final effectiveTitle = (job?.title ?? customJobTitle ?? '').trim();
    final effectiveDesc = (job?.description ?? customJobDescription ?? '').trim();
    final effectiveSeniority = (job?.seniority ?? '').trim();
    final effectiveSkills = job?.requiredSkills ?? [];

    final hasJobContext = effectiveTitle.isNotEmpty ||
        effectiveDesc.isNotEmpty ||
        effectiveSkills.isNotEmpty;

    if (!hasJobContext) {
      // General Practice Mode: All personas are presented equally without artificial bias
      return interviewers.map((i) {
        return InterviewerRecommendation(
          interviewer: i,
          matchScore: 80,
          isTopMatch: false,
          badgeText: 'GENERAL PRACTICE READY',
          headline: '${i.title} • Calibrated for Practice',
          rationalePoints: [
            'Questioning Style: ${i.questioningStyle.toUpperCase()}',
            'Primary Focus: ${i.specialty}',
            'Voice: ${i.voiceDisplayName}',
          ],
        );
      }).toList();
    }

    // Build lowercased token set from job context
    final queryText = '$effectiveTitle $effectiveDesc $effectiveSeniority ${effectiveSkills.join(' ')}'.toLowerCase();

    final results = <InterviewerRecommendation>[];

    for (final interviewer in interviewers) {
      int score = 50; // base score
      final rationale = <String>[];
      final nameLower = interviewer.name.toLowerCase();
      final titleLower = interviewer.title.toLowerCase();

      // Marcus Vance: Systems, Concurrency, Storage, Databases, Raft, Distributed
      if (nameLower.contains('marcus') || titleLower.contains('architect') || titleLower.contains('systems')) {
        int marcusHits = 0;
        final marcusKeywords = [
          'distributed', 'concurrency', 'systems', 'raft', 'database', 'storage',
          'sharding', 'architect', 'infrastructure', 'backend', 'high-throughput',
          'transactions', 'streaming', 'fault', 'consensus', 'l6', 'staff', 'principal',
          'partition', 'kafka', 'latency', 'scale'
        ];
        for (final kw in marcusKeywords) {
          if (queryText.contains(kw)) marcusHits++;
        }
        score += (marcusHits * 8).clamp(0, 42);
        if (marcusHits > 0) {
          rationale.add('High affinity for distributed systems, concurrency, and architecture rigor ($marcusHits keyword matches)');
        }
        if (effectiveSeniority.toLowerCase().contains('staff') ||
            effectiveSeniority.toLowerCase().contains('principal') ||
            effectiveSeniority.toLowerCase().contains('l6') ||
            effectiveSeniority.toLowerCase().contains('l7')) {
          score += 10;
          rationale.add('Seniority match: Calibrated for Staff & Principal committee evaluations');
        }
        if (rationale.isEmpty) {
          rationale.add('Specialized in systems depth, race conditions, and trade-off defense');
        }
      }
      // Sarah Chen: Engineering Manager, Leadership, SRE, Cloud Platform, Reliability, Incident Postmortems
      else if (nameLower.contains('sarah') || titleLower.contains('manager') || titleLower.contains('director') || titleLower.contains('lead')) {
        int sarahHits = 0;
        final sarahKeywords = [
          'manager', 'management', 'leadership', 'incident', 'velocity', 'resilient',
          'cloud', 'platform', 'cross-functional', 'em', 'director', 'team',
          'post-incident', 'postmortem', 'culture', 'organizational', 'sre', 'reliability',
          'devops', 'ownership'
        ];
        for (final kw in sarahKeywords) {
          if (queryText.contains(kw)) sarahHits++;
        }
        score += (sarahHits * 8).clamp(0, 42);
        if (sarahHits > 0) {
          rationale.add('High affinity for engineering leadership, platform reliability, and team velocity ($sarahHits keyword matches)');
        }
        if (effectiveTitle.toLowerCase().contains('manager') ||
            effectiveTitle.toLowerCase().contains('lead') ||
            effectiveTitle.toLowerCase().contains('director')) {
          score += 15;
          rationale.add('Role match: Direct alignment for Engineering Leadership & Management loops');
        }
        if (rationale.isEmpty) {
          rationale.add('Specialized in operational resilience, cross-functional collaboration, and ownership');
        }
      }
      // Alex Rivera: Full-Stack, Product Engineer, APIs, UI/UX, SaaS, Frameworks
      else if (nameLower.contains('alex') || titleLower.contains('full-stack') || titleLower.contains('product')) {
        int alexHits = 0;
        final alexKeywords = [
          'full-stack', 'fullstack', 'frontend', 'product', 'api', 'web', 'ui',
          'mobile', 'flutter', 'react', 'saas', 'consumer', 'client', 'developer-experience',
          'framework', 'javascript', 'typescript', 'mobile', 'clean code', 'user'
        ];
        for (final kw in alexKeywords) {
          if (queryText.contains(kw)) alexHits++;
        }
        score += (alexHits * 8).clamp(0, 42);
        if (alexHits > 0) {
          rationale.add('High affinity for full-stack product engineering, modern APIs, and UX execution ($alexHits keyword matches)');
        }
        if (effectiveTitle.toLowerCase().contains('full-stack') ||
            effectiveTitle.toLowerCase().contains('frontend') ||
            effectiveTitle.toLowerCase().contains('product')) {
          score += 15;
          rationale.add('Role match: Tailored for Product Engineering and API Architecture loops');
        }
        if (rationale.isEmpty) {
          rationale.add('Specialized in pragmatic architecture, clean API contracts, and user impact');
        }
      } else {
        // Generic or custom interviewer match
        int genericHits = 0;
        for (final skill in interviewer.focusAreas) {
          if (queryText.contains(skill.toLowerCase())) genericHits++;
        }
        score += (genericHits * 10).clamp(0, 40);
        rationale.add('Calibrated on focus areas: ${interviewer.focusAreas.take(2).join(', ')}');
      }

      score = score.clamp(35, 98);

      results.add(InterviewerRecommendation(
        interviewer: interviewer,
        matchScore: score,
        isTopMatch: false, // set below
        badgeText: score >= 80 ? 'HIGH AFFINITY MATCH ($score%)' : 'RELEVANT PERSONA ($score%)',
        headline: score >= 80 ? '★ Recommended for $effectiveTitle' : 'Available for $effectiveTitle',
        rationalePoints: rationale,
      ));
    }

    // Sort descending by score
    results.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    // Mark top match
    if (results.isNotEmpty && results.first.matchScore >= 68) {
      final top = results.first;
      results[0] = InterviewerRecommendation(
        interviewer: top.interviewer,
        matchScore: top.matchScore,
        isTopMatch: true,
        badgeText: '★ TOP RECOMMENDED MATCH (${top.matchScore}%)',
        headline: '★ Best Calibration for $effectiveTitle',
        rationalePoints: top.rationalePoints,
      );
    }

    return results;
  }
}
