import FamilyControls
import Flutter
import SwiftUI
import UIKit
import UserNotifications

final class GoalLockPlatformPlugin: NSObject, FlutterPlugin {
  private var pickerResult: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "goal_lock/platform",
      binaryMessenger: registrar.messenger()
    )
    let instance = GoalLockPlatformPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getStatus":
      buildStatus(result: result)
    case "requestPlatformAuthorization":
      requestPlatformAuthorization(result: result)
    case "requestNotificationPermission":
      requestNotificationPermission(result: result)
    case "pickBlockedApps":
      presentPicker(result: result)
    case "configureSchedule":
      configureSchedule(call.arguments, result: result)
    case "clearSetup":
      GoalLockShieldController.stopMonitoring()
      GoalLockShieldController.clear()
      GoalLockShieldController.clearNotifications()
      GoalLockSharedState.clearAll()
      result(nil)
    case "openUsageAccessSettings":
      buildStatus(result: result)
    case "detectSlip":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestPlatformAuthorization(result: @escaping FlutterResult) {
    #if targetEnvironment(simulator)
      buildStatus(result: result)
      return
    #endif
    requestAuthorizationIfNeeded { authResult in
      switch authResult {
      case .success:
        GoalLockShieldController.refreshNow()
        self.buildStatus(result: result)
      case .failure(let error):
        result(
          FlutterError(
            code: "authorization_failed",
            message: self.authorizationErrorMessage(error),
            details: nil
          )
        )
      }
    }
  }

  private func requestNotificationPermission(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { _, _ in
      GoalLockShieldController.scheduleRemindersIfAuthorized()
      self.buildStatus(result: result)
    }
  }

  private func configureSchedule(_ rawArguments: Any?, result: @escaping FlutterResult) {
    #if targetEnvironment(simulator)
      result(nil)
      return
    #endif
    guard
      let arguments = rawArguments as? [String: Any],
      let morningLockMinutes = arguments["morningLockMinutes"] as? Int,
      let reflectionLockMinutes = arguments["reflectionLockMinutes"] as? Int,
      let focusWindowHours = arguments["focusWindowHours"] as? Int
    else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "Missing schedule arguments.",
          details: nil
        )
      )
      return
    }

    let schedule = GoalLockSchedule(
      morningLockMinutes: morningLockMinutes,
      reflectionLockMinutes: reflectionLockMinutes,
      focusWindowHours: focusWindowHours
    )
    GoalLockSharedState.saveSchedule(schedule)
    GoalLockShieldController.startMonitoring()
    GoalLockShieldController.refreshNow()
    GoalLockShieldController.scheduleRemindersIfAuthorized()
    result(nil)
  }

  private func presentPicker(result: @escaping FlutterResult) {
    #if targetEnvironment(simulator)
      buildStatus(result: result)
      return
    #endif
    guard #available(iOS 16.0, *) else {
      buildStatus(result: result)
      return
    }
    requestAuthorizationIfNeeded { authResult in
      switch authResult {
      case .success:
        self.presentAuthorizedPicker(result: result)
      case .failure(let error):
        result(
          FlutterError(
            code: "authorization_failed",
            message: self.authorizationErrorMessage(error),
            details: nil
          )
        )
      }
    }
  }

  private func requestAuthorizationIfNeeded(
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    guard #available(iOS 16.0, *) else {
      completion(.success(()))
      return
    }
    if AuthorizationCenter.shared.authorizationStatus == .approved {
      completion(.success(()))
      return
    }
    Task {
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        DispatchQueue.main.async {
          completion(.success(()))
        }
      } catch {
        DispatchQueue.main.async {
          completion(.failure(error))
        }
      }
    }
  }

  private func presentAuthorizedPicker(result: @escaping FlutterResult) {
    guard pickerResult == nil else {
      result(
        FlutterError(
          code: "picker_busy",
          message: "The app picker is already open.",
          details: nil
        )
      )
      return
    }
    guard let controller = topViewController() else {
      result(
        FlutterError(
          code: "missing_view_controller",
          message: "Could not present the app picker.",
          details: nil
        )
      )
      return
    }

    pickerResult = result
    let currentSelection = GoalLockSharedState.loadSelection()
    let picker = GoalLockPickerHostController(initialSelection: currentSelection) {
      selection in
      GoalLockSharedState.saveSelection(selection)
      GoalLockShieldController.startMonitoring()
      GoalLockShieldController.refreshNow()
      GoalLockShieldController.scheduleRemindersIfAuthorized()
      self.finishPicker()
    } onCancel: {
      self.finishPicker()
    }
    controller.present(picker, animated: true)
  }

  private func authorizationErrorMessage(_ error: Error) -> String {
    let detail = error.localizedDescription.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    let base =
      "Goal Lock could not open the Screen Time permission prompt. If this is a local iPhone build, it may not be signed with the Family Controls capability."
    guard !detail.isEmpty else {
      return base
    }
    return "\(base) \(detail)"
  }

  private func finishPicker() {
    guard let result = pickerResult else {
      return
    }
    pickerResult = nil
    buildStatus(result: result)
  }

  private func buildStatus(result: @escaping FlutterResult) {
    #if targetEnvironment(simulator)
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        result([
          "supported": false,
          "canBlockApps": false,
          "canDetectUsage": false,
          "platformAuthorizationGranted": false,
          "notificationsGranted": settings.authorizationStatus == .authorized,
          "usageAccessGranted": false,
          "selectedAppsCount": 0,
          "installedApps": [],
        ])
      }
      return
    #endif
    let authorizationGranted: Bool
    if #available(iOS 16.0, *) {
      authorizationGranted = AuthorizationCenter.shared.authorizationStatus == .approved
    } else {
      authorizationGranted = false
    }
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      GoalLockShieldController.refreshNow()
      result([
        "supported": true,
        "canBlockApps": true,
        "canDetectUsage": false,
        "platformAuthorizationGranted": authorizationGranted,
        "notificationsGranted": settings.authorizationStatus == .authorized,
        "usageAccessGranted": false,
        "selectedAppsCount": GoalLockSharedState.selectedAppsCount(),
        "installedApps": [],
      ])
    }
  }

  private func topViewController(
    base: UIViewController? = UIApplication.shared
      .connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController
  ) -> UIViewController? {
    if let nav = base as? UINavigationController {
      return topViewController(base: nav.visibleViewController)
    }
    if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
      return topViewController(base: selected)
    }
    if let presented = base?.presentedViewController {
      return topViewController(base: presented)
    }
    return base
  }
}

@available(iOS 16.0, *)
private struct GoalLockPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selection: FamilyActivitySelection
  let onDone: (FamilyActivitySelection) -> Void
  let onCancel: () -> Void

  init(
    initialSelection: FamilyActivitySelection,
    onDone: @escaping (FamilyActivitySelection) -> Void,
    onCancel: @escaping () -> Void
  ) {
    _selection = State(initialValue: initialSelection)
    self.onDone = onDone
    self.onCancel = onCancel
  }

  var body: some View {
    NavigationStack {
      FamilyActivityPicker(selection: $selection)
        .navigationTitle("Apps to shield")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              dismiss()
              onCancel()
            }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
              dismiss()
              onDone(selection)
            }
          }
        }
    }
  }
}

@available(iOS 16.0, *)
private final class GoalLockPickerHostController:
  UIHostingController<GoalLockPickerView>
{
  init(
    initialSelection: FamilyActivitySelection,
    onDone: @escaping (FamilyActivitySelection) -> Void,
    onCancel: @escaping () -> Void
  ) {
    super.init(
      rootView: GoalLockPickerView(
        initialSelection: initialSelection,
        onDone: onDone,
        onCancel: onCancel
      )
    )
  }

  @objc required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
