// ─── User Model ─────────────────────────────────────────────────────────────

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final int age;
  final double weightKg;
  final double heightCm;
  final String gender;
  final List<String> healthConditions;
  final String fitnessGoal;
  final int totalWorkouts;
  final double totalCalories;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.age,
    required this.weightKg,
    required this.heightCm,
    this.gender = 'Male',
    this.healthConditions = const [],
    this.fitnessGoal = 'General Fitness',
    this.totalWorkouts = 0,
    this.totalCalories = 0,
  });

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  String get bmiCategory {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? photoUrl,
    int? age,
    double? weightKg,
    double? heightCm,
    String? gender,
    List<String>? healthConditions,
    String? fitnessGoal,
    int? totalWorkouts,
    double? totalCalories,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      age: age ?? this.age,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      gender: gender ?? this.gender,
      healthConditions: healthConditions ?? this.healthConditions,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      totalWorkouts: totalWorkouts ?? this.totalWorkouts,
      totalCalories: totalCalories ?? this.totalCalories,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'age': age,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'gender': gender,
        'healthConditions': healthConditions,
        'fitnessGoal': fitnessGoal,
        'totalWorkouts': totalWorkouts,
        'totalCalories': totalCalories,
      };

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        uid: j['uid'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        photoUrl: j['photoUrl'] as String?,
        age: (j['age'] as num).toInt(),
        weightKg: (j['weightKg'] as num).toDouble(),
        heightCm: (j['heightCm'] as num).toDouble(),
        gender: j['gender'] as String? ?? 'Male',
        healthConditions: List<String>.from(j['healthConditions'] ?? []),
        fitnessGoal: j['fitnessGoal'] as String? ?? 'General Fitness',
        totalWorkouts: (j['totalWorkouts'] as num?)?.toInt() ?? 0,
        totalCalories: (j['totalCalories'] as num?)?.toDouble() ?? 0,
      );
}
