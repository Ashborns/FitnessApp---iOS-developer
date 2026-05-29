// NotificationManager — schedules daily workout and goal reminders via UNUserNotificationCenter

import Foundation
import UserNotifications

enum ReminderCategory: String {
    case workout = "workout_reminder"
    case goal = "goal_reminder"
}

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var workoutReminderEnabled: Bool = false
    @Published var goalReminderEnabled: Bool = false
    @Published var workoutReminderTime: Date
    @Published var goalReminderTime: Date
    @Published var permissionGranted: Bool = false
    @Published var permissionDenied: Bool = false

    private let notificationCenter: UNUserNotificationCenter

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter

        // Default workout reminder: 08:00
        var workoutComponents = DateComponents()
        workoutComponents.hour = 8
        workoutComponents.minute = 0
        self.workoutReminderTime = Calendar.current.date(from: workoutComponents) ?? Date()

        // Default goal reminder: 20:00
        var goalComponents = DateComponents()
        goalComponents.hour = 20
        goalComponents.minute = 0
        self.goalReminderTime = Calendar.current.date(from: goalComponents) ?? Date()
    }

    // MARK: - Permission

    func requestPermission() async {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            permissionGranted = granted
            permissionDenied = !granted
        } catch {
            permissionGranted = false
            permissionDenied = true
        }
    }

    func checkCurrentPermission() async {
        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            permissionGranted = true
            permissionDenied = false
        case .denied:
            permissionGranted = false
            permissionDenied = true
        default:
            permissionGranted = false
            permissionDenied = false
        }
    }

    // MARK: - Schedule

    func scheduleWorkoutReminder() {
        scheduleDaily(
            category: .workout,
            time: workoutReminderTime,
            title: "Workout Reminder",
            body: "Time to get moving! Your daily workout is waiting."
        )
    }

    func scheduleGoalReminder() {
        scheduleDaily(
            category: .goal,
            time: goalReminderTime,
            title: "Goal Reminder",
            body: "Check your calorie goal progress before the day ends."
        )
    }

    // MARK: - Cancel

    func cancelReminders(category: ReminderCategory) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [category.rawValue])
    }

    // MARK: - Private

    private func scheduleDaily(category: ReminderCategory, time: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category.rawValue

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: category.rawValue,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { _ in }
    }
}
