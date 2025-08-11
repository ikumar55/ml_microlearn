/// Represents an individual study session attempt on a flashcard
class StudySession {
  final int? id;
  final int flashcardId;        // Foreign key to Flashcard
  final bool wasCorrect;        // Whether the answer was correct
  final int? responseTimeMs;    // Time taken to answer (milliseconds)
  final DateTime sessionDate;  // When this session occurred
  final String? source;         // How session was initiated (notification, manual, etc.)

  const StudySession({
    this.id,
    required this.flashcardId,
    required this.wasCorrect,
    this.responseTimeMs,
    required this.sessionDate,
    this.source,
  });

  /// Create StudySession from database map
  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'] as int?,
      flashcardId: map['flashcard_id'] as int,
      wasCorrect: (map['was_correct'] as int) == 1,
      responseTimeMs: map['response_time_ms'] as int?,
      sessionDate: DateTime.parse(map['session_date'] as String),
      source: map['source'] as String?,
    );
  }

  /// Convert StudySession to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'flashcard_id': flashcardId,
      'was_correct': wasCorrect ? 1 : 0,
      'response_time_ms': responseTimeMs,
      'session_date': sessionDate.toIso8601String(),
      'source': source,
    };
  }

  /// Create a copy with updated fields
  StudySession copyWith({
    int? id,
    int? flashcardId,
    bool? wasCorrect,
    int? responseTimeMs,
    DateTime? sessionDate,
    String? source,
  }) {
    return StudySession(
      id: id ?? this.id,
      flashcardId: flashcardId ?? this.flashcardId,
      wasCorrect: wasCorrect ?? this.wasCorrect,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      sessionDate: sessionDate ?? this.sessionDate,
      source: source ?? this.source,
    );
  }

  /// Validate study session data
  String? validate() {
    if (flashcardId <= 0) {
      return 'Invalid flashcard ID';
    }
    if (responseTimeMs != null && responseTimeMs! < 0) {
      return 'Response time cannot be negative';
    }
    if (responseTimeMs != null && responseTimeMs! > 300000) { // 5 minutes
      return 'Response time seems unrealistic (over 5 minutes)';
    }
    if (sessionDate.isAfter(DateTime.now().add(const Duration(hours: 1)))) {
      return 'Session date cannot be in the future';
    }
    return null; // Valid
  }

  /// Get response time in seconds
  double? get responseTimeSeconds {
    if (responseTimeMs == null) return null;
    return responseTimeMs! / 1000.0;
  }

  /// Get formatted response time for display
  String get displayResponseTime {
    if (responseTimeMs == null) return 'Unknown';
    
    final seconds = responseTimeSeconds!;
    if (seconds < 1) {
      return '${responseTimeMs}ms';
    } else if (seconds < 60) {
      return '${seconds.toStringAsFixed(1)}s';
    } else {
      final minutes = (seconds / 60).floor();
      final remainingSeconds = (seconds % 60).round();
      return '${minutes}m ${remainingSeconds}s';
    }
  }

  /// Get session performance level
  SessionPerformance get performance {
    if (!wasCorrect) return SessionPerformance.incorrect;
    
    if (responseTimeMs == null) return SessionPerformance.correct;
    
    final seconds = responseTimeSeconds!;
    if (seconds <= 3) return SessionPerformance.excellent;
    if (seconds <= 10) return SessionPerformance.good;
    return SessionPerformance.correct;
  }

  /// Get session source with fallback
  SessionSource get sessionSource {
    switch (source?.toLowerCase()) {
      case 'notification':
        return SessionSource.notification;
      case 'manual':
        return SessionSource.manual;
      case 'review':
        return SessionSource.review;
      case 'study_session':
        return SessionSource.studySession;
      default:
        return SessionSource.unknown;
    }
  }

  /// Check if session was recent (within last hour)
  bool get isRecent {
    final hourAgo = DateTime.now().subtract(const Duration(hours: 1));
    return sessionDate.isAfter(hourAgo);
  }

  /// Get time since session
  Duration get timeSinceSession => DateTime.now().difference(sessionDate);

  /// Get formatted time since session
  String get displayTimeSince {
    final duration = timeSinceSession;
    
    if (duration.inDays > 0) {
      return '${duration.inDays}d ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudySession &&
        other.id == id &&
        other.flashcardId == flashcardId &&
        other.wasCorrect == wasCorrect &&
        other.sessionDate == sessionDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        flashcardId.hashCode ^
        wasCorrect.hashCode ^
        sessionDate.hashCode;
  }

  @override
  String toString() {
    return 'StudySession{id: $id, flashcardId: $flashcardId, '
        'correct: $wasCorrect, time: ${displayResponseTime}, '
        'source: $source}';
  }
}

/// Session performance levels
enum SessionPerformance {
  excellent,   // Correct + fast (≤3s)
  good,        // Correct + moderate (≤10s)
  correct,     // Correct + slow (>10s) or unknown time
  incorrect,   // Wrong answer
}

/// Sources that can trigger study sessions
enum SessionSource {
  notification,  // From push notification
  manual,        // User manually started
  review,        // From review/practice mode
  studySession,  // From formal study session
  unknown,       // Source not specified
}

extension SessionPerformanceExtension on SessionPerformance {
  String get displayName {
    switch (this) {
      case SessionPerformance.excellent:
        return 'Excellent';
      case SessionPerformance.good:
        return 'Good';
      case SessionPerformance.correct:
        return 'Correct';
      case SessionPerformance.incorrect:
        return 'Incorrect';
    }
  }

  String get description {
    switch (this) {
      case SessionPerformance.excellent:
        return 'Quick and correct!';
      case SessionPerformance.good:
        return 'Correct with good timing';
      case SessionPerformance.correct:
        return 'Correct answer';
      case SessionPerformance.incorrect:
        return 'Needs more practice';
    }
  }
}

extension SessionSourceExtension on SessionSource {
  String get displayName {
    switch (this) {
      case SessionSource.notification:
        return 'Notification';
      case SessionSource.manual:
        return 'Manual Study';
      case SessionSource.review:
        return 'Review Session';
      case SessionSource.studySession:
        return 'Study Session';
      case SessionSource.unknown:
        return 'Unknown';
    }
  }
}