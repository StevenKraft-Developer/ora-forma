import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// UUID generator — single instance, safe to share across the app.
// ---------------------------------------------------------------------------
const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Default Catholic habit set.
// Stable IDs are intentional: existing DailyProgress history keys off these
// strings, so they must never change.
// ---------------------------------------------------------------------------
const List<Habit> kDefaultCatholicHabitSet = [
  Habit(id: 'morning_prayer',     title: 'Morning Prayer',      sortOrder: 0),
  Habit(id: 'bible_reading',      title: 'Bible Reading',       sortOrder: 1),
  Habit(id: 'clean_eating',       title: 'Clean Eating',        sortOrder: 2),
  Habit(id: 'exercise_30',        title: '30-Minute Exercise',  sortOrder: 3),
  Habit(id: 'evening_reflection', title: 'Evening Reflection',  sortOrder: 4),
];

// ---------------------------------------------------------------------------
// Habit model
// ---------------------------------------------------------------------------
class Habit {
  final String id;
  final String title;
  final String? description;
  final int sortOrder;
  final bool isArchived;

  /// Primary constructor — used by const contexts (e.g. kDefaultCatholicHabitSet)
  /// and any code that already has an ID in hand.
  ///
  /// [id] and [title] are required to stay backward-compatible with the
  /// existing ProgressProvider instantiation:
  ///   Habit(id: 'morning_prayer', title: 'Morning Prayer')
  /// The new fields all default to safe values so existing call-sites compile
  /// without modification.
  const Habit({
    required this.id,
    required this.title,
    this.description,
    this.sortOrder = 0,
    this.isArchived = false,
  });

  /// Factory that generates a fresh UUID v4 ID automatically.
  /// Use this when creating a brand-new user-defined habit.
  factory Habit.create({
    required String title,
    String? description,
    int sortOrder = 0,
  }) {
    return Habit(
      id: _uuid.v4(),
      title: title,
      description: description,
      sortOrder: sortOrder,
      isArchived: false,
    );
  }

  // -------------------------------------------------------------------------
  // Serialization
  // -------------------------------------------------------------------------

  factory Habit.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final sortOrder = json['sortOrder'];

    if (id == null || id is! String || id.isEmpty) {
      throw FormatException('Habit.fromJson: missing or empty required field "id"');
    }
    if (title == null || title is! String || title.isEmpty) {
      throw FormatException('Habit.fromJson: missing or empty required field "title"');
    }
    if (sortOrder == null || sortOrder is! int) {
      throw FormatException('Habit.fromJson: missing or invalid required field "sortOrder"');
    }

    return Habit(
      id: id,
      title: title,
      description: json['description'] as String?,     // null if absent — OK
      sortOrder: sortOrder,
      isArchived: json['isArchived'] as bool? ?? false, // false if absent — OK
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'sortOrder': sortOrder,
    'isArchived': isArchived,
  };

  // -------------------------------------------------------------------------
  // copyWith — supports edit and archive flows in later tasks
  // -------------------------------------------------------------------------

  Habit copyWith({
    String? id,
    String? title,
    String? description,
    int? sortOrder,
    bool? isArchived,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  // -------------------------------------------------------------------------
  // Equality and debug helpers
  // -------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Habit &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          sortOrder == other.sortOrder &&
          isArchived == other.isArchived;

  @override
  int get hashCode =>
      Object.hash(id, title, description, sortOrder, isArchived);

  @override
  String toString() =>
      'Habit(id: $id, title: $title, sortOrder: $sortOrder, isArchived: $isArchived)';
}
