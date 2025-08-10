# Models

Data classes that represent the core entities in ML MicroLearn:

- `study_class.dart` - Class/course information
- `lecture.dart` - Individual lectures within a class  
- `flashcard.dart` - Question/answer pairs with spaced repetition data
- `study_session.dart` - Individual study session tracking

Each model includes:
- Database serialization (`toMap()`, `fromMap()`)
- Immutable updates (`copyWith()`)
- Validation and business logic