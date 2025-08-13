import 'dart:async';
import 'package:flutter/material.dart';
import 'services/database_helper.dart';
import 'services/study_repository.dart';
import 'models/index.dart';
import 'screens/lectures_screen.dart';

void main() {
  runApp(const MLMicroLearnApp());
}

class MLMicroLearnApp extends StatelessWidget {
  const MLMicroLearnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ML MicroLearn',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<_ClassesTabState> _classesTabKey = GlobalKey<_ClassesTabState>();

  // Screens for each tab
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const StudyTab(),
      ClassesTab(key: _classesTabKey),
      const ProgressTab(),
      const SettingsTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: 'Study',
          ),
          NavigationDestination(
            icon: Icon(Icons.class_outlined),
            selectedIcon: Icon(Icons.class_),
            label: 'Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 1 // Only show on Classes tab
          ? FloatingActionButton(
              onPressed: () async {
                await _classesTabKey.currentState?._addNewClass();
              },
              tooltip: 'Add Class',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// Test database functionality with sample ML data
  Future<void> _testDatabase(BuildContext context) async {
    try {
      final repository = StudyRepository();
      
      // Initialize sample data (includes ML flashcards)
      await repository.initializeSampleData();
      
      // Get active flashcards to confirm
      final activeCards = await repository.getActiveFlashcards();
      final allClasses = await repository.getAllStudyClasses();
      
      if (!context.mounted) return;
      
      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Database initialized!\nClasses: ${allClasses.length}\nActive flashcards: ${activeCards.length}\nReady to study!'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh the UI to show data
      setState(() {});
      
    } catch (e) {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Database test failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

// Study tab - shows actual flashcards when available
class StudyTab extends StatefulWidget {
  const StudyTab({super.key});

  @override
  State<StudyTab> createState() => _StudyTabState();
}

class _StudyTabState extends State<StudyTab> {
  List<Flashcard> _flashcards = [];
  Map<String, List<Flashcard>> _flashcardsByClass = {};
  List<StudyClass> _classes = [];
  Map<int, StudyClass> _flashcardToClass = {}; // Maps flashcard id to class
  Map<int, Lecture> _flashcardToLecture = {}; // Maps flashcard id to lecture
  int _currentCardIndex = 0;
  bool _showAnswer = false;
  bool _isLoading = true;
  bool _isStudyMode = false; // New: toggle between list and study mode

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  Future<void> _loadFlashcards() async {
    try {
      final repository = StudyRepository();
      final activeCards = await repository.getActiveFlashcards();
      final allClasses = await repository.getAllStudyClasses();
      
      // Order flashcards by class and lecture, and build mapping
      final orderedFlashcards = <Flashcard>[];
      final flashcardsByClass = <String, List<Flashcard>>{};
      final flashcardToClass = <int, StudyClass>{};
      final flashcardToLecture = <int, Lecture>{};
      
      for (final studyClass in allClasses) {
        final lectures = await repository.getLecturesForClass(studyClass.id!);
        final classFlashcards = <Flashcard>[];
        
        for (final lecture in lectures) {
          final lectureCards = activeCards
              .where((card) => card.lectureId == lecture.id)
              .toList();
          
          // Add lecture cards to class flashcards and ordered list
          classFlashcards.addAll(lectureCards);
          orderedFlashcards.addAll(lectureCards);
          
          // Build mapping for each flashcard
          for (final card in lectureCards) {
            flashcardToClass[card.id!] = studyClass;
            flashcardToLecture[card.id!] = lecture;
          }
        }
        
        if (classFlashcards.isNotEmpty) {
          flashcardsByClass[studyClass.name] = classFlashcards;
        }
      }
      
      setState(() {
        _flashcards = orderedFlashcards; // Now properly ordered by class -> lecture
        _flashcardsByClass = flashcardsByClass;
        _classes = allClasses;
        _flashcardToClass = flashcardToClass;
        _flashcardToLecture = flashcardToLecture;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleStudyMode() {
    setState(() {
      _isStudyMode = !_isStudyMode;
      if (_isStudyMode) {
        _currentCardIndex = 0;
        _showAnswer = false;
      }
    });
  }

  void _nextCard() {
    setState(() {
      if (_currentCardIndex < _flashcards.length - 1) {
        _currentCardIndex++;
        _showAnswer = false;
      } else {
        // End of study session - return to list mode
        _isStudyMode = false;
        _currentCardIndex = 0;
        _showAnswer = false;
      }
    });
  }

  void _markCorrect() async {
    if (_flashcards.isNotEmpty) {
      try {
        final repository = StudyRepository();
        await repository.updateFlashcardAfterStudy(
          flashcard: _flashcards[_currentCardIndex],
          wasCorrect: true,
        );
      } catch (e) {
        // Log error but continue with session
        print('Error updating flashcard after study: $e');
      }
    }
    _nextCard();
  }

  void _markIncorrect() async {
    if (_flashcards.isNotEmpty) {
      try {
        final repository = StudyRepository();
        await repository.updateFlashcardAfterStudy(
          flashcard: _flashcards[_currentCardIndex],
          wasCorrect: false,
        );
      } catch (e) {
        // Log error but continue with session
        print('Error updating flashcard after study: $e');
      }
    }
    _nextCard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isStudyMode
          ? 'Study Session (${_currentCardIndex + 1}/${_flashcards.length})'
          : 'Study Overview'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isStudyMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleStudyMode,
              tooltip: 'Exit Study Mode',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _flashcards.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.quiz, size: 80, color: Colors.blue),
                      SizedBox(height: 16),
                      Text(
                        'Ready to Study?',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No flashcards available yet.\nTap the + button on Classes tab to create some!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : _isStudyMode
                  ? _buildStudyMode()
                  : _buildListMode(),
      floatingActionButton: null,
    );
  }

  Widget _buildListMode() {
    return Column(
      children: [
        // Study overview header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.quiz, color: Colors.blue[700], size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Study Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_flashcards.length} active flashcards ready for study',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _toggleStudyMode,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Study Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        // Flashcards list grouped by class
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _getListItemCount(),
            itemBuilder: (context, index) {
              return _buildListItem(index);
            },
          ),
        ),
      ],
    );
  }

  int _getListItemCount() {
    int count = 0;
    for (final className in _flashcardsByClass.keys) {
      count += 1; // Header
      count += _flashcardsByClass[className]!.length; // Flashcards
    }
    return count;
  }

  Widget _buildListItem(int index) {
    int currentIndex = 0;
    
    for (final className in _flashcardsByClass.keys) {
      // Check if this is the header
      if (currentIndex == index) {
        return _buildClassHeader(className);
      }
      currentIndex++;
      
      // Check if this is one of the flashcards for this class
      final classFlashcards = _flashcardsByClass[className]!;
      if (index < currentIndex + classFlashcards.length) {
        final flashcardIndex = index - currentIndex;
        final flashcard = classFlashcards[flashcardIndex];
        final globalIndex = _flashcards.indexOf(flashcard);
        return _buildFlashcardItem(flashcard, globalIndex);
      }
      currentIndex += classFlashcards.length;
    }
    
    return const SizedBox.shrink(); // Fallback
  }

  Widget _buildClassHeader(String className) {
    final studyClass = _classes.firstWhere((c) => c.name == className);
    final flashcardCount = _flashcardsByClass[className]!.length;
    
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color(int.parse(studyClass.color.substring(1), radix: 16) + 0xFF000000),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.class_, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$flashcardCount flashcard${flashcardCount > 1 ? 's' : ''} ready to study',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashcardItem(Flashcard flashcard, int globalIndex) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getDifficultyColor(flashcard.difficulty ?? 'medium'),
          child: Text(
            '${globalIndex + 1}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          flashcard.question,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              flashcard.answer,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            if (flashcard.difficulty != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getDifficultyColor(flashcard.difficulty!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  flashcard.difficulty!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.play_arrow, color: Colors.blue),
          onPressed: () {
            setState(() {
              _currentCardIndex = globalIndex;
              _isStudyMode = true;
              _showAnswer = false;
            });
          },
          tooltip: 'Study this card',
        ),
      ),
    );
  }

  Widget _buildStudyMode() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentCardIndex + 1) / _flashcards.length,
            backgroundColor: Colors.grey[300],
          ),
          const SizedBox(height: 32),
          
          // Flashcard
          Expanded(
            child: Card(
              elevation: 8,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showAnswer = !_showAnswer;
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Class and Lecture info at the top
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildClassLectureInfo(),
                            ),
                          ],
                        ),
                      ),
                      
                      // Main flashcard content
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_showAnswer) ...[
                              const Icon(Icons.help_outline, size: 48, color: Colors.blue),
                              const SizedBox(height: 16),
                              const Text(
                                'QUESTION',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _flashcards[_currentCardIndex].question,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              const Text(
                                'Tap to reveal answer',
                                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            ] else ...[
                              const Icon(Icons.lightbulb_outline, size: 48, color: Colors.green),
                              const SizedBox(height: 16),
                              const Text(
                                'ANSWER',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _flashcards[_currentCardIndex].answer,
                                style: const TextStyle(fontSize: 18),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Action buttons
          if (_showAnswer) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _markIncorrect,
                    icon: const Icon(Icons.close),
                    label: const Text('Need Practice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _markCorrect,
                    icon: const Icon(Icons.check),
                    label: const Text('Got It!'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClassLectureInfo() {
    if (_flashcards.isEmpty) return const SizedBox.shrink();
    
    final currentFlashcard = _flashcards[_currentCardIndex];
    final studyClass = _flashcardToClass[currentFlashcard.id];
    final lecture = _flashcardToLecture[currentFlashcard.id];
    
    if (studyClass == null || lecture == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Class color indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Color(int.parse(studyClass.color.substring(1), radix: 16) + 0xFF000000),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // Class and lecture text
          Flexible(
            child: Text(
              '${studyClass.name} → ${lecture.title}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// Classes tab - manages study classes and lectures
class ClassesTab extends StatefulWidget {
  const ClassesTab({super.key});

  @override
  State<ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<ClassesTab> {
  List<StudyClass> _classes = [];
  bool _isLoading = true;
  StudyClass? _deletedClass;
  List<Lecture>? _deletedLectures;
  List<Flashcard>? _deletedFlashcards;
  Timer? _undoTimer;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    try {
      final repository = StudyRepository();
      final classes = await repository.getAllStudyClasses();
      setState(() {
        _classes = classes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addNewClass() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _AddClassDialog(),
    );

    if (result != null) {
      try {
        final repository = StudyRepository();
        await repository.createStudyClass(
          name: result['name']!,
          description: result['description'],
          color: result['color']!,
        );
        _loadClasses(); // Refresh the list
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Class "${result['name']}" created!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to create class: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteClass(StudyClass studyClass) async {
    // First, get lecture and flashcard counts for the confirmation dialog
    try {
      final repository = StudyRepository();
      final lectures = await repository.getLecturesForClass(studyClass.id!);
      final totalFlashcards = studyClass.totalFlashcards;
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Class'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "${studyClass.name}"?'),
              const SizedBox(height: 16),
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'This will permanently delete:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('• ${lectures.length} lectures'),
                      Text('• $totalFlashcards flashcards'),
                      Text('• All study progress and history'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(
                  color: Colors.red,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete Class', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        _deleteClassWithUndo(studyClass, lectures);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to delete class: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_classes.isEmpty ? 'My Classes' : 'My Classes (${_classes.length})'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClasses,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.class_, size: 80, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'No Classes Yet',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Create your first class to start organizing\nyour study materials',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Tap the + button to add a class',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final studyClass = _classes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(int.parse(studyClass.color.substring(1), radix: 16) + 0xFF000000),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.class_, color: Colors.white),
                        ),
                        title: Text(
                          studyClass.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Total: ${studyClass.totalFlashcards} flashcards • Active: ${studyClass.activeFlashcards}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            switch (value) {
                              case 'view':
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LecturesScreen(studyClass: studyClass),
                                  ),
                                );
                                break;
                              case 'delete':
                                _deleteClass(studyClass);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: ListTile(
                                leading: Icon(Icons.folder_open, size: 20),
                                title: Text('View Lectures'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete, size: 20, color: Colors.red),
                                title: Text('Delete Class', style: TextStyle(color: Colors.red)),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LecturesScreen(studyClass: studyClass),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _deleteClassWithUndo(StudyClass studyClass, List<Lecture> lectures) async {
    try {
      final repository = StudyRepository();
      
      // Get all flashcards for all lectures in this class
      final allFlashcards = <Flashcard>[];
      for (final lecture in lectures) {
        final flashcards = await repository.getFlashcardsForLecture(lecture.id!);
        allFlashcards.addAll(flashcards);
      }
      
      // Delete the class (this will cascade delete lectures and flashcards)
      await repository.deleteStudyClass(studyClass.id!);
      
      // Store for undo
      _deletedClass = studyClass;
      _deletedLectures = lectures;
      _deletedFlashcards = allFlashcards;
      
      _loadClasses(); // Refresh the list
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ "${studyClass.name}" deleted with ${lectures.length} lectures and ${allFlashcards.length} flashcards'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: _undoClassDelete,
            ),
          ),
        );
        
        // Set timer to clear undo data after 10 seconds
        _undoTimer = Timer(const Duration(seconds: 10), () {
          _deletedClass = null;
          _deletedLectures = null;
          _deletedFlashcards = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to delete class: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _undoClassDelete() async {
    if (_deletedClass == null || _deletedLectures == null || _deletedFlashcards == null) return;
    
    try {
      final repository = StudyRepository();
      
      // Recreate the class
      final newClass = await repository.createStudyClass(
        name: _deletedClass!.name,
        description: _deletedClass!.description,
        color: _deletedClass!.color,
      );
      
      // Recreate all lectures and their flashcards
      for (final lecture in _deletedLectures!) {
        final newLecture = await repository.createLecture(
          classId: newClass.id!,
          title: lecture.title,
          notes: lecture.notes,
        );
        
        // Get flashcards that belonged to this lecture
        final lectureFlashcards = _deletedFlashcards!.where((fc) => fc.lectureId == lecture.id).toList();
        
        // Recreate flashcards for this lecture
        for (final flashcard in lectureFlashcards) {
          await repository.createFlashcard(
            lectureId: newLecture.id!,
            question: flashcard.question,
            answer: flashcard.answer,
            difficulty: flashcard.difficulty,
            isActive: flashcard.isActive,
          );
        }
      }
      
      _loadClasses(); // Refresh the list
      _undoTimer?.cancel();
      final className = _deletedClass!.name;
      final lectureCount = _deletedLectures!.length;
      final flashcardCount = _deletedFlashcards!.length;
      _deletedClass = null;
      _deletedLectures = null;
      _deletedFlashcards = null;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('↩️ "$className" restored with $lectureCount lectures and $flashcardCount flashcards'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to restore class: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

// Dialog for adding new classes
class _AddClassDialog extends StatefulWidget {
  @override
  State<_AddClassDialog> createState() => _AddClassDialogState();
}

class _AddClassDialogState extends State<_AddClassDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedColor = '#2196F3'; // Default blue
  
  final List<String> _colorOptions = [
    '#2196F3', // Blue
    '#4CAF50', // Green
    '#FF9800', // Orange
    '#9C27B0', // Purple
    '#F44336', // Red
    '#00BCD4', // Cyan
    '#795548', // Brown
    '#607D8B', // Blue Grey
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Class'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Class Name',
              hintText: 'e.g., Machine Learning',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'What is this class about?',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          const Text('Choose Color:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _colorOptions.map((color) {
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(int.parse(color.substring(1), radix: 16) + 0xFF000000),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () {
                  Navigator.of(context).pop({
                    'name': _nameController.text.trim(),
                    'description': _descriptionController.text.trim().isEmpty 
                        ? null 
                        : _descriptionController.text.trim(),
                    'color': _selectedColor,
                  });
                },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 80, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Track Your Progress',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Study some flashcards to see\nyour learning analytics here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Future<void> _initializeDatabase(BuildContext context) async {
    try {
      final repository = StudyRepository();
      await repository.initializeSampleData();
      
      final activeCards = await repository.getActiveFlashcards();
      final allClasses = await repository.getAllStudyClasses();
      
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Sample data initialized!\nClasses: ${allClasses.length} • Flashcards: ${activeCards.length}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to initialize: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Development Tools',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.data_usage, color: Colors.blue),
                title: const Text('Initialize Sample Data'),
                subtitle: const Text('Add ML flashcards for testing'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _initializeDatabase(context),
              ),
            ),
            const SizedBox(height: 32),
            const Center(
              child: Column(
                children: [
                  Icon(Icons.settings, size: 80, color: Colors.purple),
                  SizedBox(height: 16),
                  Text(
                    'App Settings',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Configure notifications, study preferences,\nand app behavior (coming soon)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
