# HabitGarden — "you missed yesterday" nudge (full files, new parts highlighted)

Same feature as before, just shown as complete files this time so you can see exactly where each addition sits in context. Every new block is wrapped like this so it's easy to spot:

```swift
// ▼▼▼ NEW — missed-yesterday nudge ▼▼▼
...
// ▲▲▲ END NEW ▲▲▲
```

Everything outside those markers is unchanged from what you already have.

---

## 1. `StreakCalculator.swift` — full file

```swift
//
//  StreakCalculator.swift
//  HabitGarden
//
//  Created by Ibrahim Jasim Alsalih on 2026-04-30.
//

import Foundation

// Calculates streaks and daily completion status for habits
struct StreakCalculator {

    // Returns how many consecutive days the habit was completed (e.g. "5 day streak")
    static func currentStreak(for habit: Habit) -> Int {
        let calendar = Calendar.current

        // Group completions by day
        let perDay = Dictionary(grouping: habit.completions) {
            calendar.startOfDay(for: $0.date)
        }

        // Only count days where the user hit their target (e.g. 3/3 times)
        let completedDays = Set(perDay.filter { $0.value.count >= habit.targetPerDay }.keys)

        var day = calendar.startOfDay(for: .now)

        // If the user hasn't completed today yet, don't break their streak —
        // start counting from yesterday instead
        if !completedDays.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }

        // Walk backwards day by day until we find a gap
        var streak = 0
        while completedDays.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }

        return streak
    }

    // Returns how many times the habit was completed today (e.g. 2 out of 3)
    static func isCompletedToday(_ completions: [HabitCompletion]) -> Int {
        let today = Calendar.current.startOfDay(for: .now)
        return completions.filter {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }.count
    }

    // Returns true if the habit has fully met its daily target today
    static func isCompletedToday(_ habit: Habit) -> Bool {
        isCompletedToday(habit.completions) >= habit.targetPerDay
    }

    // ▼▼▼ NEW — missed-yesterday nudge ▼▼▼
    // Returns true if the habit's daily target was met yesterday.
    static func wasCompletedYesterday(_ habit: Habit) -> Bool {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) else { return false }
        let start = calendar.startOfDay(for: yesterday)
        let count = habit.completions.filter { calendar.isDate($0.date, inSameDayAs: start) }.count
        return count >= habit.targetPerDay
    }
    // ▲▲▲ END NEW ▲▲▲
}
```

---

## 2. `NotificationManager.swift` — full file

```swift
//
//  NotificationManager.swift
//  HabitGarden
//
//  Created by Ibrahim Jasim Alsalih on 2026-05-06.
//

import Foundation
import UserNotifications

// Manages push notifications — daily reminders for each habit
struct NotificationManager {

    // Asks the user for permission to show notifications (called once on app launch)
    static func requestNotificationPermission() async {
        do {
            try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("Notification permission request failed: \(error)")
        }
    }

    // Schedules a repeating daily notification at the chosen time
    static func schedule(habitId: String, name: String, emoji: String, time: Date) {
        // Build the notification content (what the user sees)
        let content = UNMutableNotificationContent()
        content.title = emoji.isEmpty ? "Habit reminder" : "\(emoji) \(name)"
        content.body = "Did you complete your \(name) today?"
        content.sound = .default

        // Extract hour and minute so it repeats every day at the same time
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        // Use the habit's ID so we can cancel this specific notification later
        let request = UNNotificationRequest(identifier: habitId, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print ("Error scheduling notification: \(error)")

            }
        }
    }

    // ▼▼▼ NEW — missed-yesterday nudge ▼▼▼
    // Schedules a one-time "you missed it" nudge for a habit if it wasn't
    // completed yesterday. Cancels any pending nudge if it was completed.
    static func rescheduleMissedYesterdayNudge(
        habitId: String,
        name: String,
        emoji: String,
        reminderTime: Date,
        missedYesterday: Bool
    ) {
        let nudgeId = "\(habitId)-missed"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [nudgeId])

        guard missedYesterday else { return }

        let content = UNMutableNotificationContent()
        content.title = emoji.isEmpty ? "You missed a day" : "\(emoji) \(name)"
        content.body = "You didn't complete \(name) yesterday — don't let it slip again today."
        content.sound = .default

        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: nudgeId, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Error scheduling missed-day nudge: \(error)") }
        }
    }
    // ▲▲▲ END NEW ▲▲▲

    // Cancels the daily reminder and any pending missed-day nudge for a habit
    // ▼▼▼ CHANGED — now also clears the "-missed" nudge, not just the daily reminder ▼▼▼
    static func cancel(habitId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [habitId, "\(habitId)-missed"]
        )
    }
    // ▲▲▲ END CHANGED ▲▲▲

}
```

---

## 3. `HabitListView.swift` — full file

```swift
//
//  HabitListView.swift
//  HabitGarden
//

import SwiftUI
import SwiftData

struct HabitListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AuthViewModel.self) private var auth
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @State private var viewModel = HabitListViewModel()
    @State private var showAddSheet = false
    @State private var showDeleteAccountConfirm = false

    private var userHabits: [Habit] {
        guard let userId = auth.currentUser?.id else { return [] }
        return habits.filter { $0.userId == userId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BaseplateBackground()

                VStack(spacing: 0) {
                    header

                    if userHabits.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            "No habits yet",
                            systemImage: "leaf",
                            description: Text("Tap + to add your first habit.")
                        )
                        Spacer()
                    } else {
                        List {
                            ForEach(userHabits) { habit in
                                NavigationLink(destination: HabitDetailView(habit: habit)) {
                                    HabitRow(habit: habit) {
                                        viewModel.toggle(habit: habit, context: context)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    viewModel.delete(habit: userHabits[index], context: context)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            // ▼▼▼ NEW — missed-yesterday nudge ▼▼▼
            .onAppear {
                for habit in userHabits {
                    guard let reminderTime = habit.reminderTime else { continue }
                    NotificationManager.rescheduleMissedYesterdayNudge(
                        habitId: habit.id.uuidString,
                        name: habit.name,
                        emoji: habit.emoji,
                        reminderTime: reminderTime,
                        missedYesterday: !StreakCalculator.wasCompletedYesterday(habit)
                    )
                }
            }
            // ▲▲▲ END NEW ▲▲▲
            .sheet(isPresented: $showAddSheet) {
                AddHabitView(viewModel: viewModel)
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showDeleteAccountConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    auth.deleteAccount(context: context)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your habits and your account. This can't be undone.")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Habits").font(.brickTitle(30)).foregroundStyle(Brick.ink)
                Text("\(userHabits.count) growing today")
                    .font(.brickBody(14)).foregroundStyle(Brick.ink.opacity(0.75))
            }
            Spacer()
            HStack(spacing: 8) {
                NavigationLink { InsightsView() } label: {
                    iconGlyph("chart.bar.fill", tint: Brick.blue)
                }
                NavigationLink { GardenView() } label: {
                    iconGlyph("leaf.fill", tint: Brick.green)
                }
                Menu {
                    Button { auth.signOut() } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    Button(role: .destructive) { showDeleteAccountConfirm = true } label: {
                        Label("Delete Account", systemImage: "trash")
                    }
                } label: {
                    iconGlyph("person.crop.circle", tint: Brick.white)
                }
                Button { showAddSheet = true } label: {
                    iconGlyph("plus", tint: Brick.yellow)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private func iconGlyph(_ systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(tint.brickTextColor)
            .frame(width: 40, height: 40)
            .brickCard(fill: tint, cornerRadius: 11, borderWidth: 2.5, shadowOffset: 4)
            .overlay(BrickStuds(count: 2, diameter: 7, color: tint), alignment: .top)
    }
}

// A single habit card — colored by the habit's own colorHex.
struct HabitRow: View {
    let habit: Habit
    let onToggle: () -> Void

    private var cardColor: Color { Color(hex: habit.colorHex) }
    private var textColor: Color { cardColor.brickTextColor }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Brick.white)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brick.ink, lineWidth: 2))
                if habit.emoji.isEmpty {
                    Image(systemName: "circle.dashed").foregroundStyle(.secondary)
                } else {
                    Text(habit.emoji).font(.system(size: 26))
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(habit.name).font(.brickHeading(17)).foregroundStyle(textColor)
                    if habit.reminderTime != nil {
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                            .foregroundStyle(textColor.opacity(0.85))
                    }
                }
                Text("🔥 \(StreakCalculator.currentStreak(for: habit)) day streak")
                    .font(.brickBody(13))
                    .foregroundStyle(textColor.opacity(0.92))
                if habit.targetPerDay > 1 {
                    Text("\(StreakCalculator.isCompletedToday(habit.completions))/\(habit.targetPerDay)")
                        .font(.brickBodyHeavy(11))
                        .foregroundStyle(textColor.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Brick.ink.opacity(0.18)))
                }
            }

            Spacer()

            Button(action: onToggle) {
                Image(systemName: StreakCalculator.isCompletedToday(habit)
                      ? "checkmark"
                      : (habit.targetPerDay > 1 ? "plus" : "circle"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Brick.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Brick.white))
                    .overlay(Circle().stroke(Brick.ink, lineWidth: 2.5))
                    .compositingGroup()
                    .shadow(color: Brick.ink, radius: 0, x: 3, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .brickCard(fill: cardColor, cornerRadius: 18, borderWidth: 3, shadowOffset: 5)
        .overlay(BrickStuds(count: 3, diameter: 10, color: cardColor), alignment: .top)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
    }
}

#Preview {
    HabitListView()
        .modelContainer(for: [Habit.self, HabitCompletion.self], inMemory: true)
}
```

---

Copy each file over as a whole, or just drop in the highlighted blocks at the matching spot in what you already have — both get you to the same place.
