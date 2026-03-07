enum ExperienceMode { preview, linked }

class UserAccount {
  const UserAccount({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.mode,
    required this.emailVerified,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final ExperienceMode mode;
  final bool emailVerified;

  String get displayName {
    final combined = '$firstName $lastName'.trim();
    return combined.isEmpty ? email : combined;
  }

  UserAccount copyWith({
    String? userId,
    String? firstName,
    String? lastName,
    String? email,
    ExperienceMode? mode,
    bool? emailVerified,
  }) {
    return UserAccount(
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      mode: mode ?? this.mode,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'mode': mode.name,
      'emailVerified': emailVerified,
    };
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      userId: json['userId'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mode: ExperienceMode.values.byName(
        json['mode'] as String? ?? ExperienceMode.preview.name,
      ),
      emailVerified: json['emailVerified'] as bool? ?? false,
    );
  }
}

class GoalPlan {
  const GoalPlan({
    this.goalId,
    required this.goal,
    required this.morningLockMinutes,
    required this.focusWindowHours,
    required this.createdAt,
    required this.armed,
    required this.importedFromRocketGoals,
  });

  final String? goalId;
  final String goal;
  final int morningLockMinutes;
  final int focusWindowHours;
  final DateTime createdAt;
  final bool armed;
  final bool importedFromRocketGoals;

  int get reflectionLockMinutes =>
      (morningLockMinutes + (focusWindowHours * 60)) % (24 * 60);

  GoalPlan copyWith({
    String? goalId,
    String? goal,
    int? morningLockMinutes,
    int? focusWindowHours,
    DateTime? createdAt,
    bool? armed,
    bool? importedFromRocketGoals,
  }) {
    return GoalPlan(
      goalId: goalId ?? this.goalId,
      goal: goal ?? this.goal,
      morningLockMinutes: morningLockMinutes ?? this.morningLockMinutes,
      focusWindowHours: focusWindowHours ?? this.focusWindowHours,
      createdAt: createdAt ?? this.createdAt,
      armed: armed ?? this.armed,
      importedFromRocketGoals:
          importedFromRocketGoals ?? this.importedFromRocketGoals,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'goalId': goalId,
      'goal': goal,
      'morningLockMinutes': morningLockMinutes,
      'focusWindowHours': focusWindowHours,
      'createdAt': createdAt.toIso8601String(),
      'armed': armed,
      'importedFromRocketGoals': importedFromRocketGoals,
    };
  }

  factory GoalPlan.fromJson(Map<String, dynamic> json) {
    return GoalPlan(
      goalId: json['goalId'] as String?,
      goal: json['goal'] as String? ?? '',
      morningLockMinutes: json['morningLockMinutes'] as int? ?? 390,
      focusWindowHours: json['focusWindowHours'] as int? ?? 14,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      armed: json['armed'] as bool? ?? false,
      importedFromRocketGoals:
          json['importedFromRocketGoals'] as bool? ?? false,
    );
  }
}

class DailyCommitment {
  const DailyCommitment({
    required this.dateKey,
    required this.oneThing,
    required this.committedAt,
    required this.didComplete,
    required this.reflectedAt,
  });

  final String dateKey;
  final String oneThing;
  final DateTime committedAt;
  final bool? didComplete;
  final DateTime? reflectedAt;

  bool get isResolved => didComplete != null;

  DailyCommitment copyWith({
    String? dateKey,
    String? oneThing,
    DateTime? committedAt,
    Object? didComplete = _unset,
    Object? reflectedAt = _unset,
  }) {
    return DailyCommitment(
      dateKey: dateKey ?? this.dateKey,
      oneThing: oneThing ?? this.oneThing,
      committedAt: committedAt ?? this.committedAt,
      didComplete: identical(didComplete, _unset)
          ? this.didComplete
          : didComplete as bool?,
      reflectedAt: identical(reflectedAt, _unset)
          ? this.reflectedAt
          : reflectedAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateKey': dateKey,
      'oneThing': oneThing,
      'committedAt': committedAt.toIso8601String(),
      'didComplete': didComplete,
      'reflectedAt': reflectedAt?.toIso8601String(),
    };
  }

  factory DailyCommitment.fromJson(Map<String, dynamic> json) {
    return DailyCommitment(
      dateKey: json['dateKey'] as String? ?? '',
      oneThing: json['oneThing'] as String? ?? '',
      committedAt:
          DateTime.tryParse(json['committedAt'] as String? ?? '') ??
              DateTime.now(),
      didComplete: json['didComplete'] as bool?,
      reflectedAt: DateTime.tryParse(json['reflectedAt'] as String? ?? ''),
    );
  }
}

class GoalLockSnapshot {
  const GoalLockSnapshot({
    required this.account,
    required this.goalPlan,
    required this.commitments,
  });

  final UserAccount? account;
  final GoalPlan? goalPlan;
  final List<DailyCommitment> commitments;

  Map<String, dynamic> toJson() {
    return {
      'account': account?.toJson(),
      'goalPlan': goalPlan?.toJson(),
      'commitments': commitments.map((entry) => entry.toJson()).toList(),
    };
  }

  factory GoalLockSnapshot.fromJson(Map<String, dynamic> json) {
    final commitmentJson = (json['commitments'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return GoalLockSnapshot(
      account: json['account'] == null
          ? null
          : UserAccount.fromJson(
              (json['account'] as Map<dynamic, dynamic>)
                  .cast<String, dynamic>(),
            ),
      goalPlan: json['goalPlan'] == null
          ? null
          : GoalPlan.fromJson(
              (json['goalPlan'] as Map<dynamic, dynamic>)
                  .cast<String, dynamic>(),
            ),
      commitments:
          commitmentJson.map(DailyCommitment.fromJson).toList(growable: false),
    );
  }
}

const Object _unset = Object();

String dateKeyFromDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime dateFromKey(String key) {
  final pieces = key.split('-');
  if (pieces.length != 3) {
    return DateTime.now();
  }
  return DateTime(
    int.tryParse(pieces[0]) ?? 0,
    int.tryParse(pieces[1]) ?? 1,
    int.tryParse(pieces[2]) ?? 1,
  );
}

DateTime dateAtMinutes(DateTime date, int minutes) {
  return DateTime(date.year, date.month, date.day)
      .add(Duration(minutes: minutes));
}

