import 'dart:async';

import 'package:flutter/foundation.dart';

import 'local_cache.dart';
import 'local_cache_base.dart';
import 'models.dart';
import 'rocket_goals_bridge.dart';
import 'rocket_goals_bridge_base.dart';

enum AuthMode { signIn, signUp }

enum AppTab { today, history, settings }

enum LockPhase {
  loading,
  auth,
  billing,
  onboarding,
  unlocked,
  morningLocked,
  noonLocked,
  eveningLocked,
}

class GoalLockController extends ChangeNotifier {
  GoalLockController({
    LocalCache? cache,
    RocketGoalsBridge? bridge,
    DateTime Function()? now,
  }) : _cache = cache ?? createLocalCache(),
       _bridge = bridge ?? createRocketGoalsBridge(),
       _now = now ?? DateTime.now;

  final LocalCache _cache;
  final RocketGoalsBridge _bridge;
  final DateTime Function() _now;
  static const int middayCheckMinutes = 12 * 60;

  Timer? _ticker;
  RemoteCredentials? _remoteCredentials;

  bool _isReady = false;
  bool _isBusy = false;
  bool _isDarkMode = false;
  bool _holdOnboarding = false;
  AuthMode _authMode = AuthMode.signIn;
  AppTab _currentTab = AppTab.today;
  String? _errorMessage;
  String? _noticeMessage;
  UserAccount? _account;
  GoalPlan? _goalPlan;
  List<DailyCommitment> _commitments = const [];

  bool get isReady => _isReady;
  bool get isBusy => _isBusy;
  bool get isDarkMode => _isDarkMode;
  bool get holdOnboarding => _holdOnboarding;
  AuthMode get authMode => _authMode;
  AppTab get currentTab => _currentTab;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  UserAccount? get account => _account;
  GoalPlan? get goalPlan => _goalPlan;
  List<DailyCommitment> get commitments =>
      List<DailyCommitment>.unmodifiable(_sortedCommitmentsDesc());
  bool get hasLinkedSync => _remoteCredentials != null;
  bool get reconnectNeeded =>
      _account?.mode == ExperienceMode.linked && _remoteCredentials == null;
  bool get requiresBilling =>
      _account?.mode == ExperienceMode.linked &&
      !(_account?.hasGoalLockAccess ?? false);
  bool get isAdminUser => _account?.isAdmin ?? false;
  bool get canManageBilling =>
      _account?.mode == ExperienceMode.linked &&
      !isAdminUser &&
      ((_account?.goalLockSubscriptionStatus?.isNotEmpty ?? false) ||
          (_account?.goalLockAccessGranted ?? false));

  String get goalLabel => _goalPlan?.goal ?? '';

  String get greetingName => _account?.firstName.trim().isNotEmpty == true
      ? _account!.firstName.trim()
      : 'there';

  LockPhase get lockPhase {
    if (!_isReady) {
      return LockPhase.loading;
    }
    if (_account == null || _holdOnboarding) {
      return LockPhase.auth;
    }
    if (requiresBilling) {
      return LockPhase.billing;
    }
    if (_goalPlan == null || !_goalPlan!.armed) {
      return LockPhase.onboarding;
    }
    if (pendingReflection != null) {
      return LockPhase.eveningLocked;
    }
    if (pendingMiddayCheck != null) {
      return LockPhase.noonLocked;
    }
    if (_shouldShowMorningLock()) {
      return LockPhase.morningLocked;
    }
    return LockPhase.unlocked;
  }

  DailyCommitment? get todayCommitment =>
      _commitmentForDate(dateKeyFromDate(_now()));

  DailyCommitment? get pendingReflection {
    final plan = _goalPlan;
    if (plan == null) {
      return null;
    }
    for (final entry in _sortedCommitmentsDesc()) {
      if (entry.didComplete != null) {
        continue;
      }
      final dueAt = dateAtMinutes(
        dateFromKey(entry.dateKey),
        plan.reflectionLockMinutes,
      );
      if (!_now().isBefore(dueAt)) {
        return entry;
      }
    }
    return null;
  }

  DailyCommitment? get pendingMiddayCheck {
    final plan = _goalPlan;
    final entry = todayCommitment;
    if (plan == null || entry == null) {
      return null;
    }
    if (!_shouldRequireMiddayCheck(entry, plan, _now())) {
      return null;
    }
    return entry;
  }

  int get currentStreak {
    final resolved = _sortedCommitmentsDesc()
        .where((entry) => entry.didComplete != null)
        .toList(growable: false);
    if (resolved.isEmpty) {
      return 0;
    }

    var streak = 0;
    DateTime? expectedDate;
    for (final entry in resolved) {
      final entryDate = dateFromKey(entry.dateKey);
      if (expectedDate != null) {
        final difference = expectedDate.difference(entryDate).inDays;
        if (difference != 1) {
          break;
        }
      }
      if (entry.didComplete == true) {
        streak += 1;
        expectedDate = entryDate;
        continue;
      }
      break;
    }
    return streak;
  }

  double get followThroughRate {
    final reflected = _commitments
        .where((entry) => entry.didComplete != null)
        .toList();
    if (reflected.isEmpty) {
      return 0;
    }
    final yesCount = reflected
        .where((entry) => entry.didComplete == true)
        .length;
    return yesCount / reflected.length;
  }

  Future<void> initialize() async {
    final raw = await _cache.readJson();
    if (raw != null) {
      final snapshot = GoalLockSnapshot.fromJson(raw);
      _account = snapshot.account;
      _goalPlan = snapshot.goalPlan;
      _commitments = snapshot.commitments;
      _isDarkMode = snapshot.isDarkMode;
      if (reconnectNeeded) {
        _noticeMessage =
            'Local progress restored. Log back into Rocket Goals to resume cloud sync.';
      }
    }
    _isReady = true;
    _startTicker();
    notifyListeners();
  }

  void refreshLockState() {
    if (!_isReady) {
      return;
    }
    if (_account?.mode == ExperienceMode.linked && _remoteCredentials != null) {
      unawaited(refreshLinkedAccount(silent: true));
    }
    notifyListeners();
  }

  void setAuthMode(AuthMode mode) {
    _authMode = mode;
    _clearMessages(notify: true);
  }

  void dismissBanner() {
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
  }

  void selectTab(AppTab tab) {
    _currentTab = tab;
    notifyListeners();
  }

  void setHoldOnboarding(bool value) {
    _holdOnboarding = value;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    _persist();
  }

  Future<void> continueInPreview() async {
    _setBusy(true);
    _clearMessages();
    _account = const UserAccount(
      userId: 'preview-user',
      firstName: 'Ava',
      lastName: 'Jordan',
      email: 'ava@preview.rocket',
      mode: ExperienceMode.preview,
      emailVerified: true,
    );
    _goalPlan = null;
    _remoteCredentials = null;
    _commitments = const [];
    _noticeMessage =
        'Preview mode is live. Link your Rocket Goals account anytime.';
    await _persist();
    _setBusy(false);
  }

  Future<void> signIn({required String email, required String password}) async {
    await _runBridgeAction(() async {
      final bundle = await _bridge.signIn(email: email, password: password);
      _account = bundle.account;
      _goalPlan = bundle.importedGoal;
      _commitments = bundle.importedCommitments;
      _remoteCredentials = bundle.credentials;
      _noticeMessage = bundle.notice;
      await _persist();
    });
  }

  Future<void> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    await _runBridgeAction(() async {
      final bundle = await _bridge.signUp(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
      );
      _account = bundle.account;
      _goalPlan = bundle.importedGoal;
      _commitments = bundle.importedCommitments;
      _remoteCredentials = bundle.credentials;
      _noticeMessage = bundle.notice;
      await _persist();
    });
  }

  Future<void> requestPasswordReset(String email) async {
    await _runBridgeAction(() async {
      await _bridge.sendPasswordReset(email.trim());
      _noticeMessage =
          'Password reset link sent. Check the inbox for your Rocket Goals account.';
    });
  }

  Future<void> refreshLinkedAccount({bool silent = false}) async {
    if (_account?.mode != ExperienceMode.linked || _remoteCredentials == null) {
      return;
    }

    if (!silent) {
      _setBusy(true);
      _clearMessages();
    }

    try {
      final bundle = await _bridge.refreshAccount(
        credentials: _remoteCredentials!,
      );
      _account = bundle.account;
      _goalPlan = bundle.importedGoal ?? _goalPlan;
      _commitments = bundle.importedCommitments;
      if (!silent) {
        _noticeMessage = bundle.notice;
      }
      await _persist();
      notifyListeners();
    } on BridgeException catch (error) {
      if (!silent) {
        _errorMessage = error.message;
      }
    } catch (_) {
      if (!silent) {
        _errorMessage =
            'We could not refresh your billing status right now. Try again in a moment.';
      }
    } finally {
      if (!silent) {
        _setBusy(false);
      }
    }
  }

  Future<Uri?> startCheckout() async {
    if (_remoteCredentials == null) {
      _errorMessage = 'Sign in again to start checkout.';
      notifyListeners();
      return null;
    }

    Uri? checkoutUri;
    await _runBridgeAction(() async {
      checkoutUri = await _bridge.createGoalLockCheckoutSession(
        credentials: _remoteCredentials!,
      );
      _noticeMessage =
          'Checkout opened in your browser. Return here after payment and we will refresh access.';
    });
    return checkoutUri;
  }

  Future<Uri?> openBillingPortal() async {
    if (_remoteCredentials == null) {
      _errorMessage = 'Sign in again to manage billing.';
      notifyListeners();
      return null;
    }

    Uri? billingUri;
    await _runBridgeAction(() async {
      billingUri = await _bridge.createGoalLockBillingPortalSession(
        credentials: _remoteCredentials!,
      );
      _noticeMessage = 'Billing portal opened in your browser.';
    });
    return billingUri;
  }

  Future<void> armGoalLock({
    required String goal,
    required int morningLockMinutes,
    required int focusWindowHours,
  }) async {
    if (_account == null) {
      return;
    }
    final trimmedGoal = goal.trim();
    if (trimmedGoal.isEmpty) {
      _errorMessage = 'Name the one goal this ritual is protecting.';
      notifyListeners();
      return;
    }

    _setBusy(true);
    _clearMessages();

    var draft = GoalPlan(
      goalId: _goalPlan?.goalId,
      goal: trimmedGoal,
      morningLockMinutes: morningLockMinutes,
      focusWindowHours: focusWindowHours,
      createdAt: _goalPlan?.createdAt ?? _now(),
      armed: true,
      importedFromRocketGoals: _goalPlan?.importedFromRocketGoals ?? false,
    );

    if (_account!.mode == ExperienceMode.linked && _remoteCredentials != null) {
      try {
        draft = await _bridge.upsertGoalPlan(
          account: _account!,
          plan: draft,
          credentials: _remoteCredentials!,
          latestCommitment: todayCommitment,
          commitments: _sortedCommitmentsDesc(),
        );
        _noticeMessage = draft.importedFromRocketGoals
            ? 'Goal Lock armed and synced back to Rocket Goals.'
            : 'Goal Lock armed.';
      } on BridgeException catch (error) {
        _noticeMessage = error.message;
      } catch (error, stackTrace) {
        debugPrint('Goal Lock sync failed while arming: $error');
        debugPrintStack(stackTrace: stackTrace);
        _noticeMessage =
            'Goal Lock armed locally. Rocket Goals sync hit an unexpected error.';
      }
    } else {
      _noticeMessage = 'Goal Lock armed. Your phone ritual starts tomorrow.';
    }

    _goalPlan = draft;
    if (_account!.mode == ExperienceMode.preview && _commitments.isEmpty) {
      _commitments = _seedPreviewMomentum(draft);
    }
    await _persist();
    _setBusy(false);
  }

  Future<void> submitMorningOneThing(String answer) async {
    final trimmed = answer.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Give the day one concrete move.';
      notifyListeners();
      return;
    }

    final key = dateKeyFromDate(_now());
    final existingIndex = _commitments.indexWhere(
      (entry) => entry.dateKey == key,
    );
    final updatedEntry = DailyCommitment(
      dateKey: key,
      oneThing: trimmed,
      committedAt: _now(),
      middayOnTrack: existingIndex == -1
          ? null
          : _commitments[existingIndex].middayOnTrack,
      middayCheckedAt: existingIndex == -1
          ? null
          : _commitments[existingIndex].middayCheckedAt,
      didComplete: existingIndex == -1
          ? null
          : _commitments[existingIndex].didComplete,
      reflectedAt: existingIndex == -1
          ? null
          : _commitments[existingIndex].reflectedAt,
    );

    if (existingIndex == -1) {
      _commitments = [..._commitments, updatedEntry];
    } else {
      final next = [..._commitments];
      next[existingIndex] = updatedEntry;
      _commitments = next;
    }

    _noticeMessage = 'Unlocked. Protect that one thing before the day drifts.';
    _errorMessage = null;
    await _saveLocallyThenSyncRemotely();
  }

  Future<void> submitMiddayCheck(bool onTrack) async {
    final entry = pendingMiddayCheck;
    if (entry == null) {
      return;
    }

    final index = _commitments.indexWhere(
      (item) => item.dateKey == entry.dateKey,
    );
    if (index == -1) {
      return;
    }

    final next = [..._commitments];
    next[index] = entry.copyWith(
      middayOnTrack: onTrack,
      middayCheckedAt: _now(),
    );
    _commitments = next;
    _noticeMessage = onTrack
        ? 'You are still on it. Finish the day strong.'
        : 'Noted. Reset the next block and get back to the one thing.';
    _errorMessage = null;
    await _saveLocallyThenSyncRemotely();
  }

  Future<void> submitEveningReflection(bool didComplete) async {
    final reflectionTarget = pendingReflection;
    if (reflectionTarget == null) {
      return;
    }

    final index = _commitments.indexWhere(
      (entry) => entry.dateKey == reflectionTarget.dateKey,
    );
    if (index == -1) {
      return;
    }

    final next = [..._commitments];
    next[index] = reflectionTarget.copyWith(
      didComplete: didComplete,
      reflectedAt: _now(),
    );
    _commitments = next;
    _noticeMessage = didComplete
        ? 'Locked in. That counts.'
        : 'Honest answer recorded. Tomorrow starts fresh.';
    _errorMessage = null;
    await _saveLocallyThenSyncRemotely();
  }

  Future<void> updateSchedule({
    required int morningLockMinutes,
    required int focusWindowHours,
  }) async {
    if (_goalPlan == null) {
      return;
    }
    _goalPlan = _goalPlan!.copyWith(
      morningLockMinutes: morningLockMinutes,
      focusWindowHours: focusWindowHours,
      armed: true,
    );
    _noticeMessage = 'Schedule updated.';
    await _saveLocallyThenSyncRemotely();
  }

  Future<void> updateGoal(String goal) async {
    if (_goalPlan == null) {
      return;
    }

    final trimmedGoal = goal.trim();
    if (trimmedGoal.isEmpty) {
      _errorMessage = 'Keep one clear goal here.';
      notifyListeners();
      return;
    }

    _setBusy(true);
    _clearMessages();
    _goalPlan = _goalPlan!.copyWith(goal: trimmedGoal, armed: true);
    _noticeMessage = 'Goal updated.';
    await _persist();
    _setBusy(false);
    unawaited(_syncLatestInBackground());
  }

  Future<void> signOut() async {
    _ticker?.cancel();
    _remoteCredentials = null;
    _account = null;
    _goalPlan = null;
    _commitments = const [];
    _authMode = AuthMode.signIn;
    _currentTab = AppTab.today;
    _errorMessage = null;
    _noticeMessage = null;
    _isReady = true;
    await _cache.clear();
    _startTicker();
    notifyListeners();
  }

  String nextLockSummary() {
    final plan = _goalPlan;
    if (plan == null) {
      return 'No lock scheduled yet.';
    }
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final morningAt = dateAtMinutes(today, plan.morningLockMinutes);
    final noonAt = dateAtMinutes(today, middayCheckMinutes);
    final reflectionAt = dateAtMinutes(today, plan.reflectionLockMinutes);
    final todaysEntry = todayCommitment;

    if (pendingReflection != null) {
      return 'Reflection is due now.';
    }
    if (pendingMiddayCheck != null) {
      return 'Noon check-in is due now.';
    }
    if (todaysEntry == null && now.isBefore(morningAt)) {
      return 'Morning lock at ${formatMinutes(plan.morningLockMinutes)}.';
    }
    if (_hasUpcomingMiddayCheck(todaysEntry, plan, now)) {
      return 'Noon check-in at ${formatMinutes(noonAt.hour * 60 + noonAt.minute)}.';
    }
    if (todaysEntry != null &&
        todaysEntry.didComplete == null &&
        now.isBefore(reflectionAt)) {
      return 'Reflection lock at ${formatMinutes(plan.reflectionLockMinutes)}.';
    }
    return 'Tomorrow at ${formatMinutes(plan.morningLockMinutes)}.';
  }

  List<DailyCommitment> recentEntries({int count = 7}) {
    final entries = _sortedCommitmentsDesc();
    return entries.take(count).toList(growable: false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _syncLatest() async {
    if (_account == null || _goalPlan == null || _remoteCredentials == null) {
      return;
    }

    try {
      _goalPlan = await _bridge.upsertGoalPlan(
        account: _account!,
        plan: _goalPlan!,
        credentials: _remoteCredentials!,
        latestCommitment: _sortedCommitmentsDesc().isEmpty
            ? null
            : _sortedCommitmentsDesc().first,
        commitments: _sortedCommitmentsDesc(),
      );
    } on BridgeException catch (error) {
      _noticeMessage = error.message;
    } catch (error, stackTrace) {
      debugPrint('Goal Lock sync failed during background update: $error');
      debugPrintStack(stackTrace: stackTrace);
      _noticeMessage =
          'Saved locally. Rocket Goals sync hit an unexpected error.';
    }
  }

  Future<void> _saveLocallyThenSyncRemotely() async {
    await _persist();
    notifyListeners();
    unawaited(_syncLatestInBackground());
  }

  Future<void> _syncLatestInBackground() async {
    await _syncLatest();
    await _persist();
    if (hasListeners) {
      notifyListeners();
    }
  }

  List<DailyCommitment> _seedPreviewMomentum(GoalPlan plan) {
    final today = DateTime(_now().year, _now().month, _now().day);
    return <DailyCommitment>[
      DailyCommitment(
        dateKey: dateKeyFromDate(today.subtract(const Duration(days: 1))),
        oneThing: 'Ship the landing page hero for ${plan.goal.toLowerCase()}',
        committedAt: today.subtract(const Duration(days: 1, hours: 11)),
        middayOnTrack: true,
        middayCheckedAt: today.subtract(const Duration(days: 1)),
        didComplete: true,
        reflectedAt: today.subtract(const Duration(days: 1, hours: 2)),
      ),
      DailyCommitment(
        dateKey: dateKeyFromDate(today.subtract(const Duration(days: 2))),
        oneThing: 'Draft the boldest version of the launch narrative',
        committedAt: today.subtract(const Duration(days: 2, hours: 11)),
        middayOnTrack: true,
        middayCheckedAt: today.subtract(const Duration(days: 2)),
        didComplete: true,
        reflectedAt: today.subtract(const Duration(days: 2, hours: 2)),
      ),
      DailyCommitment(
        dateKey: dateKeyFromDate(today.subtract(const Duration(days: 3))),
        oneThing: 'Ask one person for direct feedback on the offer',
        committedAt: today.subtract(const Duration(days: 3, hours: 10)),
        middayOnTrack: false,
        middayCheckedAt: today.subtract(const Duration(days: 3, hours: 3)),
        didComplete: false,
        reflectedAt: today.subtract(const Duration(days: 3, hours: 2)),
      ),
      DailyCommitment(
        dateKey: dateKeyFromDate(today.subtract(const Duration(days: 4))),
        oneThing: 'Write the first ugly draft before breakfast',
        committedAt: today.subtract(const Duration(days: 4, hours: 11)),
        middayOnTrack: true,
        middayCheckedAt: today.subtract(const Duration(days: 4)),
        didComplete: true,
        reflectedAt: today.subtract(const Duration(days: 4, hours: 2)),
      ),
    ];
  }

  DailyCommitment? _commitmentForDate(String key) {
    for (final entry in _commitments) {
      if (entry.dateKey == key) {
        return entry;
      }
    }
    return null;
  }

  bool _shouldShowMorningLock() {
    final plan = _goalPlan;
    if (plan == null) {
      return false;
    }
    final today = _now();
    final morningAt = dateAtMinutes(today, plan.morningLockMinutes);
    final todayEntry = _commitmentForDate(dateKeyFromDate(today));
    return !_now().isBefore(morningAt) && todayEntry == null;
  }

  bool _shouldRequireMiddayCheck(
    DailyCommitment entry,
    GoalPlan plan,
    DateTime now,
  ) {
    if (entry.middayOnTrack != null) {
      return false;
    }
    final today = DateTime(now.year, now.month, now.day);
    final noonAt = dateAtMinutes(today, middayCheckMinutes);
    final reflectionAt = dateAtMinutes(today, plan.reflectionLockMinutes);
    if (!entry.committedAt.isBefore(noonAt)) {
      return false;
    }
    if (now.isBefore(noonAt)) {
      return false;
    }
    if (!now.isBefore(reflectionAt)) {
      return false;
    }
    return true;
  }

  bool _hasUpcomingMiddayCheck(
    DailyCommitment? entry,
    GoalPlan plan,
    DateTime now,
  ) {
    if (entry == null || entry.middayOnTrack != null) {
      return false;
    }
    final today = DateTime(now.year, now.month, now.day);
    final noonAt = dateAtMinutes(today, middayCheckMinutes);
    final reflectionAt = dateAtMinutes(today, plan.reflectionLockMinutes);
    if (!entry.committedAt.isBefore(noonAt)) {
      return false;
    }
    if (!now.isBefore(noonAt)) {
      return false;
    }
    return noonAt.isBefore(reflectionAt);
  }

  Future<void> _runBridgeAction(Future<void> Function() action) async {
    _setBusy(true);
    _clearMessages();
    try {
      await action();
    } on BridgeException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage =
          'Something broke while linking to Rocket Goals. Preview mode is still available.';
    } finally {
      await _persist();
      _setBusy(false);
    }
  }

  void _setBusy(bool next) {
    _isBusy = next;
    notifyListeners();
  }

  Future<void> _persist() {
    return _cache.writeJson(
      GoalLockSnapshot(
        account: _account,
        goalPlan: _goalPlan,
        commitments: _commitments,
        isDarkMode: _isDarkMode,
      ).toJson(),
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  void _clearMessages({bool notify = false}) {
    _errorMessage = null;
    _noticeMessage = null;
    if (notify) {
      notifyListeners();
    }
  }

  List<DailyCommitment> _sortedCommitmentsDesc() {
    final sorted = [..._commitments];
    sorted.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return sorted;
  }
}

String formatMinutes(int minutes) {
  final normalized = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60);
  final hours = normalized ~/ 60;
  final mins = normalized % 60;
  final suffix = hours >= 12 ? 'PM' : 'AM';
  final twelveHour = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);
  final minuteText = mins.toString().padLeft(2, '0');
  return '$twelveHour:$minuteText $suffix';
}
