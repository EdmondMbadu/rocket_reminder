import DeviceActivity
import FamilyControls
import ManagedSettings
import UserNotifications

private let goalLockAppGroup = "group.com.example.goalLock.shared"
private let goalLockSelectionKey = "goalLock.familySelection"
private let goalLockScheduleKey = "goalLock.schedule"

struct GoalLockSchedule: Codable {
  let morningLockMinutes: Int
  let reflectionLockMinutes: Int
  let focusWindowHours: Int
}

enum GoalLockSharedState {
  static var defaults: UserDefaults {
    UserDefaults(suiteName: goalLockAppGroup) ?? .standard
  }

  static func loadSelection() -> FamilyActivitySelection {
    guard
      let data = defaults.data(forKey: goalLockSelectionKey),
      let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    else {
      return FamilyActivitySelection()
    }
    return selection
  }

  static func saveSelection(_ selection: FamilyActivitySelection) {
    guard let data = try? JSONEncoder().encode(selection) else {
      return
    }
    defaults.set(data, forKey: goalLockSelectionKey)
  }

  static func loadSchedule() -> GoalLockSchedule? {
    guard
      let data = defaults.data(forKey: goalLockScheduleKey),
      let schedule = try? JSONDecoder().decode(GoalLockSchedule.self, from: data)
    else {
      return nil
    }
    return schedule
  }

  static func saveSchedule(_ schedule: GoalLockSchedule) {
    guard let data = try? JSONEncoder().encode(schedule) else {
      return
    }
    defaults.set(data, forKey: goalLockScheduleKey)
  }

  static func clearAll() {
    defaults.removeObject(forKey: goalLockSelectionKey)
    defaults.removeObject(forKey: goalLockScheduleKey)
  }

  static func selectedAppsCount() -> Int {
    let selection = loadSelection()
    return selection.applicationTokens.count + selection.categoryTokens.count
  }
}

enum GoalLockShieldController {
  private static let store = ManagedSettingsStore()

  static func applySelection() {
    let selection = GoalLockSharedState.loadSelection()
    let applications = selection.applicationTokens
    let categories = selection.categoryTokens

    store.shield.applications = applications.isEmpty ? nil : applications
    store.shield.applicationCategories = categories.isEmpty
      ? nil
      : ShieldSettings.ActivityCategoryPolicy.specific(categories)
  }

  static func clear() {
    store.shield.applications = nil
    store.shield.applicationCategories = nil
  }

  static func refreshNow() {
    guard let schedule = GoalLockSharedState.loadSchedule() else {
      clear()
      return
    }
    if isWithinFocusWindow(schedule) {
      applySelection()
    } else {
      clear()
    }
  }

  static func startMonitoring() {
    guard let schedule = GoalLockSharedState.loadSchedule() else {
      stopMonitoring()
      clear()
      return
    }
    let center = DeviceActivityCenter()
    center.stopMonitoring()
    guard GoalLockSharedState.selectedAppsCount() > 0 else {
      clear()
      return
    }

    do {
      if schedule.morningLockMinutes < schedule.reflectionLockMinutes {
        try center.startMonitoring(
          DeviceActivityName("goal_lock.daily"),
          during: DeviceActivitySchedule(
            intervalStart: dateComponents(for: schedule.morningLockMinutes),
            intervalEnd: dateComponents(for: schedule.reflectionLockMinutes),
            repeats: true
          )
        )
      } else {
        try center.startMonitoring(
          DeviceActivityName("goal_lock.daily.first"),
          during: DeviceActivitySchedule(
            intervalStart: dateComponents(for: schedule.morningLockMinutes),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
          )
        )
        try center.startMonitoring(
          DeviceActivityName("goal_lock.daily.second"),
          during: DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: dateComponents(for: schedule.reflectionLockMinutes),
            repeats: true
          )
        )
      }
    } catch {
      refreshNow()
    }
  }

  static func stopMonitoring() {
    DeviceActivityCenter().stopMonitoring()
  }

  static func scheduleRemindersIfAuthorized() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      guard settings.authorizationStatus == .authorized else {
        return
      }
      guard let schedule = GoalLockSharedState.loadSchedule() else {
        return
      }
      let center = UNUserNotificationCenter.current()
      center.removePendingNotificationRequests(withIdentifiers: [
        "goal_lock.morning",
        "goal_lock.noon",
        "goal_lock.evening",
      ])

      let morning = makeContent(
        title: "Goal Lock",
        body: "Morning lock is live. Name the one move that matters today."
      )
      let noon = makeContent(
        title: "Goal Lock",
        body: "Noon check-in. Are you still on the one thing?"
      )
      let evening = makeContent(
        title: "Goal Lock",
        body: "Evening reflection. Did you do it?"
      )
      let requests = [
        UNNotificationRequest(
          identifier: "goal_lock.morning",
          content: morning,
          trigger: UNCalendarNotificationTrigger(
            dateMatching: dateComponents(for: schedule.morningLockMinutes),
            repeats: true
          )
        ),
        UNNotificationRequest(
          identifier: "goal_lock.noon",
          content: noon,
          trigger: UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: 12, minute: 0),
            repeats: true
          )
        ),
        UNNotificationRequest(
          identifier: "goal_lock.evening",
          content: evening,
          trigger: UNCalendarNotificationTrigger(
            dateMatching: dateComponents(for: schedule.reflectionLockMinutes),
            repeats: true
          )
        ),
      ]
      requests.forEach { request in
        center.add(request)
      }
    }
  }

  static func clearNotifications() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(
      withIdentifiers: [
        "goal_lock.morning",
        "goal_lock.noon",
        "goal_lock.evening",
      ]
    )
  }

  private static func makeContent(title: String, body: String) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    return content
  }

  private static func dateComponents(for minutes: Int) -> DateComponents {
    DateComponents(hour: minutes / 60, minute: minutes % 60)
  }

  private static func isWithinFocusWindow(_ schedule: GoalLockSchedule) -> Bool {
    let calendar = Calendar.current
    let now = Date()
    let hour = calendar.component(.hour, from: now)
    let minute = calendar.component(.minute, from: now)
    let nowMinutes = (hour * 60) + minute
    if schedule.morningLockMinutes < schedule.reflectionLockMinutes {
      return nowMinutes >= schedule.morningLockMinutes &&
        nowMinutes < schedule.reflectionLockMinutes
    }
    return nowMinutes >= schedule.morningLockMinutes ||
      nowMinutes < schedule.reflectionLockMinutes
  }
}
