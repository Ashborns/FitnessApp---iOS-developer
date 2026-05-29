// NotificationSettingsView — Settings screen for workout and goal reminder notifications

import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationManager = NotificationManager()

    var body: some View {
        Form {
            if notificationManager.permissionDenied {
                permissionDeniedSection
            } else {
                workoutReminderSection
                goalReminderSection
            }
        }
        .navigationTitle("Notifications")
        .task {
            await notificationManager.requestPermission()
        }
    }

    // MARK: - Permission Denied

    @ViewBuilder
    private var permissionDeniedSection: some View {
        Section {
            VStack(spacing: .spacingLarge) {
                Image(systemName: "bell.slash.fill")
                    .font(.largeTitle)
                    .foregroundColor(.themeError)
                    .accessibilityHidden(true)

                Text("Notifications are disabled")
                    .font(.headline)

                Text("Enable notifications in Settings to receive workout and goal reminders.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    openAppSettings()
                } label: {
                    Text("Open Settings")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .spacingMedium)
                }
                .buttonStyle(.borderedProminent)
                .tint(.themePrimary)
                .accessibilityLabel("Open Settings")
                .accessibilityIdentifier("openSettingsButton")
            }
            .padding(.vertical, .spacingLarge)
        }
    }

    // MARK: - Workout Reminder

    @ViewBuilder
    private var workoutReminderSection: some View {
        Section {
            Toggle(isOn: $notificationManager.workoutReminderEnabled) {
                Label("Workout Reminder", systemImage: "figure.run")
            }
            .tint(.themePrimary)
            .accessibilityLabel("Workout Reminder")
            .accessibilityIdentifier("workoutReminderToggle")
            .onChange(of: notificationManager.workoutReminderEnabled) { enabled in
                if enabled {
                    notificationManager.scheduleWorkoutReminder()
                } else {
                    notificationManager.cancelReminders(category: .workout)
                }
            }

            if notificationManager.workoutReminderEnabled {
                DatePicker(
                    "Reminder Time",
                    selection: $notificationManager.workoutReminderTime,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityLabel("Workout reminder time")
                .accessibilityIdentifier("workoutReminderTimePicker")
                .onChange(of: notificationManager.workoutReminderTime) { _ in
                    notificationManager.scheduleWorkoutReminder()
                }
            }
        } header: {
            Text("Workout")
                .foregroundColor(.themeSecondary)
        }
    }

    // MARK: - Goal Reminder

    @ViewBuilder
    private var goalReminderSection: some View {
        Section {
            Toggle(isOn: $notificationManager.goalReminderEnabled) {
                Label("Goal Reminder", systemImage: "target")
            }
            .tint(.themePrimary)
            .accessibilityLabel("Goal Reminder")
            .accessibilityIdentifier("goalReminderToggle")
            .onChange(of: notificationManager.goalReminderEnabled) { enabled in
                if enabled {
                    notificationManager.scheduleGoalReminder()
                } else {
                    notificationManager.cancelReminders(category: .goal)
                }
            }

            if notificationManager.goalReminderEnabled {
                DatePicker(
                    "Reminder Time",
                    selection: $notificationManager.goalReminderTime,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityLabel("Goal reminder time")
                .accessibilityIdentifier("goalReminderTimePicker")
                .onChange(of: notificationManager.goalReminderTime) { _ in
                    notificationManager.scheduleGoalReminder()
                }
            }
        } header: {
            Text("Goals")
                .foregroundColor(.themeSecondary)
        }
    }

    // MARK: - Helpers

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#if DEBUG
struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NotificationSettingsView()
        }
    }
}
#endif
