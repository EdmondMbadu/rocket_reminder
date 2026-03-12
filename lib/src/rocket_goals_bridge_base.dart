import 'models.dart';

class RemoteCredentials {
  const RemoteCredentials({
    required this.userId,
    required this.idToken,
    required this.refreshToken,
    required this.email,
  });

  final String userId;
  final String idToken;
  final String refreshToken;
  final String email;
}

class LinkedAccountBundle {
  const LinkedAccountBundle({
    required this.account,
    required this.credentials,
    required this.importedGoal,
    required this.importedCommitments,
    required this.notice,
  });

  final UserAccount account;
  final RemoteCredentials credentials;
  final GoalPlan? importedGoal;
  final List<DailyCommitment> importedCommitments;
  final String? notice;
}

class BridgeException implements Exception {
  const BridgeException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class RocketGoalsBridge {
  Future<LinkedAccountBundle> signIn({
    required String email,
    required String password,
  });

  Future<LinkedAccountBundle> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset(String email);

  Future<LinkedAccountBundle> refreshAccount({
    required RemoteCredentials credentials,
  });

  Future<Uri> createGoalLockCheckoutSession({
    required RemoteCredentials credentials,
  });

  Future<Uri> createGoalLockBillingPortalSession({
    required RemoteCredentials credentials,
  });

  Future<GoalPlan> upsertGoalPlan({
    required UserAccount account,
    required GoalPlan plan,
    required RemoteCredentials credentials,
    DailyCommitment? latestCommitment,
    List<DailyCommitment> commitments = const [],
  });
}
