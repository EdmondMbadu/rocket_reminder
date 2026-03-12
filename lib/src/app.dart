import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'controller.dart';
import 'models.dart';

const _brandWhite = Color(0xFFF7F4EF);
const _brandMist = Color(0xFFD6D1CB);
const _brandSmoke = Color(0xFFA49D95);
const _brandRed = Color(0xFFDC2626);
const _brandRedDeep = Color(0xFF991B1B);
const _brandBlack = Color(0xFF070707);
const _brandBlackSoft = Color(0xFF101010);

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------

class GoalLockApp extends StatefulWidget {
  const GoalLockApp({super.key, required this.controller});

  final GoalLockController controller;

  @override
  State<GoalLockApp> createState() => _GoalLockAppState();
}

class _GoalLockAppState extends State<GoalLockApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    widget.controller.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    widget.controller.dispose();
    super.dispose();
  }

  late final WidgetsBindingObserver _lifecycleObserver =
      _GoalLockLifecycleObserver(widget.controller);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Goal Lock',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: widget.controller.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: GoalLockRoot(controller: widget.controller),
        );
      },
    );
  }
}

class _GoalLockLifecycleObserver extends WidgetsBindingObserver {
  _GoalLockLifecycleObserver(this.controller);

  final GoalLockController controller;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.refreshLockState();
    }
  }
}

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final bg = isDark ? _brandBlack : const Color(0xFFFAF8F5);
  final textPrimary = isDark ? _brandWhite : const Color(0xFF1A1816);
  final textSecondary = isDark ? _brandMist : const Color(0xFF8A8480);
  final overlay = isDark ? Colors.white : Colors.black;

  final scheme = ColorScheme.fromSeed(
    seedColor: _brandRed,
    brightness: brightness,
    primary: _brandRed,
    secondary: isDark ? _brandWhite : _brandBlack,
    surface: bg,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.6,
        height: 0.96,
      ),
      displayMedium: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
        height: 1,
      ),
      displaySmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
      headlineLarge: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(
        color: textSecondary,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        color: textSecondary,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
      bodySmall: TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
      labelLarge: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: overlay.withValues(alpha: isDark ? 0.06 : 0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: overlay.withValues(alpha: 0.10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: overlay.withValues(alpha: 0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: _brandRed, width: 1.5),
      ),
      hintStyle: TextStyle(color: overlay.withValues(alpha: 0.32)),
      labelStyle: TextStyle(
        color: overlay.withValues(alpha: isDark ? 0.75 : 0.55),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _brandRed,
        foregroundColor: _brandWhite,
        elevation: 0,
        minimumSize: const Size.fromHeight(58),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: BorderSide(
          color: overlay.withValues(alpha: isDark ? 0.18 : 0.15),
        ),
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: overlay.withValues(alpha: isDark ? 0.08 : 0.05),
      labelStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      side: BorderSide(color: overlay.withValues(alpha: isDark ? 0.10 : 0.08)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Root
// ---------------------------------------------------------------------------

class GoalLockRoot extends StatelessWidget {
  const GoalLockRoot({super.key, required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final phase = controller.lockPhase;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const <Color>[_brandBlack, Color(0xFF160708), _brandBlackSoft]
                : const <Color>[
                    Color(0xFFFCFAF7),
                    Color(0xFFF7F3EE),
                    Color(0xFFFAF8F5),
                  ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: _AmbientGlow(dark: dark)),
            SafeArea(
              child: KeyedSubtree(
                key: ValueKey(phase),
                child: switch (phase) {
                  LockPhase.loading => const _LoadingView(),
                  LockPhase.auth => _AuthView(controller: controller),
                  LockPhase.billing => _BillingView(controller: controller),
                  LockPhase.onboarding => _OnboardingView(
                    controller: controller,
                  ),
                  _ => _ActiveView(controller: controller),
                },
              ),
            ),
            if (phase == LockPhase.morningLocked)
              _MorningLockOverlay(controller: controller),
            if (phase == LockPhase.noonLocked)
              _MiddayCheckOverlay(controller: controller),
            if (phase == LockPhase.eveningLocked)
              _EveningReflectionOverlay(controller: controller),
            if (controller.errorMessage != null ||
                controller.noticeMessage != null)
              Positioned(
                top: 18,
                left: 18,
                right: 18,
                child: _BannerToast(controller: controller),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _RocketBadge(size: 72),
          const SizedBox(height: 28),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: _isDark(context) ? _brandMist : _brandSmoke,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

class _AuthView extends StatefulWidget {
  const _AuthView({required this.controller});

  final GoalLockController controller;

  @override
  State<_AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<_AuthView> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final onBg = dark ? Colors.white : Colors.black;
    final isSignUp = widget.controller.authMode == AuthMode.signUp;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _GlassPanel(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _RocketBadge(size: 56),
                const SizedBox(height: 16),
                Text(
                  'Goal Lock',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'You tell us your goal, we make sure you do it!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                _ModeSwitch(
                  authMode: widget.controller.authMode,
                  onChanged: widget.controller.setAuthMode,
                ),
                const SizedBox(height: 24),
                if (isSignUp) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _firstNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'First name',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lastNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Last name',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Email'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Password'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: widget.controller.isBusy
                      ? null
                      : () async {
                          if (isSignUp) {
                            await widget.controller.signUp(
                              firstName: _firstNameController.text,
                              lastName: _lastNameController.text,
                              email: _emailController.text,
                              password: _passwordController.text,
                            );
                          } else {
                            await widget.controller.signIn(
                              email: _emailController.text,
                              password: _passwordController.text,
                            );
                          }
                        },
                  child: widget.controller.isBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isSignUp ? 'Create account' : 'Sign in'),
                ),
                if (!kReleaseMode) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: widget.controller.isBusy
                        ? null
                        : widget.controller.continueInPreview,
                    child: Text(
                      'Skip — preview without account',
                      style: TextStyle(
                        color: onBg.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (!isSignUp)
                  TextButton(
                    onPressed: widget.controller.isBusy
                        ? null
                        : () => widget.controller.requestPasswordReset(
                            _emailController.text,
                          ),
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: onBg.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Billing
// ---------------------------------------------------------------------------

class _BillingView extends StatelessWidget {
  const _BillingView({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final onBg = dark ? Colors.white : Colors.black;
    final subscriptionStatus = controller.account?.goalLockSubscriptionStatus
        ?.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _GlassPanel(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: _RocketBadge(size: 52)),
                const SizedBox(height: 24),
                Text(
                  'Unlock Goal Lock',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  'Goal Lock requires an active subscription before non-admin accounts can use the app.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                _GlassPanel(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\$0.99',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'First month',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Then \$5.00 per month after that.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: onBg.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                for (final line in const [
                  'Daily lock screens stay tied to your Rocket Goals account.',
                  'Your first invoice is 99 cents. Every renewal after that is 5 dollars monthly.',
                  'Admins bypass billing automatically.',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_circle,
                            size: 18,
                            color: _brandRed,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            line,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (subscriptionStatus != null &&
                    subscriptionStatus.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Current billing status: ${_formatBillingStatus(subscriptionStatus)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: onBg.withValues(alpha: 0.66),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: controller.isBusy
                      ? null
                      : () async {
                          final checkoutUri = await controller.startCheckout();
                          if (checkoutUri == null || !context.mounted) {
                            return;
                          }
                          final launched = await launchUrl(
                            checkoutUri,
                            mode: LaunchMode.externalApplication,
                          );
                          if (!launched && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not open checkout. Please try again.',
                                ),
                              ),
                            );
                          }
                        },
                  child: controller.isBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Pay and unlock'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: controller.isBusy
                      ? null
                      : () => controller.refreshLinkedAccount(),
                  child: const Text('I completed payment'),
                ),
                if (controller.canManageBilling) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: controller.isBusy
                        ? null
                        : () async {
                            final billingUri = await controller
                                .openBillingPortal();
                            if (billingUri == null || !context.mounted) {
                              return;
                            }
                            final launched = await launchUrl(
                              billingUri,
                              mode: LaunchMode.externalApplication,
                            );
                            if (!launched && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not open billing portal. Please try again.',
                                  ),
                                ),
                              );
                            }
                          },
                    child: const Text('Manage billing'),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: controller.isBusy ? null : controller.signOut,
                  child: Text(
                    'Sign out',
                    style: TextStyle(
                      color: onBg.withValues(alpha: 0.42),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatBillingStatus(String status) {
  final normalized = status.trim().replaceAll('_', ' ').toLowerCase();
  if (normalized.isEmpty) {
    return 'unpaid';
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}

// ---------------------------------------------------------------------------
// Onboarding
// ---------------------------------------------------------------------------

class _OnboardingView extends StatefulWidget {
  const _OnboardingView({required this.controller});

  final GoalLockController controller;

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  late final TextEditingController _goalController;
  late int _morningLockMinutes;
  late double _focusWindowHours;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(
      text: widget.controller.goalPlan?.goal ?? '',
    );
    _morningLockMinutes =
        widget.controller.goalPlan?.morningLockMinutes ?? 6 * 60 + 30;
    _focusWindowHours = (widget.controller.goalPlan?.focusWindowHours ?? 14)
        .toDouble();
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _morningLockMinutes ~/ 60,
        minute: _morningLockMinutes % 60,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: _brandRed),
          ),
          child: child!,
        );
      },
    );
    if (selected != null) {
      setState(() {
        _morningLockMinutes = selected.hour * 60 + selected.minute;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final overlay = dark ? Colors.white : Colors.black;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _GlassPanel(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Center(child: _RocketBadge(size: 48)),
                const SizedBox(height: 24),
                Text(
                  'What\'s your one goal?',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _goalController,
                  maxLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Write my book'),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final example in const [
                      'Write my book',
                      'Get fit',
                      'Launch my startup',
                    ])
                      ActionChip(
                        label: Text(example),
                        onPressed: () => _goalController.text = example,
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Morning lock time',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.alarm_rounded, size: 20),
                  label: Text(formatMinutes(_morningLockMinutes)),
                ),
                const SizedBox(height: 24),
                Text(
                  'Focus window',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_focusWindowHours.round()} hours until reflection',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _brandRed,
                    inactiveTrackColor: overlay.withValues(alpha: 0.08),
                    thumbColor: dark ? _brandWhite : _brandBlack,
                    overlayColor: const Color(0x33DC2626),
                  ),
                  child: Slider(
                    value: _focusWindowHours,
                    min: 8,
                    max: 16,
                    divisions: 8,
                    label: '${_focusWindowHours.round()}h',
                    onChanged: (v) => setState(() => _focusWindowHours = v),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: widget.controller.isBusy
                      ? null
                      : () => widget.controller.armGoalLock(
                          goal: _goalController.text,
                          morningLockMinutes: _morningLockMinutes,
                          focusWindowHours: _focusWindowHours.round(),
                        ),
                  child: widget.controller.isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Start'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active (main shell)
// ---------------------------------------------------------------------------

class _ActiveView extends StatelessWidget {
  const _ActiveView({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final onBg = dark ? Colors.white : Colors.black;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 34),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _RocketBadge(size: 32),
                  const SizedBox(width: 10),
                  Text(
                    'Goal Lock',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: onBg.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: controller.toggleTheme,
                    child: Icon(
                      dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: onBg.withValues(alpha: 0.4),
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _EditableGoalHeader(controller: controller),
              const SizedBox(height: 22),
              _TabBar(controller: controller),
              const SizedBox(height: 22),
              KeyedSubtree(
                key: ValueKey(controller.currentTab),
                child: switch (controller.currentTab) {
                  AppTab.today => _TodayTab(controller: controller),
                  AppTab.history => _HistoryTab(controller: controller),
                  AppTab.settings => _SettingsTab(controller: controller),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableGoalHeader extends StatelessWidget {
  const _EditableGoalHeader({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final overlay = dark ? Colors.white : Colors.black;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: controller.isBusy
          ? null
          : () => controller.selectTab(AppTab.settings),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.goalLabel,
            style: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(fontSize: 36),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_rounded,
                size: 16,
                color: overlay.withValues(alpha: 0.38),
              ),
              const SizedBox(width: 6),
              Text(
                'Tap title to edit in settings',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: overlay.withValues(alpha: 0.42),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today
// ---------------------------------------------------------------------------

class _TodayTab extends StatelessWidget {
  const _TodayTab({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final onBg = dark ? Colors.white : Colors.black;
    final today = controller.todayCommitment;

    return Column(
      key: const ValueKey('today'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlassPanel(
          padding: const EdgeInsets.all(24),
          child: today == null
              ? Column(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 36,
                      color: _brandSmoke,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Waiting for morning lock',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.nextLockSummary(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY\'S ONE THING',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onBg.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      today.oneThing,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      controller.nextLockSummary(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (today.middayOnTrack != null) ...[
                      const SizedBox(height: 14),
                      _StatusTag(
                        label: today.middayOnTrack!
                            ? 'Noon: On track'
                            : 'Noon: Off track',
                        positive: today.middayOnTrack!,
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _StatChip(
                label: 'Streak',
                value: '${controller.currentStreak}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatChip(
                label: 'Follow-through',
                value: '${(controller.followThroughRate * 100).round()}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _GlassPanel(
          padding: const EdgeInsets.all(20),
          child: _MomentumRing(rate: controller.followThroughRate),
        ),
        if (controller.recentEntries(count: 3).isNotEmpty) ...[
          const SizedBox(height: 18),
          _GlassPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RECENT',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    letterSpacing: 2,
                    color: onBg.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                for (final entry in controller.recentEntries(count: 3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CompactHistoryRow(entry: entry),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// History
// ---------------------------------------------------------------------------

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final entries = controller.commitments;
    return Column(
      key: const ValueKey('history'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.recentEntries(count: 7).isNotEmpty) ...[
          _WeeklyStrip(entries: controller.recentEntries(count: 7)),
          const SizedBox(height: 18),
        ],
        if (entries.isEmpty)
          _GlassPanel(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No history yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          )
        else
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HistoryCard(entry: entry),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({required this.controller});

  final GoalLockController controller;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late final TextEditingController _goalController;
  late int _morningLockMinutes;
  late double _focusWindowHours;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(
      text: widget.controller.goalPlan?.goal ?? '',
    );
    _morningLockMinutes =
        widget.controller.goalPlan?.morningLockMinutes ?? 6 * 60 + 30;
    _focusWindowHours = (widget.controller.goalPlan?.focusWindowHours ?? 14)
        .toDouble();
  }

  @override
  void didUpdateWidget(covariant _SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final latestGoal = widget.controller.goalPlan?.goal ?? '';
    if (_goalController.text != latestGoal) {
      _goalController.text = latestGoal;
    }
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _pickMorningTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _morningLockMinutes ~/ 60,
        minute: _morningLockMinutes % 60,
      ),
    );
    if (picked != null) {
      setState(() {
        _morningLockMinutes = picked.hour * 60 + picked.minute;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final overlay = dark ? Colors.white : Colors.black;

    return Column(
      key: const ValueKey('settings'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlassPanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Goal', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _goalController,
                maxLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'What goal are you protecting now?',
                ),
                onSubmitted: (_) => widget.controller.isBusy
                    ? null
                    : widget.controller.updateGoal(_goalController.text),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: widget.controller.isBusy
                    ? null
                    : () => widget.controller.updateGoal(_goalController.text),
                child: const Text('Save goal'),
              ),
              const SizedBox(height: 24),
              Text('Schedule', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickMorningTime,
                icon: const Icon(Icons.alarm_rounded, size: 20),
                label: Text(
                  'Morning lock: ${formatMinutes(_morningLockMinutes)}',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Focus window: ${_focusWindowHours.round()} hours',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: dark ? _brandWhite : _brandBlack,
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _brandRed,
                  inactiveTrackColor: overlay.withValues(alpha: 0.08),
                  thumbColor: dark ? _brandWhite : _brandBlack,
                  overlayColor: const Color(0x33DC2626),
                ),
                child: Slider(
                  min: 8,
                  max: 16,
                  divisions: 8,
                  value: _focusWindowHours,
                  label: '${_focusWindowHours.round()}h',
                  onChanged: (v) => setState(() => _focusWindowHours = v),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: widget.controller.isBusy
                    ? null
                    : () => widget.controller.updateSchedule(
                        morningLockMinutes: _morningLockMinutes,
                        focusWindowHours: _focusWindowHours.round(),
                      ),
                child: const Text('Save schedule'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(
                dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 20,
                color: overlay.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Dark mode',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Switch.adaptive(
                value: widget.controller.isDarkMode,
                activeTrackColor: _brandRed,
                onChanged: (_) => widget.controller.toggleTheme(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _GlassPanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Account', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                widget.controller.account?.displayName ?? '',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: dark ? _brandWhite : _brandBlack,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if ((widget.controller.account?.email ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.controller.account!.email,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (widget.controller.account?.mode == ExperienceMode.linked) ...[
                const SizedBox(height: 10),
                Text(
                  widget.controller.account!.isAdmin
                      ? 'Billing: Admin access'
                      : 'Billing: ${widget.controller.account!.hasGoalLockAccess ? 'Active' : _formatBillingStatus(widget.controller.account!.goalLockSubscriptionStatus ?? 'unpaid')}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: dark ? _brandMist : _brandSmoke,
                  ),
                ),
                if (!widget.controller.account!.isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton(
                      onPressed: widget.controller.isBusy
                          ? null
                          : () async {
                              final billingUri = await widget.controller
                                  .openBillingPortal();
                              if (billingUri == null || !context.mounted) {
                                return;
                              }
                              final launched = await launchUrl(
                                billingUri,
                                mode: LaunchMode.externalApplication,
                              );
                              if (!launched && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not open billing portal. Please try again.',
                                    ),
                                  ),
                                );
                              }
                            },
                      child: const Text('Manage billing'),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: widget.controller.isBusy
                    ? null
                    : widget.controller.signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Morning Lock Overlay
// ---------------------------------------------------------------------------

class _MorningLockOverlay extends StatefulWidget {
  const _MorningLockOverlay({required this.controller});

  final GoalLockController controller;

  @override
  State<_MorningLockOverlay> createState() => _MorningLockOverlayState();
}

class _MorningLockOverlayState extends State<_MorningLockOverlay> {
  late final TextEditingController _answerController;

  @override
  void initState() {
    super.initState();
    _answerController = TextEditingController();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LockBackdrop(
      child: _GlassPanel(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What is the ONE thing you will do today for ${widget.controller.goalLabel}?',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _answerController,
              maxLines: 1,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Write 400 words before coffee',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: widget.controller.isBusy
                  ? null
                  : () => widget.controller.submitMorningOneThing(
                      _answerController.text,
                    ),
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Midday Check Overlay
// ---------------------------------------------------------------------------

class _MiddayCheckOverlay extends StatelessWidget {
  const _MiddayCheckOverlay({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final pending = controller.pendingMiddayCheck;
    return _LockBackdrop(
      child: _GlassPanel(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Are you on track to do your one thing?',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontSize: 34),
            ),
            const SizedBox(height: 16),
            Text(
              pending?.oneThing ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: _brandRed),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.isBusy
                        ? null
                        : () => controller.submitMiddayCheck(false),
                    child: const Text('No'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: controller.isBusy
                        ? null
                        : () => controller.submitMiddayCheck(true),
                    child: const Text('Yes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Evening Reflection Overlay
// ---------------------------------------------------------------------------

class _EveningReflectionOverlay extends StatelessWidget {
  const _EveningReflectionOverlay({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final pending = controller.pendingReflection;
    return _LockBackdrop(
      child: _GlassPanel(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Did you do it?',
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(fontSize: 40),
            ),
            const SizedBox(height: 16),
            Text(
              pending?.oneThing ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: _brandRed),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.isBusy
                        ? null
                        : () => controller.submitEveningReflection(false),
                    child: const Text('No'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: controller.isBusy
                        ? null
                        : () => controller.submitEveningReflection(true),
                    child: const Text('Yes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Banner Toast
// ---------------------------------------------------------------------------

class _BannerToast extends StatelessWidget {
  const _BannerToast({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final isError = controller.errorMessage != null;
    final fg = isError ? Colors.white : (dark ? Colors.white : _brandBlack);

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: isError
                  ? const Color(0x88DC2626)
                  : (dark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.black.withValues(alpha: 0.06)),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: (dark ? Colors.white : Colors.black).withValues(
                  alpha: 0.12,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.warning_rounded : Icons.check_circle_rounded,
                  color: fg,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    controller.errorMessage ?? controller.noticeMessage ?? '',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: controller.dismissBanner,
                  icon: Icon(Icons.close_rounded, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared UI components
// ---------------------------------------------------------------------------

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.width,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: dark ? 28 : 18,
            sigmaY: dark ? 28 : 18,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.18 : 0.06),
                  blurRadius: dark ? 30 : 16,
                  offset: Offset(0, dark ? 18 : 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -80,
          child: _BlurOrb(
            size: 320,
            colors: dark
                ? const [Color(0x55DC2626), Color(0x00DC2626)]
                : const [Color(0x12DC2626), Color(0x00DC2626)],
          ),
        ),
        Positioned(
          bottom: -100,
          right: -60,
          child: _BlurOrb(
            size: 280,
            colors: dark
                ? const [Color(0x33991B1B), Color(0x00991B1B)]
                : const [Color(0x0A991B1B), Color(0x00991B1B)],
          ),
        ),
      ],
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _RocketBadge extends StatelessWidget {
  const _RocketBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: Image.asset(
        'assets/branding/rocket-goals-web-logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.authMode, required this.onChanged});

  final AuthMode authMode;
  final ValueChanged<AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final overlay = dark ? Colors.white : Colors.black;
    return Container(
      decoration: BoxDecoration(
        color: overlay.withValues(alpha: dark ? 0.05 : 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: overlay.withValues(alpha: dark ? 0.08 : 0.06),
        ),
      ),
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          Expanded(
            child: _SwitchPill(
              label: 'Sign in',
              selected: authMode == AuthMode.signIn,
              onTap: () => onChanged(AuthMode.signIn),
            ),
          ),
          Expanded(
            child: _SwitchPill(
              label: 'Create account',
              selected: authMode == AuthMode.signUp,
              onTap: () => onChanged(AuthMode.signUp),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchPill extends StatelessWidget {
  const _SwitchPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _brandRed : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected
                  ? Colors.white
                  : (dark ? Colors.white : Colors.black).withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final overlay = dark ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: overlay.withValues(alpha: dark ? 0.05 : 0.04),
        border: Border.all(
          color: overlay.withValues(alpha: dark ? 0.08 : 0.06),
        ),
      ),
      child: Row(
        children: [
          _TabPill(
            label: 'Today',
            icon: Icons.today_rounded,
            selected: controller.currentTab == AppTab.today,
            onTap: () => controller.selectTab(AppTab.today),
          ),
          _TabPill(
            label: 'History',
            icon: Icons.history_rounded,
            selected: controller.currentTab == AppTab.history,
            onTap: () => controller.selectTab(AppTab.history),
          ),
          _TabPill(
            label: 'Settings',
            icon: Icons.settings_rounded,
            selected: controller.currentTab == AppTab.settings,
            onTap: () => controller.selectTab(AppTab.settings),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final unselectedColor = (dark ? Colors.white : Colors.black).withValues(
      alpha: 0.55,
    );

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? _brandRed : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : unselectedColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  color: selected ? Colors.white : unselectedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final overlay = dark ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: overlay.withValues(alpha: dark ? 0.06 : 0.04),
        border: Border.all(
          color: overlay.withValues(alpha: dark ? 0.08 : 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: overlay.withValues(alpha: 0.45),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final foreground = positive
        ? (dark ? _brandWhite : const Color(0xFF166534))
        : _brandRed;
    final background = positive
        ? (dark ? const Color(0x22F7F4EF) : const Color(0x1622C55E))
        : const Color(0x16DC2626);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _MomentumRing extends StatelessWidget {
  const _MomentumRing({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final overlay = dark ? Colors.white : Colors.black;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 200.0);
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: rate.clamp(0, 1)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _RingPainter(
                        progress: value,
                        baseRingColor: overlay.withValues(alpha: 0.07),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(value * 100).round()}%',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'follow-through',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: overlay.withValues(alpha: 0.45),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.baseRingColor});

  final double progress;
  final Color baseRingColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 12;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..color = baseRingColor
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..shader = const SweepGradient(
        colors: [_brandRedDeep, _brandRed, _brandWhite],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, basePaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.baseRingColor != baseRingColor;
}

class _CompactHistoryRow extends StatelessWidget {
  const _CompactHistoryRow({required this.entry});

  final DailyCommitment entry;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: switch (entry.didComplete) {
              true => dark ? _brandWhite : const Color(0xFF22C55E),
              false => _brandRed,
              null => _brandSmoke,
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            entry.oneThing,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: dark ? Colors.white : _brandBlack,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          entry.dateKey.substring(5),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

class _WeeklyStrip extends StatelessWidget {
  const _WeeklyStrip({required this.entries});

  final List<DailyCommitment> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final dark = _isDark(context);
    final overlay = dark ? Colors.white : Colors.black;
    final ordered = [...entries]
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));

    return Row(
      children: [
        for (final entry in ordered)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: switch (entry.didComplete) {
                    true =>
                      dark ? const Color(0x44F7F4EF) : const Color(0x3022C55E),
                    false => const Color(0x33DC2626),
                    null =>
                      dark ? const Color(0x22D6D1CB) : const Color(0x11D6D1CB),
                  },
                  border: Border.all(color: overlay.withValues(alpha: 0.06)),
                ),
                child: Center(
                  child: Text(
                    entry.dateKey.substring(8),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: dark ? Colors.white : _brandBlack,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final DailyCommitment entry;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final overlay = dark ? Colors.white : Colors.black;
    final dotColor = switch (entry.didComplete) {
      true => dark ? _brandWhite : const Color(0xFF22C55E),
      false => _brandRed,
      null => _brandSmoke,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: overlay.withValues(alpha: dark ? 0.05 : 0.03),
        border: Border.all(
          color: overlay.withValues(alpha: dark ? 0.08 : 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.oneThing,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: dark ? _brandWhite : _brandBlack,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.dateKey,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: overlay.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LockBackdrop extends StatelessWidget {
  const _LockBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xE0070707),
        child: Center(
          child: Padding(padding: const EdgeInsets.all(24), child: child),
        ),
      ),
    );
  }
}
