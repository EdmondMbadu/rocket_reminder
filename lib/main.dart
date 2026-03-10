import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  runApp(GoalLockApp(controller: GoalLockController()));
}
