// ─── Workout Models ──────────────────────────────────────────────────────────

class MuscleGroup {
  final String id;
  final String name;
  final String icon;
  final int color;
  final String description;
  final List<Exercise> exercises;

  const MuscleGroup({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.description = '',
    required this.exercises,
  });
}

class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String difficulty;
  final String equipment;
  final int durationSeconds;
  final int sets;
  final String reps;
  final String description;
  final List<String> steps;
  final List<String> formCues;
  final int kalories;
  final List<String> muscles;
  final String previewEmoji;
  /// Folder name in the free-exercise-db GitHub repo.
  /// Full frame URLs:
  ///   https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/{gifUrl}/0.jpg
  ///   https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/{gifUrl}/1.jpg
  /// Empty string means no animation available — falls back to emoji display.
  final String gifUrl;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.difficulty,
    required this.equipment,
    required this.durationSeconds,
    required this.sets,
    required this.reps,
    required this.description,
    required this.steps,
    required this.formCues,
    required this.kalories,
    required this.muscles,
    required this.previewEmoji,
    this.gifUrl = '',
  });
}

class WorkoutPreset {
  final String id;
  final String name;
  final String level;
  final String duration;
  final String icon;
  final int color;
  final List<String> exerciseIds;
  final String description;

  const WorkoutPreset({
    required this.id,
    required this.name,
    required this.level,
    required this.duration,
    required this.icon,
    required this.color,
    required this.exerciseIds,
    this.description = '',
  });
}

// ─── Session Models ──────────────────────────────────────────────────────────

class SessionModel {
  final String id;
  final String workoutName;
  final String muscleGroup;
  final DateTime date;
  final int durationMinutes;
  final double caloriesBurned;
  final double accuracyScore;
  final List<String> musclesWorked;
  final String intensity;
  final String aiSuggestion;
  /// Names of individual exercises performed in this session.
  final List<String> exerciseNames;

  const SessionModel({
    required this.id,
    required this.workoutName,
    required this.muscleGroup,
    required this.date,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.accuracyScore,
    required this.musclesWorked,
    required this.intensity,
    this.aiSuggestion = '',
    this.exerciseNames = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'workoutName': workoutName,
        'muscleGroup': muscleGroup,
        'date': date.toIso8601String(),
        'durationMinutes': durationMinutes,
        'caloriesBurned': caloriesBurned,
        'accuracyScore': accuracyScore,
        'musclesWorked': musclesWorked,
        'intensity': intensity,
        'aiSuggestion': aiSuggestion,
        'exerciseNames': exerciseNames,
      };

  factory SessionModel.fromJson(Map<String, dynamic> j) => SessionModel(
        id: j['id'] as String,
        workoutName: j['workoutName'] as String,
        muscleGroup: j['muscleGroup'] as String,
        date: DateTime.parse(j['date'] as String),
        durationMinutes: (j['durationMinutes'] as num).toInt(),
        caloriesBurned: (j['caloriesBurned'] as num).toDouble(),
        accuracyScore: (j['accuracyScore'] as num).toDouble(),
        musclesWorked: List<String>.from(j['musclesWorked'] ?? []),
        intensity: j['intensity'] as String? ?? 'Moderate',
        aiSuggestion: j['aiSuggestion'] as String? ?? '',
        exerciseNames: List<String>.from(j['exerciseNames'] ?? []),
      );
}

// ─── Chat Message Model ──────────────────────────────────────────────────────

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
  });

  ChatMessage copyWith({String? content, bool? isLoading}) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      isUser: isUser,
      timestamp: timestamp,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':        id,
    'content':   content,
    'isUser':    isUser,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id:        j['id'] as String,
    content:   j['content'] as String,
    isUser:    j['isUser'] as bool,
    timestamp: DateTime.parse(j['timestamp'] as String),
  );
}
