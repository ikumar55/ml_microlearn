/// Represents a lecture/topic within a study class
class Lecture {
  final int? id;
  final int classId;            // Foreign key to StudyClass
  final String title;
  final String? notes;          // Optional lecture notes/description
  final DateTime createdAt;
  final int flashcardCount;     // Computed from related flashcards

  const Lecture({
    this.id,
    required this.classId,
    required this.title,
    this.notes,
    required this.createdAt,
    this.flashcardCount = 0,
  });

  /// Create Lecture from database map
  factory Lecture.fromMap(Map<String, dynamic> map) {
    return Lecture(
      id: map['id'] as int?,
      classId: map['class_id'] as int,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      flashcardCount: map['flashcard_count'] as int? ?? 0,
    );
  }

  /// Convert Lecture to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_id': classId,
      'title': title,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      // Note: flashcard_count is computed, not stored
    };
  }

  /// Create a copy with updated fields
  Lecture copyWith({
    int? id,
    int? classId,
    String? title,
    String? notes,
    DateTime? createdAt,
    int? flashcardCount,
  }) {
    return Lecture(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      flashcardCount: flashcardCount ?? this.flashcardCount,
    );
  }

  /// Validate lecture data
  String? validate() {
    if (title.trim().isEmpty) {
      return 'Lecture title cannot be empty';
    }
    if (title.length > 200) {
      return 'Lecture title must be less than 200 characters';
    }
    if (notes != null && notes!.length > 1000) {
      return 'Lecture notes must be less than 1000 characters';
    }
    if (classId <= 0) {
      return 'Invalid class ID';
    }
    return null; // Valid
  }

  /// Get display title (truncated if needed)
  String get displayTitle {
    if (title.length <= 50) return title;
    return '${title.substring(0, 47)}...';
  }

  /// Get display notes (truncated if needed)
  String? get displayNotes {
    if (notes == null || notes!.isEmpty) return null;
    if (notes!.length <= 100) return notes;
    return '${notes!.substring(0, 97)}...';
  }

  /// Check if lecture has content
  bool get hasFlashcards => flashcardCount > 0;

  /// Check if lecture has notes
  bool get hasNotes => notes != null && notes!.trim().isNotEmpty;

  /// Get lecture status for UI
  LectureStatus get status {
    if (flashcardCount == 0) return LectureStatus.empty;
    if (flashcardCount < 5) return LectureStatus.light;
    if (flashcardCount < 20) return LectureStatus.moderate;
    return LectureStatus.comprehensive;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Lecture &&
        other.id == id &&
        other.classId == classId &&
        other.title == title &&
        other.notes == notes &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        classId.hashCode ^
        title.hashCode ^
        notes.hashCode ^
        createdAt.hashCode;
  }

  @override
  String toString() {
    return 'Lecture{id: $id, classId: $classId, title: $title, '
        'flashcards: $flashcardCount}';
  }
}

/// Lecture content status based on flashcard count
enum LectureStatus {
  empty,          // 0 flashcards
  light,          // 1-4 flashcards
  moderate,       // 5-19 flashcards
  comprehensive,  // 20+ flashcards
}

extension LectureStatusExtension on LectureStatus {
  String get displayName {
    switch (this) {
      case LectureStatus.empty:
        return 'No Content';
      case LectureStatus.light:
        return 'Light Content';
      case LectureStatus.moderate:
        return 'Good Content';
      case LectureStatus.comprehensive:
        return 'Rich Content';
    }
  }

  String get description {
    switch (this) {
      case LectureStatus.empty:
        return 'Add flashcards to get started';
      case LectureStatus.light:
        return 'Quick review material';
      case LectureStatus.moderate:
        return 'Solid study material';
      case LectureStatus.comprehensive:
        return 'Comprehensive study material';
    }
  }
}