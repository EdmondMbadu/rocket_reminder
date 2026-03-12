import 'models.dart';
import 'rocket_goals_bridge_base.dart';

class _UnavailableBridge implements RocketGoalsBridge {
  const _UnavailableBridge();

  @override
  Future<void> sendPasswordReset(String email) async {
    throw const BridgeException(
      'Linked account flows are available on mobile and desktop builds. Use Preview on web.',
    );
  }

  @override
  Future<LinkedAccountBundle> refreshAccount({
    required RemoteCredentials credentials,
  }) async {
    throw const BridgeException(
      'Linked account flows are available on mobile and desktop builds. Use Preview on web.',
    );
  }

  @override
  Future<Uri> createGoalLockCheckoutSession({
    required RemoteCredentials credentials,
  }) async {
    throw const BridgeException(
      'Billing is available on mobile and desktop builds. Use a native build to subscribe.',
    );
  }

  @override
  Future<Uri> createGoalLockBillingPortalSession({
    required RemoteCredentials credentials,
  }) async {
    throw const BridgeException(
      'Billing is available on mobile and desktop builds. Use a native build to manage your subscription.',
    );
  }

  @override
  Future<LinkedAccountBundle> signIn({
    required String email,
    required String password,
  }) async {
    throw const BridgeException(
      'Linked account flows are available on mobile and desktop builds. Use Preview on web.',
    );
  }

  @override
  Future<LinkedAccountBundle> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    throw const BridgeException(
      'Linked account flows are available on mobile and desktop builds. Use Preview on web.',
    );
  }

  @override
  Future<GoalPlan> upsertGoalPlan({
    required UserAccount account,
    required GoalPlan plan,
    required RemoteCredentials credentials,
    DailyCommitment? latestCommitment,
    List<DailyCommitment> commitments = const [],
  }) async {
    return plan;
  }
}

RocketGoalsBridge createPlatformBridge() => const _UnavailableBridge();
