import 'rocket_goals_bridge_base.dart';
import 'rocket_goals_bridge_stub.dart'
    if (dart.library.io) 'rocket_goals_bridge_io.dart' as platform;

RocketGoalsBridge createRocketGoalsBridge() => platform.createPlatformBridge();
