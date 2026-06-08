class DailyProgress {
  final String dateKey;
  final List<String> completedHabitIds;

  const DailyProgress({
    required this.dateKey,
    required this.completedHabitIds,
  });

  factory DailyProgress.fromJson(Map<String, dynamic> json) {
    return DailyProgress(
      dateKey: json['dateKey'] as String,
      completedHabitIds: List<String>.from(
        json['completedHabitIds'] as List<dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateKey': dateKey,
      'completedHabitIds': completedHabitIds,
    };
  }

  DailyProgress copyWith({
    String? dateKey,
    List<String>? completedHabitIds,
  }) {
    return DailyProgress(
      dateKey: dateKey ?? this.dateKey,
      completedHabitIds: completedHabitIds ?? this.completedHabitIds,
    );
  }
}