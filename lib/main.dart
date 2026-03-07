import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(GoalLockApp(controller: GoalLockController()));
}
