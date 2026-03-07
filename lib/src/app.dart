import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';

const _brandWhite = Color(0xFFF7F4EF);
const _brandMist = Color(0xFFD6D1CB);
const _brandSmoke = Color(0xFFA49D95);
const _brandRed = Color(0xFFDC2626);
const _brandRedBright = Color(0xFFEF4444);
const _brandRedDeep = Color(0xFF991B1B);
const _brandBlack = Color(0xFF070707);
const _brandBlackSoft = Color(0xFF101010);

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
    widget.controller.initialize();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Goal Lock',
          theme: _buildTheme(),
          home: GoalLockRoot(controller: widget.controller),
        );
      },
    );
  }
}

ThemeData _buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _brandRed,
    brightness: Brightness.dark,
    primary: _brandRed,
    secondary: _brandWhite,
    tertiary: _brandWhite,
    surface: _brandBlack,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: _brandBlack,
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: _brandWhite,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.6,
        height: 0.96,
      ),
      displayMedium: TextStyle(
        color: _brandWhite,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
        height: 1,
      ),
      headlineLarge: TextStyle(
        color: _brandWhite,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: TextStyle(
        color: _brandWhite,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      titleLarge: TextStyle(
        color: _brandWhite,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        color: _brandMist,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        color: _brandMist,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
      labelLarge: TextStyle(
        color: _brandWhite,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: _brandRed, width: 1.5),
      ),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.32)),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _brandWhite,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      labelStyle: TextStyle(
        color: _brandWhite,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

class GoalLockRoot extends StatelessWidget {
  const GoalLockRoot({super.key, required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final phase = controller.lockPhase;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              _brandBlack,
              Color(0xFF160708),
              _brandBlackSoft,
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _NebulaBackdrop()),
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: switch (phase) {
                  LockPhase.loading => const _LoadingView(),
                  LockPhase.auth => _AuthView(controller: controller),
                  LockPhase.onboarding => _OnboardingView(controller: controller),
                  _ => _ActiveView(controller: controller),
                },
              ),
            ),
            if (phase == LockPhase.morningLocked)
              _MorningLockOverlay(controller: controller),
            if (phase == LockPhase.eveningLocked)
              _EveningReflectionOverlay(controller: controller),
            if (controller.errorMessage != null || controller.noticeMessage != null)
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

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _GlassPanel(
        width: 320,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _RocketBadge(size: 76),
            const SizedBox(height: 22),
            Text(
              'GOAL LOCK',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Loading the ritual that protects your biggest goal.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final isSignUp = widget.controller.authMode == AuthMode.signUp;
    return SingleChildScrollView(
      key: ValueKey<bool>(isSignUp),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 780;
              final heroPanel = Padding(
                padding: EdgeInsets.only(
                  right: stacked ? 0 : 20,
                  bottom: stacked ? 20 : 0,
                ),
                child: _GlassPanel(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _BrandWordmark(),
                      const SizedBox(height: 26),
                      Text(
                        'Every morning, your phone locks until you choose one move.',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontSize: stacked ? 40 : 52,
                            ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Goal Lock strips goal-setting down to one ritual: one goal, one move, one honest reflection before bed.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 26),
                      const _FeatureLine(
                        title: 'Linked identity',
                        body:
                            'Use the same Rocket Goals email and account profile already living in rocket-prompt.',
                      ),
                      const SizedBox(height: 14),
                      const _FeatureLine(
                        title: 'Fast onboarding',
                        body:
                            'No task tree. No project admin. Name the goal, pick the lock time, and the ritual is live.',
                      ),
                      const SizedBox(height: 14),
                      const _FeatureLine(
                        title: 'Nightly honesty',
                        body:
                            'One tap. Yes or no. Momentum becomes visible instead of vague.',
                      ),
                      const SizedBox(height: 26),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          _MiniStat(label: 'One Goal', value: 'Singular focus'),
                          _MiniStat(label: 'Morning', value: 'Commit before drift'),
                          _MiniStat(label: 'Night', value: 'Reflect with one tap'),
                        ],
                      ),
                    ],
                  ),
                ),
              );

              final formPanel = _GlassPanel(
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ModeSwitch(
                      authMode: widget.controller.authMode,
                      onChanged: widget.controller.setAuthMode,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      isSignUp ? 'Create your lock ritual' : 'Link your Rocket Goals account',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSignUp
                          ? 'This uses the same account system as Rocket Goals. Setup stays fast on purpose.'
                          : 'Use your existing Rocket Goals login, or preview the full experience instantly.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    if (isSignUp) ...[
                      TextField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                          hintText: 'Ava',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                          hintText: 'Jordan',
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'you@rocketprompt.io',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: isSignUp ? 'At least 6 characters' : 'Your password',
                      ),
                    ),
                    const SizedBox(height: 18),
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
                          : Text(
                              isSignUp ? 'Create account' : 'Link account',
                            ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: widget.controller.isBusy
                          ? null
                          : widget.controller.continueInPreview,
                      child: const Text('Preview the product'),
                    ),
                    if (!isSignUp) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: widget.controller.isBusy
                            ? null
                            : () async {
                                await widget.controller.requestPasswordReset(
                                  _emailController.text,
                                );
                              },
                        child: const Text('Forgot password?'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _InfoStrip(
                      title: 'Shared account system',
                      body:
                          'Profiles map to the same `userProfiles` and `rocketGoals` collections used by the existing Rocket Goals app.',
                    ),
                  ],
                ),
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [heroPanel, formPanel],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: heroPanel),
                  Expanded(flex: 4, child: formPanel),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

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
    _goalController =
        TextEditingController(text: widget.controller.goalPlan?.goal ?? '');
    _morningLockMinutes =
        widget.controller.goalPlan?.morningLockMinutes ?? 6 * 60 + 30;
    _focusWindowHours =
        (widget.controller.goalPlan?.focusWindowHours ?? 14).toDouble();
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
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _brandRed,
                ),
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
    final reflectionTime = (_morningLockMinutes + (_focusWindowHours * 60).round()) % (24 * 60);
    final imported = widget.controller.goalPlan?.importedFromRocketGoals ?? false;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandWordmark(),
              const SizedBox(height: 24),
              Text(
                'Fast onboarding for one goal.',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 46),
              ),
              const SizedBox(height: 12),
              Text(
                'No tasks. No subtasks. Name the goal, choose when the lock hits, and the ritual starts.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 820;
                  final setupPanel = _GlassPanel(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionEyebrow(
                          label: imported ? 'Imported Mission' : 'One Goal',
                        ),
                        const SizedBox(height: 12),
                        if (imported)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Wrap(
                              spacing: 8,
                              children: const [
                                _PillTag(
                                  label: 'Pulled from Rocket Goals',
                                  tone: _TagTone.highlight,
                                ),
                                _PillTag(
                                  label: 'Edit if you want a tighter target',
                                  tone: _TagTone.soft,
                                ),
                              ],
                            ),
                          ),
                        TextField(
                          controller: _goalController,
                          maxLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'What is the goal?',
                            hintText: 'Write my book',
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final example in const [
                              'Write my book',
                              'Get fit',
                              'Launch my startup',
                              'Ship my portfolio',
                            ])
                              ActionChip(
                                label: Text(example),
                                onPressed: () => _goalController.text = example,
                              ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        const _SectionEyebrow(label: 'Daily Rhythm'),
                        const SizedBox(height: 12),
                        Text(
                          'Morning lock time',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.alarm_rounded),
                          label: Text(formatMinutes(_morningLockMinutes)),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Focus window length',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: _brandRed,
                            inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                            thumbColor: _brandWhite,
                            overlayColor: const Color(0x33DC2626),
                          ),
                          child: Slider(
                            value: _focusWindowHours,
                            min: 8,
                            max: 16,
                            divisions: 8,
                            label: '${_focusWindowHours.round()} hours',
                            onChanged: (value) {
                              setState(() {
                                _focusWindowHours = value;
                              });
                            },
                          ),
                        ),
                        Text(
                          '${_focusWindowHours.round()} hour focus window',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: widget.controller.isBusy
                              ? null
                              : () async {
                                  await widget.controller.armGoalLock(
                                    goal: _goalController.text,
                                    morningLockMinutes: _morningLockMinutes,
                                    focusWindowHours: _focusWindowHours.round(),
                                  );
                                },
                          child: widget.controller.isBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Arm Goal Lock'),
                        ),
                      ],
                    ),
                  );

                  final previewPanel = _GlassPanel(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionEyebrow(label: 'Preview'),
                        const SizedBox(height: 14),
                        _TimelinePreview(
                          morningLockMinutes: _morningLockMinutes,
                          reflectionMinutes: reflectionTime,
                        ),
                        const SizedBox(height: 18),
                        _InfoStrip(
                          title: 'Morning',
                          body:
                              'Your device ritual triggers at ${formatMinutes(_morningLockMinutes)} and asks one question: what is the one thing you will do today?',
                        ),
                        const SizedBox(height: 12),
                        _InfoStrip(
                          title: 'Night',
                          body:
                              'After ${_focusWindowHours.round()} hours, the lock returns for one tap: did you do it?',
                        ),
                        const SizedBox(height: 12),
                        _InfoStrip(
                          title: 'Account bridge',
                          body: widget.controller.account?.mode ==
                                  ExperienceMode.linked
                              ? 'This profile is linked to Rocket Goals. Your chosen mission will sync back into that account.'
                              : 'Preview mode keeps the full UX intact so you can feel the product before linking.',
                        ),
                      ],
                    ),
                  );

                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        setupPanel,
                        const SizedBox(height: 20),
                        previewPanel,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: setupPanel),
                      const SizedBox(width: 20),
                      Expanded(flex: 4, child: previewPanel),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveView extends StatelessWidget {
  const _ActiveView({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 34),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandWordmark(),
              const SizedBox(height: 20),
              _GlassPanel(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const _PillTag(
                          label: 'Mission Orbit',
                          tone: _TagTone.highlight,
                        ),
                        _PillTag(
                          label: controller.account?.mode == ExperienceMode.linked
                              ? controller.hasLinkedSync
                                  ? 'Synced to Rocket Goals'
                                  : 'Reconnect to sync'
                              : 'Preview mode',
                          tone: controller.account?.mode == ExperienceMode.linked
                              ? _TagTone.soft
                              : _TagTone.soft,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      controller.goalLabel,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontSize: 44,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Morning question first. Everything else can wait.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 760;
                        final cards = <Widget>[
                          _StatCard(
                            title: 'Streak',
                            value: '${controller.currentStreak}',
                            body: 'Consecutive yes nights',
                            accent: _brandWhite,
                          ),
                          _StatCard(
                            title: 'Follow-through',
                            value: '${(controller.followThroughRate * 100).round()}%',
                            body: 'Reflection yes rate',
                            accent: _brandRedBright,
                          ),
                          _StatCard(
                            title: 'Next lock',
                            value: controller.nextLockSummary(),
                            body: 'Your next forced decision point',
                            accent: _brandRed,
                            compact: true,
                          ),
                        ];

                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int index = 0; index < cards.length; index++) ...[
                                cards[index],
                                if (index != cards.length - 1)
                                  const SizedBox(height: 14),
                              ],
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int index = 0; index < cards.length; index++) ...[
                              Expanded(child: cards[index]),
                              if (index != cards.length - 1)
                                const SizedBox(width: 14),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _TabBar(controller: controller),
              const SizedBox(height: 18),
              switch (controller.currentTab) {
                AppTab.today => _TodayTab(controller: controller),
                AppTab.history => _HistoryTab(controller: controller),
                AppTab.settings => _SettingsTab(controller: controller),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final today = controller.todayCommitment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 780;
            final leftPanel = _GlassPanel(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionEyebrow(label: 'Today'),
                  const SizedBox(height: 12),
                  Text(
                    today == null
                        ? 'Your morning lock is still waiting for the answer.'
                        : 'Today\'s one thing is locked in.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    child: today == null
                        ? _FocusPlaceholder(goal: controller.goalLabel)
                        : _FocusCommitmentCard(entry: today),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    controller.pendingReflection != null
                        ? 'Reflection is due now.'
                        : controller.nextLockSummary(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );

            final rightPanel = Column(
              children: [
                _GlassPanel(
                  padding: const EdgeInsets.all(24),
                  child: _MomentumRing(rate: controller.followThroughRate),
                ),
                const SizedBox(height: 18),
                _GlassPanel(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionEyebrow(label: 'Recent nights'),
                      const SizedBox(height: 14),
                      for (final entry in controller.recentEntries(count: 4))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CompactHistoryRow(entry: entry),
                        ),
                    ],
                  ),
                ),
              ],
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  leftPanel,
                  const SizedBox(height: 18),
                  rightPanel,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: leftPanel),
                const SizedBox(width: 18),
                Expanded(flex: 4, child: rightPanel),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final entries = controller.commitments;
    return _GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionEyebrow(label: 'History'),
          const SizedBox(height: 12),
          Text(
            'Momentum is visible when the answers stack.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 18),
          _WeeklyStrip(entries: controller.recentEntries(count: 7)),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            Text(
              'No history yet. Tomorrow morning creates the first real line in the log.',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            Column(
              children: [
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _HistoryCard(entry: entry),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({required this.controller});

  final GoalLockController controller;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late int _morningLockMinutes;
  late double _focusWindowHours;

  @override
  void initState() {
    super.initState();
    _morningLockMinutes =
        widget.controller.goalPlan?.morningLockMinutes ?? 6 * 60 + 30;
    _focusWindowHours =
        (widget.controller.goalPlan?.focusWindowHours ?? 14).toDouble();
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
    final reflectionMinutes = (_morningLockMinutes + (_focusWindowHours * 60).round()) % (24 * 60);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;
        final schedulePanel = _GlassPanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionEyebrow(label: 'Schedule'),
              const SizedBox(height: 12),
              Text(
                'Tune the rhythm, keep the rule.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickMorningTime,
                icon: const Icon(Icons.schedule_rounded),
                label: Text('Morning lock: ${formatMinutes(_morningLockMinutes)}'),
              ),
              const SizedBox(height: 18),
              Text(
                'Focus window: ${_focusWindowHours.round()} hours',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _brandRed,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                  thumbColor: _brandWhite,
                  overlayColor: const Color(0x33DC2626),
                ),
                child: Slider(
                  min: 8,
                  max: 16,
                  divisions: 8,
                  value: _focusWindowHours,
                  label: '${_focusWindowHours.round()} hours',
                  onChanged: (value) {
                    setState(() {
                      _focusWindowHours = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Reflection lock returns at ${formatMinutes(reflectionMinutes)}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
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
        );

        final rightColumn = Column(
          children: [
            _GlassPanel(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionEyebrow(label: 'Account'),
                  const SizedBox(height: 12),
                  Text(
                    widget.controller.account?.displayName ?? 'Unknown',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.controller.account?.email ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  _InfoStrip(
                    title: widget.controller.account?.mode == ExperienceMode.linked
                        ? 'Linked account'
                        : 'Preview account',
                    body: widget.controller.account?.mode == ExperienceMode.linked
                        ? widget.controller.hasLinkedSync
                            ? 'Changes sync into the same project used by Rocket Goals.'
                            : 'This session was restored locally. Sign back in if you want cloud sync again.'
                        : 'Preview mode is local and built to let you feel the product instantly.',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed:
                        widget.controller.isBusy ? null : widget.controller.signOut,
                    child: const Text('Sign out'),
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
                  const _SectionEyebrow(label: 'Build note'),
                  const SizedBox(height: 12),
                  Text(
                    'This build ships the ritual and state model.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Native OS-wide phone locking would be the next platform-specific layer on top of this experience.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              schedulePanel,
              const SizedBox(height: 18),
              rightColumn,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: schedulePanel),
            const SizedBox(width: 18),
            Expanded(flex: 4, child: rightColumn),
          ],
        );
      },
    );
  }
}

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
        width: 620,
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PillTag(label: 'Morning lock', tone: _TagTone.highlight),
            const SizedBox(height: 16),
            Text(
              'What is the ONE thing you will do today for ${widget.controller.goalLabel}?',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 14),
            Text(
              'One line only. This unlocks the day.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _answerController,
              maxLines: 1,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Write 400 words before coffee',
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: widget.controller.isBusy
                  ? null
                  : () => widget.controller.submitMorningOneThing(
                        _answerController.text,
                      ),
              child: const Text('Unlock the day'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EveningReflectionOverlay extends StatelessWidget {
  const _EveningReflectionOverlay({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final pending = controller.pendingReflection;
    return _LockBackdrop(
      child: _GlassPanel(
        width: 620,
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PillTag(label: 'Night reflection', tone: _TagTone.highlight),
            const SizedBox(height: 16),
            Text(
              'Did you do it?',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 44),
            ),
            const SizedBox(height: 10),
            Text(
              pending?.oneThing ?? '',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _brandRed,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              'One tap. Honest answer. Then the ritual resets.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 22),
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

class _BannerToast extends StatelessWidget {
  const _BannerToast({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    final isError = controller.errorMessage != null;
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
                  : Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.warning_rounded : Icons.check_circle_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    controller.errorMessage ?? controller.noticeMessage ?? '',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: controller.dismissBanner,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
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

class _NebulaBackdrop extends StatelessWidget {
  const _NebulaBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridGlowPainter(),
      child: Stack(
        children: const [
          Positioned(
            top: -120,
            left: -80,
            child: _BlurOrb(
              size: 340,
              colors: [Color(0x99DC2626), Color(0x00DC2626)],
            ),
          ),
          Positioned(
            top: 180,
            right: -90,
            child: _BlurOrb(
              size: 300,
              colors: [Color(0x70F7F4EF), Color(0x00F7F4EF)],
            ),
          ),
          Positioned(
            bottom: -120,
            left: 80,
            child: _BlurOrb(
              size: 360,
              colors: [Color(0x66991B1B), Color(0x00991B1B)],
            ),
          ),
        ],
      ),
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

class _GridGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const gap = 32.0;

    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BrandWordmark extends StatelessWidget {
  const _BrandWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _RocketBadge(size: 52),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GOAL LOCK',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
            ),
            Text(
              'by Rocket Goals',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RocketBadge extends StatelessWidget {
  const _RocketBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_brandRed, _brandBlackSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _brandRed.withValues(alpha: 0.34),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.rocket_launch_rounded,
          color: _brandWhite,
          size: size * 0.52,
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _brandRed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyLarge,
              children: [
                TextSpan(
                  text: '$title. ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.54),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(6),
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
                  color: Colors.white.withValues(alpha: selected ? 1 : 0.72),
                ),
          ),
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            letterSpacing: 2.2,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

enum _TagTone { highlight, soft }

class _PillTag extends StatelessWidget {
  const _PillTag({required this.label, required this.tone});

  final String label;
  final _TagTone tone;

  @override
  Widget build(BuildContext context) {
    final isHighlight = tone == _TagTone.highlight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isHighlight
            ? const Color(0x33DC2626)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: isHighlight
              ? const Color(0x66DC2626)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _TimelinePreview extends StatelessWidget {
  const _TimelinePreview({
    required this.morningLockMinutes,
    required this.reflectionMinutes,
  });

  final int morningLockMinutes;
  final int reflectionMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TimelineNode(
          title: 'Morning lock',
          subtitle:
              'At ${formatMinutes(morningLockMinutes)}, the app blocks the feed and asks for one move.',
          tone: _brandRed,
        ),
        const SizedBox(height: 12),
        _TimelineNode(
          title: 'Unlocked work',
          subtitle:
              'You carry one line only, so the goal stays sharp all day.',
          tone: _brandWhite,
        ),
        const SizedBox(height: 12),
        _TimelineNode(
          title: 'Night reflection',
          subtitle:
              'At ${formatMinutes(reflectionMinutes)}, it comes back with one tap: yes or no.',
          tone: _brandRedBright,
        ),
      ],
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.title,
    required this.subtitle,
    required this.tone,
  });

  final String title;
  final String subtitle;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(shape: BoxShape.circle, color: tone),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.body,
    required this.accent,
    this.compact = false,
  });

  final String title;
  final String value;
  final String body;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(height: 12),
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.58),
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: compact
                ? Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    )
                : Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
          ),
          const SizedBox(height: 6),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller});

  final GoalLockController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _TabPill(
            label: 'Today',
            icon: Icons.grid_view_rounded,
            selected: controller.currentTab == AppTab.today,
            onTap: () => controller.selectTab(AppTab.today),
          ),
          _TabPill(
            label: 'History',
            icon: Icons.query_stats_rounded,
            selected: controller.currentTab == AppTab.history,
            onTap: () => controller.selectTab(AppTab.history),
          ),
          _TabPill(
            label: 'Settings',
            icon: Icons.tune_rounded,
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? _brandRed : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: Colors.white.withValues(alpha: selected ? 1 : 0.72),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: selected ? 1 : 0.72),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusPlaceholder extends StatelessWidget {
  const _FocusPlaceholder({required this.goal});

  final String goal;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('focus-placeholder'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            const Color(0x44DC2626),
            const Color(0x22101010),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Still locked',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'The question for $goal has not been answered yet.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _FocusCommitmentCard extends StatelessWidget {
  const _FocusCommitmentCard({required this.entry});

  final DailyCommitment entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>(entry.dateKey),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x66DC2626),
            Color(0x44101010),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'One thing',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            entry.oneThing,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}

class _MomentumRing extends StatelessWidget {
  const _MomentumRing({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 240.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionEyebrow(label: 'Momentum'),
            const SizedBox(height: 12),
            Center(
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
                          painter: _RingPainter(progress: value),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(value * 100).round()}%',
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'follow-through',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.64),
                                      fontWeight: FontWeight.w800,
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
            ),
          ],
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 12;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
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
      oldDelegate.progress != progress;
}

class _CompactHistoryRow extends StatelessWidget {
  const _CompactHistoryRow({required this.entry});

  final DailyCommitment entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: switch (entry.didComplete) {
              true => _brandWhite,
              false => _brandRed,
              null => _brandSmoke,
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.oneThing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.dateKey,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.56),
                    ),
              ),
            ],
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
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final ordered = [...entries]..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return Row(
      children: [
        for (final entry in ordered)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: switch (entry.didComplete) {
                    true => const Color(0x44F7F4EF),
                    false => const Color(0x44DC2626),
                    null => const Color(0x33D6D1CB),
                  },
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Center(
                  child: Text(
                    entry.dateKey.substring(5),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
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
    final outcomeLabel = switch (entry.didComplete) {
      true => 'Yes',
      false => 'No',
      null => 'Pending',
    };
    final tone = switch (entry.didComplete) {
      true => _brandWhite,
      false => _brandRed,
      null => _brandSmoke,
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.dateKey,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: tone.withValues(alpha: 0.18),
                ),
                child: Text(
                  outcomeLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(entry.oneThing, style: Theme.of(context).textTheme.bodyLarge),
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}
