import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/index.dart';

/// DatabaseHelper - Singleton class for managing SQLite database operations
/// Provides CRUD operations for all data models with proper relationships
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
  
  /// Database version for migration management
  static const int _databaseVersion = 1;
  static const String _databaseName = 'ml_microlearn.db';
  
  /// Get database instance (singleton pattern)
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }
  
  /// Initialize database with proper schema
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }
  
  /// Create database tables with proper relationships
  Future<void> _createDatabase(Database db, int version) async {
    // StudyClass table
    await db.execute('''
      CREATE TABLE study_classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT NOT NULL,
        created_at TEXT NOT NULL,
        total_flashcards INTEGER NOT NULL DEFAULT 0,
        active_flashcards INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    // Lecture table with foreign key to StudyClass
    await db.execute('''
      CREATE TABLE lectures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        flashcard_count INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (class_id) REFERENCES study_classes (id) ON DELETE CASCADE
      )
    ''');
    
    // Flashcard table with foreign key to Lecture
    await db.execute('''
      CREATE TABLE flashcards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lecture_id INTEGER NOT NULL,
        question TEXT NOT NULL,
        answer TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        difficulty TEXT,
        correct_count INTEGER NOT NULL DEFAULT 0,
        incorrect_count INTEGER NOT NULL DEFAULT 0,
        last_reviewed TEXT,
        next_review TEXT NOT NULL,
        consecutive_correct INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (lecture_id) REFERENCES lectures (id) ON DELETE CASCADE
      )
    ''');
    
    // StudySession table with foreign key to Flashcard
    await db.execute('''
      CREATE TABLE study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        flashcard_id INTEGER NOT NULL,
        was_correct INTEGER NOT NULL,
        session_date TEXT NOT NULL,
        response_time_ms INTEGER,
        source TEXT,
        FOREIGN KEY (flashcard_id) REFERENCES flashcards (id) ON DELETE CASCADE
      )
    ''');
    
    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_lectures_class_id ON lectures(class_id)');
    await db.execute('CREATE INDEX idx_flashcards_lecture_id ON flashcards(lecture_id)');
    await db.execute('CREATE INDEX idx_flashcards_next_review ON flashcards(next_review)');
    await db.execute('CREATE INDEX idx_flashcards_is_active ON flashcards(is_active)');
    await db.execute('CREATE INDEX idx_study_sessions_flashcard_id ON study_sessions(flashcard_id)');
    await db.execute('CREATE INDEX idx_study_sessions_date ON study_sessions(session_date)');
  }
  
  /// Handle database upgrades for future versions
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Future migrations will be handled here
    // For now, we're at version 1, so no migrations needed
  }
  
  // ========================================
  // StudyClass CRUD Operations
  // ========================================
  
  /// Insert a new StudyClass
  Future<int> insertStudyClass(StudyClass studyClass) async {
    final db = await database;
    return await db.insert('study_classes', studyClass.toMap());
  }
  
  /// Get all StudyClasses
  Future<List<StudyClass>> getAllStudyClasses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'study_classes',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => StudyClass.fromMap(maps[i]));
  }
  
  /// Get StudyClass by ID
  Future<StudyClass?> getStudyClass(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'study_classes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return StudyClass.fromMap(maps.first);
    }
    return null;
  }
  
  /// Update StudyClass
  Future<int> updateStudyClass(StudyClass studyClass) async {
    final db = await database;
    return await db.update(
      'study_classes',
      studyClass.toMap(),
      where: 'id = ?',
      whereArgs: [studyClass.id],
    );
  }
  
  /// Delete StudyClass (cascades to lectures and flashcards)
  Future<int> deleteStudyClass(int id) async {
    final db = await database;
    return await db.delete(
      'study_classes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // ========================================
  // Lecture CRUD Operations
  // ========================================
  
  /// Insert a new Lecture
  Future<int> insertLecture(Lecture lecture) async {
    final db = await database;
    return await db.insert('lectures', lecture.toMap());
  }
  
  /// Get all Lectures for a StudyClass
  Future<List<Lecture>> getLecturesForClass(int classId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'lectures',
      where: 'class_id = ?',
      whereArgs: [classId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Lecture.fromMap(maps[i]));
  }
  
  /// Get Lecture by ID
  Future<Lecture?> getLecture(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'lectures',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Lecture.fromMap(maps.first);
    }
    return null;
  }
  
  /// Update Lecture
  Future<int> updateLecture(Lecture lecture) async {
    final db = await database;
    return await db.update(
      'lectures',
      lecture.toMap(),
      where: 'id = ?',
      whereArgs: [lecture.id],
    );
  }
  
  /// Delete Lecture (cascades to flashcards)
  Future<int> deleteLecture(int id) async {
    final db = await database;
    return await db.delete(
      'lectures',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // ========================================
  // Flashcard CRUD Operations
  // ========================================
  
  /// Insert a new Flashcard
  Future<int> insertFlashcard(Flashcard flashcard) async {
    final db = await database;
    return await db.insert('flashcards', flashcard.toMap());
  }
  
  /// Get all Flashcards for a Lecture
  Future<List<Flashcard>> getFlashcardsForLecture(int lectureId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'flashcards',
      where: 'lecture_id = ?',
      whereArgs: [lectureId],
      orderBy: 'next_review ASC',
    );
    return List.generate(maps.length, (i) => Flashcard.fromMap(maps[i]));
  }
  
  /// Get Flashcards due for review
  Future<List<Flashcard>> getFlashcardsDueForReview({int limit = 10}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final List<Map<String, dynamic>> maps = await db.query(
      'flashcards',
      where: 'is_active = 1 AND next_review <= ?',
      whereArgs: [now],
      orderBy: 'next_review ASC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => Flashcard.fromMap(maps[i]));
  }
  
  /// Get active Flashcards (for notifications)
  Future<List<Flashcard>> getActiveFlashcards() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'flashcards',
      where: 'is_active = 1',
      orderBy: 'next_review ASC',
    );
    return List.generate(maps.length, (i) => Flashcard.fromMap(maps[i]));
  }
  
  /// Get Flashcard by ID
  Future<Flashcard?> getFlashcard(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'flashcards',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Flashcard.fromMap(maps.first);
    }
    return null;
  }
  
  /// Update Flashcard
  Future<int> updateFlashcard(Flashcard flashcard) async {
    final db = await database;
    return await db.update(
      'flashcards',
      flashcard.toMap(),
      where: 'id = ?',
      whereArgs: [flashcard.id],
    );
  }
  
  /// Delete Flashcard
  Future<int> deleteFlashcard(int id) async {
    final db = await database;
    return await db.delete(
      'flashcards',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // ========================================
  // StudySession CRUD Operations
  // ========================================
  
  /// Insert a new StudySession
  Future<int> insertStudySession(StudySession session) async {
    final db = await database;
    return await db.insert('study_sessions', session.toMap());
  }
  
  /// Get all StudySessions for a Flashcard
  Future<List<StudySession>> getSessionsForFlashcard(int flashcardId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'study_sessions',
      where: 'flashcard_id = ?',
      whereArgs: [flashcardId],
      orderBy: 'session_date DESC',
    );
    return List.generate(maps.length, (i) => StudySession.fromMap(maps[i]));
  }
  
  /// Get recent StudySessions (for analytics)
  Future<List<StudySession>> getRecentSessions({int limit = 50}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'study_sessions',
      orderBy: 'session_date DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => StudySession.fromMap(maps[i]));
  }
  
  // ========================================
  // Analytics & Aggregation Queries
  // ========================================
  
  /// Get total study statistics
  Future<Map<String, int>> getStudyStatistics() async {
    final db = await database;
    
    // Count total classes
    final classCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM study_classes')
    ) ?? 0;
    
    // Count total lectures
    final lectureCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM lectures')
    ) ?? 0;
    
    // Count total flashcards
    final flashcardCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM flashcards')
    ) ?? 0;
    
    // Count active flashcards
    final activeFlashcardCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM flashcards WHERE is_active = 1')
    ) ?? 0;
    
    // Count total sessions
    final sessionCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM study_sessions')
    ) ?? 0;
    
    // Count correct sessions
    final correctSessionCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM study_sessions WHERE was_correct = 1')
    ) ?? 0;
    
    return {
      'classes': classCount,
      'lectures': lectureCount,
      'flashcards': flashcardCount,
      'activeFlashcards': activeFlashcardCount,
      'totalSessions': sessionCount,
      'correctSessions': correctSessionCount,
    };
  }
  
  /// Update computed fields (flashcard counts, etc.)
  Future<void> updateComputedFields() async {
    final db = await database;
    
    // Update lecture flashcard counts
    await db.rawUpdate('''
      UPDATE lectures 
      SET flashcard_count = (
        SELECT COUNT(*) 
        FROM flashcards 
        WHERE flashcards.lecture_id = lectures.id
      )
    ''');
    
    // Update study class flashcard counts
    await db.rawUpdate('''
      UPDATE study_classes 
      SET total_flashcards = (
        SELECT COUNT(*) 
        FROM flashcards 
        INNER JOIN lectures ON flashcards.lecture_id = lectures.id 
        WHERE lectures.class_id = study_classes.id
      ),
      active_flashcards = (
        SELECT COUNT(*) 
        FROM flashcards 
        INNER JOIN lectures ON flashcards.lecture_id = lectures.id 
        WHERE lectures.class_id = study_classes.id AND flashcards.is_active = 1
      )
    ''');
  }
  
  /// Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}