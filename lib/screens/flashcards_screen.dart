import 'dart:async';
import 'package:flutter/material.dart';
import '../models/index.dart';
import '../services/study_repository.dart';

/// Flashcards screen - manages flashcards within a specific lecture
class FlashcardsScreen extends StatefulWidget {
  final StudyClass studyClass;
  final Lecture lecture;

  const FlashcardsScreen({
    super.key,
    required this.studyClass,
    required this.lecture,
  });

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  List<Flashcard> _flashcards = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  Set<int> _selectedCards = {};
  
  // Undo functionality
  List<Flashcard>? _deletedFlashcards;
  Timer? _undoTimer;

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFlashcards() async {
    try {
      final repository = StudyRepository();
      final flashcards = await repository.getFlashcardsForLecture(widget.lecture.id!);
      setState(() {
        _flashcards = flashcards;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addNewFlashcard() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddFlashcardDialog(),
    );

    if (result != null) {
      try {
        final repository = StudyRepository();
        await repository.createFlashcard(
          lectureId: widget.lecture.id!,
          question: result['question']!,
          answer: result['answer']!,
          isActive: result['isActive'] ?? true,
          difficulty: result['difficulty'],
        );
        _loadFlashcards(); // Refresh the list
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Flashcard created!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to create flashcard: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleCardActive(Flashcard card) async {
    try {
      final repository = StudyRepository();
      final updatedCard = card.copyWith(isActive: !card.isActive);
      await repository.updateFlashcard(updatedCard);
      _loadFlashcards();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedCard.isActive 
                  ? '✅ Card added to study rotation' 
                  : '⏸️ Card removed from study rotation',
            ),
            backgroundColor: updatedCard.isActive ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to update card: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedCards.clear();
    });
  }

  void _toggleCardSelection(int cardId) {
    setState(() {
      if (_selectedCards.contains(cardId)) {
        _selectedCards.remove(cardId);
      } else {
        _selectedCards.add(cardId);
      }
    });
  }

  Future<void> _batchToggleActive(bool makeActive) async {
    try {
      final repository = StudyRepository();
      
      for (final cardId in _selectedCards) {
        final card = _flashcards.firstWhere((c) => c.id == cardId);
        final updatedCard = card.copyWith(isActive: makeActive);
        await repository.updateFlashcard(updatedCard);
      }
      
      _loadFlashcards();
      setState(() {
        _isSelectionMode = false;
        _selectedCards.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              makeActive 
                  ? '✅ ${_selectedCards.length} cards added to study rotation'
                  : '⏸️ ${_selectedCards.length} cards removed from study rotation',
            ),
            backgroundColor: makeActive ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to update cards: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _batchDeleteSelected() async {
    final selectedCount = _selectedCards.length;
    final selectedFlashcards = _flashcards.where((c) => _selectedCards.contains(c.id)).toList();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Flashcards'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete $selectedCount selected flashcard${selectedCount > 1 ? 's' : ''}?'),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: Card(
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
                            'Selected flashcards:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: selectedFlashcards.length,
                          itemBuilder: (context, index) {
                            final card = selectedFlashcards[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• ${card.question}',
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
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
            child: Text('Delete $selectedCount Card${selectedCount > 1 ? 's' : ''}', 
                       style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteFlashcardsWithUndo(selectedFlashcards);
      setState(() {
        _isSelectionMode = false;
        _selectedCards.clear();
      });
    }
  }

  Future<void> _deleteFlashcardsWithUndo(List<Flashcard> flashcardsToDelete) async {
    try {
      // Cancel any existing undo timer
      _undoTimer?.cancel();
      
      final repository = StudyRepository();
      
      // Store deleted flashcards for undo
      _deletedFlashcards = List.from(flashcardsToDelete);
      
      // Delete the flashcards
      for (final flashcard in flashcardsToDelete) {
        await repository.deleteFlashcard(flashcard.id!);
      }
      
      _loadFlashcards(); // Refresh the list
      
      if (mounted) {
        final count = flashcardsToDelete.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ $count flashcard${count > 1 ? 's' : ''} deleted'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: _undoDelete,
            ),
          ),
        );
        
        // Set timer to clear undo data after 10 seconds
        _undoTimer = Timer(const Duration(seconds: 10), () {
          _deletedFlashcards = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to delete flashcards: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _undoDelete() async {
    if (_deletedFlashcards == null) return;
    
    try {
      final repository = StudyRepository();
      
      // Restore the flashcards
      for (final flashcard in _deletedFlashcards!) {
        await repository.createFlashcard(
          lectureId: flashcard.lectureId,
          question: flashcard.question,
          answer: flashcard.answer,
          difficulty: flashcard.difficulty,
          isActive: flashcard.isActive,
        );
      }
      
      _loadFlashcards(); // Refresh the list
      _undoTimer?.cancel();
      final count = _deletedFlashcards!.length;
      _deletedFlashcards = null;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('↩️ $count flashcard${count > 1 ? 's' : ''} restored'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to restore flashcards: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _batchMoveSelected() async {
    final selectedCount = _selectedCards.length;
    
    try {
      final repository = StudyRepository();
      final allLectures = await repository.getLecturesForClass(widget.studyClass.id!);
      final availableLectures = allLectures.where((l) => l.id != widget.lecture.id).toList();
      
      if (availableLectures.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ℹ️ No other lectures available to move to. Create another lecture first.'),
            backgroundColor: Colors.blue,
          ),
        );
        return;
      }

      final targetLecture = await showDialog<Lecture>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Move $selectedCount Flashcard${selectedCount > 1 ? 's' : ''}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose the lecture to move the selected flashcard${selectedCount > 1 ? 's' : ''} to:'),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: availableLectures.map((lecture) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
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
                        subtitle: Text('${lecture.flashcardCount} existing flashcards'),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () => Navigator.of(context).pop(lecture),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (targetLecture != null) {
        // Move the flashcards
        for (final cardId in _selectedCards) {
          final card = _flashcards.firstWhere((c) => c.id == cardId);
          final updatedCard = card.copyWith(lectureId: targetLecture.id);
          await repository.updateFlashcard(updatedCard);
        }
        
        _loadFlashcards(); // Refresh the list
        setState(() {
          _isSelectionMode = false;
          _selectedCards.clear();
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📁 $selectedCount flashcard${selectedCount > 1 ? 's' : ''} moved to "${targetLecture.title}"'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to move flashcards: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editFlashcard(Flashcard flashcard) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditFlashcardDialog(flashcard: flashcard),
    );

    if (result != null) {
      try {
        final repository = StudyRepository();
        final updatedCard = flashcard.copyWith(
          question: result['question'],
          answer: result['answer'],
          difficulty: result['difficulty'],
        );
        await repository.updateFlashcard(updatedCard);
        _loadFlashcards(); // Refresh the list
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Flashcard updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to update flashcard: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteFlashcard(Flashcard flashcard) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Flashcard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this flashcard?'),
            const SizedBox(height: 16),
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Q: ${flashcard.question}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A: ${flashcard.answer}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
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
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteFlashcardsWithUndo([flashcard]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _flashcards.where((c) => c.isActive).length;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.studyClass.name} → ${widget.lecture.title}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _flashcards.isEmpty 
                  ? 'No flashcards' 
                  : '$activeCount/${_flashcards.length} active',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Color(int.parse(widget.studyClass.color.substring(1), radix: 16) + 0xFF000000),
        foregroundColor: Colors.white,
        actions: [
          if (_flashcards.isNotEmpty)
            IconButton(
              icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
              onPressed: _toggleSelectionMode,
              tooltip: _isSelectionMode ? 'Exit selection' : 'Select multiple',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFlashcards,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _flashcards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.quiz,
                        size: 80,
                        color: Color(int.parse(widget.studyClass.color.substring(1), radix: 16) + 0xFF000000),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Flashcards Yet',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add flashcards to\n${widget.lecture.title}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tap the + button to add a flashcard',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_isSelectionMode) ...[
                      Container(
                        color: Colors.blue[50],
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text('${_selectedCards.length} selected'),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _isSelectionMode = false;
                                      _selectedCards.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Exit selection',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _selectedCards.isEmpty ? null : () => _batchToggleActive(true),
                                  icon: const Icon(Icons.play_arrow, size: 16),
                                  label: const Text('Activate'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _selectedCards.isEmpty ? null : () => _batchToggleActive(false),
                                  icon: const Icon(Icons.pause, size: 16),
                                  label: const Text('Deactivate'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _selectedCards.isEmpty ? null : _batchMoveSelected,
                                  icon: const Icon(Icons.folder_copy, size: 16),
                                  label: const Text('Move'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _selectedCards.isEmpty ? null : _batchDeleteSelected,
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: const Text('Delete'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _flashcards.length,
                        itemBuilder: (context, index) {
                          final flashcard = _flashcards[index];
                          final isSelected = _selectedCards.contains(flashcard.id);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: isSelected ? Colors.blue[50] : null,
                            child: ListTile(
                              leading: _isSelectionMode
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (_) => _toggleCardSelection(flashcard.id!),
                                    )
                                  : CircleAvatar(
                                      backgroundColor: flashcard.isActive ? Colors.green : Colors.grey,
                                      child: Icon(
                                        flashcard.isActive ? Icons.play_arrow : Icons.pause,
                                        color: Colors.white,
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
                                  Text(
                                    flashcard.answer,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
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
                                      const SizedBox(width: 8),
                                      Text(
                                        flashcard.isActive ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: flashcard.isActive ? Colors.green : Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: _isSelectionMode 
                                  ? null 
                                  : PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'edit':
                                            _editFlashcard(flashcard);
                                            break;
                                          case 'toggle':
                                            _toggleCardActive(flashcard);
                                            break;
                                          case 'delete':
                                            _deleteFlashcard(flashcard);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: ListTile(
                                            leading: Icon(Icons.edit, size: 20),
                                            title: Text('Edit'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: ListTile(
                                            leading: Icon(
                                              flashcard.isActive ? Icons.pause : Icons.play_arrow,
                                              size: 20,
                                              color: flashcard.isActive ? Colors.orange : Colors.green,
                                            ),
                                            title: Text(flashcard.isActive ? 'Remove from Study' : 'Add to Study'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: ListTile(
                                            leading: Icon(Icons.delete, size: 20, color: Colors.red),
                                            title: Text('Delete', style: TextStyle(color: Colors.red)),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ],
                                    ),
                              onTap: _isSelectionMode
                                  ? () => _toggleCardSelection(flashcard.id!)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _isSelectionMode
          ? FloatingActionButton(
              onPressed: _batchDeleteSelected,
              tooltip: 'Delete Selected',
              backgroundColor: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            )
          : FloatingActionButton(
              onPressed: _addNewFlashcard,
              tooltip: 'Add Flashcard',
              child: const Icon(Icons.add),
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

/// Dialog for adding new flashcards
class _AddFlashcardDialog extends StatefulWidget {
  @override
  State<_AddFlashcardDialog> createState() => _AddFlashcardDialogState();
}

class _AddFlashcardDialogState extends State<_AddFlashcardDialog> {
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  String? _selectedDifficulty;
  bool _isActive = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Flashcard'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'What do you want to remember?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(
                labelText: 'Answer',
                hintText: 'The correct answer',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedDifficulty,
              decoration: const InputDecoration(
                labelText: 'Difficulty (Optional)',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'easy', child: Text('Easy')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'hard', child: Text('Hard')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedDifficulty = value;
                });
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Include in study rotation'),
              subtitle: const Text('Active cards appear in notifications'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value ?? true;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _questionController.text.trim().isEmpty || _answerController.text.trim().isEmpty
              ? null
              : () {
                  Navigator.of(context).pop({
                    'question': _questionController.text.trim(),
                    'answer': _answerController.text.trim(),
                    'difficulty': _selectedDifficulty,
                    'isActive': _isActive,
                  });
                },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Dialog for editing existing flashcards
class _EditFlashcardDialog extends StatefulWidget {
  final Flashcard flashcard;
  
  const _EditFlashcardDialog({required this.flashcard});

  @override
  State<_EditFlashcardDialog> createState() => _EditFlashcardDialogState();
}

class _EditFlashcardDialogState extends State<_EditFlashcardDialog> {
  late final TextEditingController _questionController;
  late final TextEditingController _answerController;
  String? _selectedDifficulty;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.flashcard.question);
    _answerController = TextEditingController(text: widget.flashcard.answer);
    _selectedDifficulty = widget.flashcard.difficulty;
    
    _questionController.addListener(_updateButtonState);
    _answerController.addListener(_updateButtonState);
    _updateButtonState();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    setState(() {
      _isValid = _questionController.text.trim().isNotEmpty && 
                 _answerController.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Flashcard'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'What do you want to remember?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(
                labelText: 'Answer',
                hintText: 'The correct answer',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedDifficulty,
              decoration: const InputDecoration(
                labelText: 'Difficulty (Optional)',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('No difficulty set')),
                DropdownMenuItem(value: 'easy', child: Text('Easy')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'hard', child: Text('Hard')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedDifficulty = value;
                });
              },
            ),
          ],
        ),
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
                    'question': _questionController.text.trim(),
                    'answer': _answerController.text.trim(),
                    'difficulty': _selectedDifficulty,
                  });
                },
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
}