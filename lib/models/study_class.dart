/// Represents a study class/course with metadata and computed statistics
class StudyClass {
  final int? id;
  final String name;
  final String color;           // Hex color code for visual organization
  final DateTime createdAt;
  final int totalFlashcards;    // Computed from related flashcards
  final int activeFlashcards;   // Currently in notification rotation

  const StudyClass({
    this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    this.totalFlashcards = 0,
    this.activeFlashcards = 0,
  });

  /// Create StudyClass from database map
  factory StudyClass.fromMap(Map<String, dynamic> map) {
    return StudyClass(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      totalFlashcards: map['total_flashcards'] as int? ?? 0,
      activeFlashcards: map['active_flashcards'] as int? ?? 0,
    );
  }

  /// Convert StudyClass to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      // Note: computed fields are not stored directly
    };
  }

  /// Create a copy with updated fields
  StudyClass copyWith({
    int? id,
    String? name,
    String? color,
    DateTime? createdAt,
    int? totalFlashcards,
    int? activeFlashcards,
  }) {
    return StudyClass(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      totalFlashcards: totalFlashcards ?? this.totalFlashcards,
      activeFlashcards: activeFlashcards ?? this.activeFlashcards,
    );
  }

  /// Validate class data
  String? validate() {
    if (name.trim().isEmpty) {
      return 'Class name cannot be empty';
    }
    if (name.length > 100) {
      return 'Class name must be less than 100 characters';
    }
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
      return 'Color must be a valid hex code (e.g., #FF5722)';
    }
    return null; // Valid
  }

  /// Get a display-friendly color
  String get displayColor => color.toUpperCase();

  /// Check if class has any content
  bool get hasContent => totalFlashcards > 0;

  /// Get study readiness status
  StudyReadiness get studyReadiness {
    if (activeFlashcards == 0) return StudyReadiness.noActiveCards;
    if (activeFlashcards < 5) return StudyReadiness.low;
    if (activeFlashcards < 15) return StudyReadiness.medium;
    return StudyReadiness.high;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudyClass &&
        other.id == id &&
        other.name == name &&
        other.color == color &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        color.hashCode ^
        createdAt.hashCode;
  }

  @override
  String toString() {
    return 'StudyClass{id: $id, name: $name, color: $color, '
        'total: $totalFlashcards, active: $activeFlashcards}';
  }
}

/// Study readiness levels based on active flashcard count
enum StudyReadiness {
  noActiveCards,
  low,      // 1-4 cards
  medium,   // 5-14 cards  
  high,     // 15+ cards
}

extension StudyReadinessExtension on StudyReadiness {
  String get displayName {
    switch (this) {
      case StudyReadiness.noActiveCards:
        return 'No Active Cards';
      case StudyReadiness.low:
        return 'Light Study';
      case StudyReadiness.medium:
        return 'Regular Study';
      case StudyReadiness.high:
        return 'Intensive Study';
    }
  }

  String get description {
    switch (this) {
      case StudyReadiness.noActiveCards:
        return 'Add some flashcards to start studying';
      case StudyReadiness.low:
        return 'Perfect for casual review';
      case StudyReadiness.medium:
        return 'Good amount for regular practice';
      case StudyReadiness.high:
        return 'Great for intensive study sessions';
    }
  }
}