enum ExperienceMode { preview, linked }

class UserAccount {
  const UserAccount({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.mode,
    required this.emailVerified,
    this.isAdmin = false,
    this.goalLockAccessGranted = false,
    this.goalLockSubscriptionStatus,
    this.goalLockSubscriptionExpiresAt,
    this.goalLockSubscriptionCancelAt,
    this.goalLockIntroOfferUsed = false,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final ExperienceMode mode;
  final bool emailVerified;
  final bool isAdmin;
  final bool goalLockAccessGranted;
  final String? goalLockSubscriptionStatus;
  final DateTime? goalLockSubscriptionExpiresAt;
  final DateTime? goalLockSubscriptionCancelAt;
  final bool goalLockIntroOfferUsed;

  String get displayName {
    final combined = '$firstName $lastName'.trim();
    return combined.isEmpty ? email : combined;
  }

  bool get hasGoalLockAccess {
    if (mode == ExperienceMode.preview) {
      return true;
    }
    if (isAdmin || goalLockAccessGranted) {
      return true;
    }

    final normalizedStatus = goalLockSubscriptionStatus?.trim().toLowerCase();
    if (normalizedStatus == 'active' ||
        normalizedStatus == 'trialing' ||
        normalizedStatus == 'canceling') {
      return true;
    }

    final expiresAt = goalLockSubscriptionExpiresAt;
    if (expiresAt != null && expiresAt.isAfter(DateTime.now())) {
      return true;
    }

    return false;
  }

  UserAccount copyWith({
    String? userId,
    String? firstName,
    String? lastName,
    String? email,
    ExperienceMode? mode,
    bool? emailVerified,
    bool? isAdmin,
    bool? goalLockAccessGranted,
    Object? goalLockSubscriptionStatus = _unset,
    Object? goalLockSubscriptionExpiresAt = _unset,
    Object? goalLockSubscriptionCancelAt = _unset,
    bool? goalLockIntroOfferUsed,
  }) {
    return UserAccount(
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      mode: mode ?? this.mode,
      emailVerified: emailVerified ?? this.emailVerified,
      isAdmin: isAdmin ?? this.isAdmin,
      goalLockAccessGranted:
          goalLockAccessGranted ?? this.goalLockAccessGranted,
      goalLockSubscriptionStatus: identical(goalLockSubscriptionStatus, _unset)
          ? this.goalLockSubscriptionStatus
          : goalLockSubscriptionStatus as String?,
      goalLockSubscriptionExpiresAt:
          identical(goalLockSubscriptionExpiresAt, _unset)
          ? this.goalLockSubscriptionExpiresAt
          : goalLockSubscriptionExpiresAt as DateTime?,
      goalLockSubscriptionCancelAt:
          identical(goalLockSubscriptionCancelAt, _unset)
          ? this.goalLockSubscriptionCancelAt
          : goalLockSubscriptionCancelAt as DateTime?,
      goalLockIntroOfferUsed:
          goalLockIntroOfferUsed ?? this.goalLockIntroOfferUsed,
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
      'isAdmin': isAdmin,
      'goalLockAccessGranted': goalLockAccessGranted,
      'goalLockSubscriptionStatus': goalLockSubscriptionStatus,
      'goalLockSubscriptionExpiresAt': goalLockSubscriptionExpiresAt
          ?.toIso8601String(),
      'goalLockSubscriptionCancelAt': goalLockSubscriptionCancelAt
          ?.toIso8601String(),
      'goalLockIntroOfferUsed': goalLockIntroOfferUsed,
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
      isAdmin: json['isAdmin'] as bool? ?? false,
      goalLockAccessGranted: json['goalLockAccessGranted'] as bool? ?? false,
      goalLockSubscriptionStatus: json['goalLockSubscriptionStatus'] as String?,
      goalLockSubscriptionExpiresAt: _coerceDateTime(
        json['goalLockSubscriptionExpiresAt'],
      ),
      goalLockSubscriptionCancelAt: _coerceDateTime(
        json['goalLockSubscriptionCancelAt'],
      ),
      goalLockIntroOfferUsed: json['goalLockIntroOfferUsed'] as bool? ?? false,
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
      morningLockMinutes: normalizeMinutesOfDay(
        _coerceInt(json['morningLockMinutes']) ?? 390,
      ),
      focusWindowHours: clampFocusWindowHours(
        _coerceInt(json['focusWindowHours']) ?? 14,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
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
    required this.middayOnTrack,
    required this.middayCheckedAt,
    required this.didComplete,
    required this.reflectedAt,
  });

  final String dateKey;
  final String oneThing;
  final DateTime committedAt;
  final bool? middayOnTrack;
  final DateTime? middayCheckedAt;
  final bool? didComplete;
  final DateTime? reflectedAt;

  bool get isResolved => didComplete != null;

  DailyCommitment copyWith({
    String? dateKey,
    String? oneThing,
    DateTime? committedAt,
    Object? middayOnTrack = _unset,
    Object? middayCheckedAt = _unset,
    Object? didComplete = _unset,
    Object? reflectedAt = _unset,
  }) {
    return DailyCommitment(
      dateKey: dateKey ?? this.dateKey,
      oneThing: oneThing ?? this.oneThing,
      committedAt: committedAt ?? this.committedAt,
      middayOnTrack: identical(middayOnTrack, _unset)
          ? this.middayOnTrack
          : middayOnTrack as bool?,
      middayCheckedAt: identical(middayCheckedAt, _unset)
          ? this.middayCheckedAt
          : middayCheckedAt as DateTime?,
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
      'middayOnTrack': middayOnTrack,
      'middayCheckedAt': middayCheckedAt?.toIso8601String(),
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
      middayOnTrack: json['middayOnTrack'] as bool?,
      middayCheckedAt: DateTime.tryParse(
        json['middayCheckedAt'] as String? ?? '',
      ),
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
    this.isDarkMode = false,
  });

  final UserAccount? account;
  final GoalPlan? goalPlan;
  final List<DailyCommitment> commitments;
  final bool isDarkMode;

  Map<String, dynamic> toJson() {
    return {
      'account': account?.toJson(),
      'goalPlan': goalPlan?.toJson(),
      'commitments': commitments.map((entry) => entry.toJson()).toList(),
      'isDarkMode': isDarkMode,
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
      commitments: commitmentJson
          .map(DailyCommitment.fromJson)
          .toList(growable: false),
      isDarkMode: json['isDarkMode'] as bool? ?? false,
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
  return DateTime(
    date.year,
    date.month,
    date.day,
  ).add(Duration(minutes: minutes));
}

int normalizeMinutesOfDay(int minutes) {
  return ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60);
}

int clampFocusWindowHours(int hours) {
  return hours.clamp(8, 16);
}

int? _coerceInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

DateTime? _coerceDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
