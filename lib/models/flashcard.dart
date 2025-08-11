/// Represents a flashcard with question/answer and spaced repetition data
class Flashcard {
  final int? id;
  final int lectureId;          // Foreign key to Lecture
  final String question;
  final String answer;
  final bool isActive;          // Whether card is in notification rotation
  final String? difficulty;     // 'easy', 'medium', 'hard', or null
  final int correctCount;       // Total correct answers
  final int incorrectCount;     // Total incorrect answers
  final DateTime? lastReviewed; // Last time this card was studied
  final DateTime nextReview;    // When this card should be reviewed next
  final int consecutiveCorrect; // Current streak of correct answers
  final DateTime createdAt;

  const Flashcard({
    this.id,
    required this.lectureId,
    required this.question,
    required this.answer,
    this.isActive = true,
    this.difficulty,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.lastReviewed,
    required this.nextReview,
    this.consecutiveCorrect = 0,
    required this.createdAt,
  });

  /// Create Flashcard from database map
  factory Flashcard.fromMap(Map<String, dynamic> map) {
    return Flashcard(
      id: map['id'] as int?,
      lectureId: map['lecture_id'] as int,
      question: map['question'] as String,
      answer: map['answer'] as String,
      isActive: (map['is_active'] as int) == 1,
      difficulty: map['difficulty'] as String?,
      correctCount: map['correct_count'] as int? ?? 0,
      incorrectCount: map['incorrect_count'] as int? ?? 0,
      lastReviewed: map['last_reviewed'] != null
          ? DateTime.parse(map['last_reviewed'] as String)
          : null,
      nextReview: DateTime.parse(map['next_review'] as String),
      consecutiveCorrect: map['consecutive_correct'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convert Flashcard to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lecture_id': lectureId,
      'question': question,
      'answer': answer,
      'is_active': isActive ? 1 : 0,
      'difficulty': difficulty,
      'correct_count': correctCount,
      'incorrect_count': incorrectCount,
      'last_reviewed': lastReviewed?.toIso8601String(),
      'next_review': nextReview.toIso8601String(),
      'consecutive_correct': consecutiveCorrect,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Flashcard copyWith({
    int? id,
    int? lectureId,
    String? question,
    String? answer,
    bool? isActive,
    String? difficulty,
    int? correctCount,
    int? incorrectCount,
    DateTime? lastReviewed,
    DateTime? nextReview,
    int? consecutiveCorrect,
    DateTime? createdAt,
  }) {
    return Flashcard(
      id: id ?? this.id,
      lectureId: lectureId ?? this.lectureId,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      isActive: isActive ?? this.isActive,
      difficulty: difficulty ?? this.difficulty,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      nextReview: nextReview ?? this.nextReview,
      consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Validate flashcard data
  String? validate() {
    if (question.trim().isEmpty) {
      return 'Question cannot be empty';
    }
    if (answer.trim().isEmpty) {
      return 'Answer cannot be empty';
    }
    if (question.length > 500) {
      return 'Question must be less than 500 characters';
    }
    if (answer.length > 1000) {
      return 'Answer must be less than 1000 characters';
    }
    if (difficulty != null && 
        !['easy', 'medium', 'hard'].contains(difficulty!.toLowerCase())) {
      return 'Difficulty must be easy, medium, or hard';
    }
    if (lectureId <= 0) {
      return 'Invalid lecture ID';
    }
    return null; // Valid
  }

  /// Get display question (truncated if needed)
  String get displayQuestion {
    if (question.length <= 80) return question;
    return '${question.substring(0, 77)}...';
  }

  /// Get display answer (truncated if needed)
  String get displayAnswer {
    if (answer.length <= 100) return answer;
    return '${answer.substring(0, 97)}...';
  }

  /// Calculate accuracy percentage
  double get accuracy {
    final total = correctCount + incorrectCount;
    if (total == 0) return 0.0;
    return (correctCount / total) * 100;
  }

  /// Get total attempts
  int get totalAttempts => correctCount + incorrectCount;

  /// Check if card is due for review
  bool get isDue => DateTime.now().isAfter(nextReview);

  /// Check if card is overdue (more than 1 day past due)
  bool get isOverdue {
    if (!isDue) return false;
    final daysPastDue = DateTime.now().difference(nextReview).inDays;
    return daysPastDue > 1;
  }

  /// Get days until next review (negative if overdue)
  int get daysUntilReview {
    final difference = nextReview.difference(DateTime.now());
    return difference.inDays;
  }

  /// Get flashcard mastery level
  MasteryLevel get masteryLevel {
    if (totalAttempts < 3) return MasteryLevel.new_;
    if (accuracy < 50) return MasteryLevel.struggling;
    if (accuracy < 80) return MasteryLevel.learning;
    if (consecutiveCorrect >= 3) return MasteryLevel.mastered;
    return MasteryLevel.proficient;
  }

  /// Get difficulty level (with fallback)
  DifficultyLevel get difficultyLevel {
    switch (difficulty?.toLowerCase()) {
      case 'easy':
        return DifficultyLevel.easy;
      case 'medium':
        return DifficultyLevel.medium;
      case 'hard':
        return DifficultyLevel.hard;
      default:
        return DifficultyLevel.medium; // Default
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Flashcard &&
        other.id == id &&
        other.lectureId == lectureId &&
        other.question == question &&
        other.answer == answer;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        lectureId.hashCode ^
        question.hashCode ^
        answer.hashCode;
  }

  @override
  String toString() {
    return 'Flashcard{id: $id, lectureId: $lectureId, '
        'question: ${displayQuestion}, active: $isActive, '
        'mastery: $masteryLevel}';
  }
}

/// Flashcard mastery levels based on performance
enum MasteryLevel {
  new_,        // Less than 3 attempts
  struggling,  // < 50% accuracy
  learning,    // 50-79% accuracy
  proficient,  // 80%+ accuracy
  mastered,    // 80%+ accuracy with 3+ consecutive correct
}

/// Difficulty levels for flashcards
enum DifficultyLevel {
  easy,
  medium,
  hard,
}

extension MasteryLevelExtension on MasteryLevel {
  String get displayName {
    switch (this) {
      case MasteryLevel.new_:
        return 'New';
      case MasteryLevel.struggling:
        return 'Struggling';
      case MasteryLevel.learning:
        return 'Learning';
      case MasteryLevel.proficient:
        return 'Proficient';
      case MasteryLevel.mastered:
        return 'Mastered';
    }
  }

  String get description {
    switch (this) {
      case MasteryLevel.new_:
        return 'Just added - needs practice';
      case MasteryLevel.struggling:
        return 'Needs more attention';
      case MasteryLevel.learning:
        return 'Making good progress';
      case MasteryLevel.proficient:
        return 'Well understood';
      case MasteryLevel.mastered:
        return 'Fully mastered';
    }
  }
}

extension DifficultyLevelExtension on DifficultyLevel {
  String get displayName {
    switch (this) {
      case DifficultyLevel.easy:
        return 'Easy';
      case DifficultyLevel.medium:
        return 'Medium';
      case DifficultyLevel.hard:
        return 'Hard';
    }
  }
}