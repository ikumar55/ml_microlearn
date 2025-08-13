import '../models/index.dart';
import 'database_helper.dart';

/// StudyRepository - Repository pattern for managing study data
/// Provides high-level operations and business logic for study functionality
class StudyRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // ========================================
  // StudyClass Operations
  // ========================================
  
  /// Create a new study class with validation
  Future<StudyClass> createStudyClass({
    required String name,
    String? description,
    required String color,
  }) async {
    // Validate inputs
    if (name.trim().isEmpty) {
      throw ArgumentError('Class name cannot be empty');
    }
    
    if (!_isValidHexColor(color)) {
      throw ArgumentError('Invalid color format. Use hex format like #FF5722');
    }
    
    final studyClass = StudyClass(
      name: name.trim(),
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      color: color,
      createdAt: DateTime.now(),
      totalFlashcards: 0,
      activeFlashcards: 0,
    );
    
    final id = await _dbHelper.insertStudyClass(studyClass);
    return studyClass.copyWith(id: id);
  }
  
  /// Get all study classes with updated counts
  Future<List<StudyClass>> getAllStudyClasses() async {
    await _dbHelper.updateComputedFields();
    return await _dbHelper.getAllStudyClasses();
  }
  
  /// Get study class by ID
  Future<StudyClass?> getStudyClass(int id) async {
    return await _dbHelper.getStudyClass(id);
  }
  
  /// Update study class
  Future<StudyClass> updateStudyClass(StudyClass studyClass) async {
    if (studyClass.id == null) {
      throw ArgumentError('Cannot update study class without ID');
    }
    
    await _dbHelper.updateStudyClass(studyClass);
    await _dbHelper.updateComputedFields();
    return studyClass;
  }
  
  /// Delete study class and all related data
  Future<void> deleteStudyClass(int id) async {
    await _dbHelper.deleteStudyClass(id);
  }
  
  // ========================================
  // Lecture Operations
  // ========================================
  
  /// Create a new lecture
  Future<Lecture> createLecture({
    required int classId,
    required String title,
    String? notes,
  }) async {
    if (title.trim().isEmpty) {
      throw ArgumentError('Lecture title cannot be empty');
    }
    
    final lecture = Lecture(
      classId: classId,
      title: title.trim(),
      notes: notes?.trim(),
      createdAt: DateTime.now(),
      flashcardCount: 0,
    );
    
    final id = await _dbHelper.insertLecture(lecture);
    return lecture.copyWith(id: id);
  }
  
  /// Get all lectures for a class
  Future<List<Lecture>> getLecturesForClass(int classId) async {
    await _dbHelper.updateComputedFields();
    return await _dbHelper.getLecturesForClass(classId);
  }
  
  /// Get lecture by ID
  Future<Lecture?> getLecture(int id) async {
    return await _dbHelper.getLecture(id);
  }
  
  /// Update lecture
  Future<Lecture> updateLecture(Lecture lecture) async {
    if (lecture.id == null) {
      throw ArgumentError('Cannot update lecture without ID');
    }
    
    await _dbHelper.updateLecture(lecture);
    await _dbHelper.updateComputedFields();
    return lecture;
  }
  
  /// Delete lecture and all related flashcards
  Future<void> deleteLecture(int id) async {
    await _dbHelper.deleteLecture(id);
    await _dbHelper.updateComputedFields();
  }
  
  // ========================================
  // Flashcard Operations
  // ========================================
  
  /// Create a new flashcard
  Future<Flashcard> createFlashcard({
    required int lectureId,
    required String question,
    required String answer,
    bool isActive = true,
    String? difficulty,
  }) async {
    if (question.trim().isEmpty) {
      throw ArgumentError('Question cannot be empty');
    }
    
    if (answer.trim().isEmpty) {
      throw ArgumentError('Answer cannot be empty');
    }
    
    final now = DateTime.now();
    final flashcard = Flashcard(
      lectureId: lectureId,
      question: question.trim(),
      answer: answer.trim(),
      isActive: isActive,
      difficulty: difficulty,
      correctCount: 0,
      incorrectCount: 0,
      lastReviewed: null, // Not reviewed yet
      nextReview: now, // Due immediately for first review
      consecutiveCorrect: 0,
      createdAt: now,
    );
    
    final id = await _dbHelper.insertFlashcard(flashcard);
    await _dbHelper.updateComputedFields();
    return flashcard.copyWith(id: id);
  }
  
  /// Get all flashcards for a lecture
  Future<List<Flashcard>> getFlashcardsForLecture(int lectureId) async {
    return await _dbHelper.getFlashcardsForLecture(lectureId);
  }
  
  /// Get flashcards due for review (spaced repetition)
  Future<List<Flashcard>> getFlashcardsDueForReview({int limit = 10}) async {
    return await _dbHelper.getFlashcardsDueForReview(limit: limit);
  }
  
  /// Get active flashcards for notifications
  Future<List<Flashcard>> getActiveFlashcards() async {
    return await _dbHelper.getActiveFlashcards();
  }
  
  /// Update flashcard (general purpose)
  Future<Flashcard> updateFlashcard(Flashcard flashcard) async {
    if (flashcard.id == null) {
      throw ArgumentError('Cannot update flashcard without ID');
    }
    
    await _dbHelper.updateFlashcard(flashcard);
    await _dbHelper.updateComputedFields();
    
    return flashcard;
  }
  
  /// Update flashcard after study session
  Future<Flashcard> updateFlashcardAfterStudy({
    required Flashcard flashcard,
    required bool wasCorrect,
    Duration? responseTime,
  }) async {
    if (flashcard.id == null) {
      throw ArgumentError('Cannot update flashcard without ID');
    }
    
    // Record the study session
    final session = StudySession(
      flashcardId: flashcard.id!,
      wasCorrect: wasCorrect,
      sessionDate: DateTime.now(),
      responseTimeMs: responseTime?.inMilliseconds,
    );
    await _dbHelper.insertStudySession(session);
    
    // Calculate next review date using spaced repetition (SM-2 algorithm)
    final updatedFlashcard = _calculateNextReview(flashcard, wasCorrect);
    
    await _dbHelper.updateFlashcard(updatedFlashcard);
    await _dbHelper.updateComputedFields();
    
    return updatedFlashcard;
  }
  
  /// Calculate next review date using simplified SM-2 algorithm
  Flashcard _calculateNextReview(Flashcard flashcard, bool wasCorrect) {
    final now = DateTime.now();
    int newCorrectCount = flashcard.correctCount;
    int newIncorrectCount = flashcard.incorrectCount;
    int newConsecutiveCorrect = flashcard.consecutiveCorrect;
    
    if (wasCorrect) {
      newCorrectCount++;
      newConsecutiveCorrect++;
    } else {
      newIncorrectCount++;
      newConsecutiveCorrect = 0;
    }
    
    // Calculate interval based on performance (simplified SM-2)
    Duration interval;
    if (!wasCorrect) {
      // Reset to 1 day if incorrect
      interval = const Duration(days: 1);
    } else {
      // Progressive intervals: 1, 3, 7, 14, 30, 60 days
      switch (newConsecutiveCorrect) {
        case 1:
          interval = const Duration(days: 1);
          break;
        case 2:
          interval = const Duration(days: 3);
          break;
        case 3:
          interval = const Duration(days: 7);
          break;
        case 4:
          interval = const Duration(days: 14);
          break;
        case 5:
          interval = const Duration(days: 30);
          break;
        default:
          interval = const Duration(days: 60);
      }
    }
    
    return flashcard.copyWith(
      correctCount: newCorrectCount,
      incorrectCount: newIncorrectCount,
      consecutiveCorrect: newConsecutiveCorrect,
      lastReviewed: now,
      nextReview: now.add(interval),
    );
  }
  
  /// Toggle flashcard active status
  Future<Flashcard> toggleFlashcardActive(Flashcard flashcard) async {
    if (flashcard.id == null) {
      throw ArgumentError('Cannot update flashcard without ID');
    }
    
    final updated = flashcard.copyWith(isActive: !flashcard.isActive);
    await _dbHelper.updateFlashcard(updated);
    await _dbHelper.updateComputedFields();
    return updated;
  }
  
  /// Delete flashcard
  Future<void> deleteFlashcard(int id) async {
    await _dbHelper.deleteFlashcard(id);
    await _dbHelper.updateComputedFields();
  }
  
  // ========================================
  // Study Session Operations
  // ========================================
  
  /// Get study sessions for a flashcard
  Future<List<StudySession>> getSessionsForFlashcard(int flashcardId) async {
    return await _dbHelper.getSessionsForFlashcard(flashcardId);
  }
  
  /// Get recent study sessions for analytics
  Future<List<StudySession>> getRecentSessions({int limit = 50}) async {
    return await _dbHelper.getRecentSessions(limit: limit);
  }
  
  // ========================================
  // Analytics & Statistics
  // ========================================
  
  /// Get comprehensive study statistics
  Future<StudyStatistics> getStudyStatistics() async {
    final stats = await _dbHelper.getStudyStatistics();
    
    // Calculate accuracy percentage
    final totalSessions = stats['totalSessions'] ?? 0;
    final correctSessions = stats['correctSessions'] ?? 0;
    final accuracyPercentage = totalSessions > 0 
        ? (correctSessions / totalSessions * 100).round()
        : 0;
    
    return StudyStatistics(
      totalClasses: stats['classes'] ?? 0,
      totalLectures: stats['lectures'] ?? 0,
      totalFlashcards: stats['flashcards'] ?? 0,
      activeFlashcards: stats['activeFlashcards'] ?? 0,
      totalSessions: totalSessions,
      correctSessions: correctSessions,
      accuracyPercentage: accuracyPercentage,
    );
  }
  
  /// Initialize database with sample data for testing
  Future<void> initializeSampleData() async {
    // Check if data already exists
    final existingClasses = await getAllStudyClasses();
    if (existingClasses.isNotEmpty) {
      return; // Data already exists
    }
    
    // Create sample class
    final sampleClass = await createStudyClass(
      name: 'Machine Learning Fundamentals',
      color: '#2196F3',
    );
    
    // Create sample lecture
    final sampleLecture = await createLecture(
      classId: sampleClass.id!,
      title: 'Introduction to Neural Networks',
      notes: 'Basic concepts of artificial neural networks and their applications.',
    );
    
    // Create sample flashcards
    await createFlashcard(
      lectureId: sampleLecture.id!,
      question: 'What does ReLU stand for?',
      answer: 'Rectified Linear Unit - an activation function that outputs the input if positive, zero otherwise.',
      difficulty: 'easy',
    );
    
    await createFlashcard(
      lectureId: sampleLecture.id!,
      question: 'What is backpropagation?',
      answer: 'An algorithm for training neural networks that calculates gradients by propagating errors backward through the network.',
      difficulty: 'medium',
    );
    
    await createFlashcard(
      lectureId: sampleLecture.id!,
      question: 'Explain the vanishing gradient problem.',
      answer: 'A problem in deep networks where gradients become exponentially small, making it difficult to train early layers effectively.',
      difficulty: 'hard',
    );
  }
  
  /// Validate hex color format
  bool _isValidHexColor(String color) {
    final hexColorRegex = RegExp(r'^#[0-9A-Fa-f]{6}$');
    return hexColorRegex.hasMatch(color);
  }
}

/// Data class for study statistics
class StudyStatistics {
  final int totalClasses;
  final int totalLectures;
  final int totalFlashcards;
  final int activeFlashcards;
  final int totalSessions;
  final int correctSessions;
  final int accuracyPercentage;
  
  const StudyStatistics({
    required this.totalClasses,
    required this.totalLectures,
    required this.totalFlashcards,
    required this.activeFlashcards,
    required this.totalSessions,
    required this.correctSessions,
    required this.accuracyPercentage,
  });
  
  @override
  String toString() {
    return 'StudyStatistics(classes: $totalClasses, lectures: $totalLectures, '
           'flashcards: $totalFlashcards, active: $activeFlashcards, '
           'sessions: $totalSessions, accuracy: $accuracyPercentage%)';
  }
}