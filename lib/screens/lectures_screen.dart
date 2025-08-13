import 'dart:async';
import 'package:flutter/material.dart';
import '../models/index.dart';
import '../services/study_repository.dart';
import 'flashcards_screen.dart';

/// Lectures screen - displays lectures for a specific class
class LecturesScreen extends StatefulWidget {
  final StudyClass studyClass;

  const LecturesScreen({
    super.key,
    required this.studyClass,
  });

  @override
  State<LecturesScreen> createState() => _LecturesScreenState();
}

class _LecturesScreenState extends State<LecturesScreen> {
  List<Lecture> _lectures = [];
  bool _isLoading = true;
  Lecture? _deletedLecture;
  List<Flashcard>? _deletedFlashcards;
  Timer? _undoTimer;

  @override
  void initState() {
    super.initState();
    _loadLectures();
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLectures() async {
    try {
      final repository = StudyRepository();
      final lectures = await repository.getLecturesForClass(widget.studyClass.id!);
      setState(() {
        _lectures = lectures;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addNewLecture() async {
    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => _AddLectureDialog(),
    );

    if (result != null) {
      try {
        final repository = StudyRepository();
        await repository.createLecture(
          classId: widget.studyClass.id!,
          title: result['title']!,
          notes: result['notes'],
        );
        _loadLectures(); // Refresh the list
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Lecture "${result['title']}" created!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to create lecture: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteLecture(Lecture lecture) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lecture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${lecture.title}"?'),
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
                    Text('• "${lecture.title}" lecture'),
                    Text('• ${lecture.flashcardCount} flashcards'),
                    Text('• All study progress for these flashcards'),
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
            child: const Text('Delete Lecture', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        _deleteLectureWithUndo(lecture);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to delete lecture: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.studyClass.name),
            Text(
              _lectures.isEmpty ? 'No lectures' : '${_lectures.length} lectures',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Color(int.parse(widget.studyClass.color.substring(1), radix: 16) + 0xFF000000),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLectures,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lectures.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book,
                        size: 80,
                        color: Color(int.parse(widget.studyClass.color.substring(1), radix: 16) + 0xFF000000),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Lectures Yet',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add lectures to organize your\n${widget.studyClass.name} content',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tap the + button to add a lecture',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lectures.length,
                  itemBuilder: (context, index) {
                    final lecture = _lectures[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(int.parse(widget.studyClass.color.substring(1), radix: 16) + 0xFF000000),
                          child: Text(
                            lecture.title.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          lecture.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (lecture.notes != null && lecture.notes!.isNotEmpty)
                              Text(
                                lecture.notes!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              '${lecture.flashcardCount} flashcards',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            switch (value) {
                              case 'view':
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FlashcardsScreen(
                                      studyClass: widget.studyClass,
                                      lecture: lecture,
                                    ),
                                  ),
                                );
                                break;
                              case 'delete':
                                _deleteLecture(lecture);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: ListTile(
                                leading: Icon(Icons.quiz, size: 20),
                                title: Text('View Flashcards'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete, size: 20, color: Colors.red),
                                title: Text('Delete Lecture', style: TextStyle(color: Colors.red)),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FlashcardsScreen(
                                studyClass: widget.studyClass,
                                lecture: lecture,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewLecture,
        tooltip: 'Add Lecture',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _deleteLectureWithUndo(Lecture lecture) async {
    try {
      final repository = StudyRepository();
      
      // First, get all flashcards for this lecture
      final flashcards = await repository.getFlashcardsForLecture(lecture.id!);
      
      // Delete the lecture
      await repository.deleteLecture(lecture.id!);
      
      // Store for undo
      _deletedLecture = lecture;
      _deletedFlashcards = flashcards;
      
      _loadLectures(); // Refresh the list
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ "${lecture.title}" deleted with ${lecture.flashcardCount} flashcards'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: _undoLectureDelete,
            ),
          ),
        );
        
        // Set timer to clear undo data after 10 seconds
        _undoTimer = Timer(const Duration(seconds: 10), () {
          _deletedLecture = null;
          _deletedFlashcards = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to delete lecture: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _undoLectureDelete() async {
    if (_deletedLecture == null || _deletedFlashcards == null) return;
    
    try {
      final repository = StudyRepository();
      
      // Recreate the lecture
      final newLecture = await repository.createLecture(
        classId: widget.studyClass.id!,
        title: _deletedLecture!.title,
        notes: _deletedLecture!.notes,
      );
      
      // Recreate all flashcards
      for (final flashcard in _deletedFlashcards!) {
        await repository.createFlashcard(
          lectureId: newLecture.id!,
          question: flashcard.question,
          answer: flashcard.answer,
          difficulty: flashcard.difficulty,
          isActive: flashcard.isActive,
        );
      }
      
      _loadLectures(); // Refresh the list
      _undoTimer?.cancel();
      final lectureTitle = _deletedLecture!.title;
      final flashcardCount = _deletedFlashcards!.length;
      _deletedLecture = null;
      _deletedFlashcards = null;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('↩️ "$lectureTitle" restored with $flashcardCount flashcards'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to restore lecture: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

/// Dialog for adding new lectures
class _AddLectureDialog extends StatefulWidget {
  @override
  State<_AddLectureDialog> createState() => _AddLectureDialogState();
}

class _AddLectureDialogState extends State<_AddLectureDialog> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    setState(() {
      _isValid = _titleController.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Lecture'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Lecture Title',
              hintText: 'e.g., Neural Network Fundamentals',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (Optional)',
              hintText: 'Brief description of the lecture',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: !_isValid
              ? null
              : () {
                  Navigator.of(context).pop({
                    'title': _titleController.text.trim(),
                    'notes': _notesController.text.trim().isEmpty 
                        ? null 
                        : _notesController.text.trim(),
                  });
                },
          child: const Text('Create'),
        ),
      ],
    );
  }
}