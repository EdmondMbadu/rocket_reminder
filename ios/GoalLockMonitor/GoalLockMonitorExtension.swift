import DeviceActivity

final class GoalLockMonitorExtension: DeviceActivityMonitor {
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    GoalLockShieldController.applySelection()
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    GoalLockShieldController.clear()
  }
}
