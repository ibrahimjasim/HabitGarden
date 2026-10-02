# HabitGarden — "you missed yesterday" nudge

Adds a second kind of notification alongside the existing daily reminder: a one-time nudge that only fires if you didn't complete a habit yesterday. Your existing daily reminder is untouched — this is additive.

**How it decides "yesterday":** since HabitGarden has no server or background job, there's no true midnight check. Instead, the check runs whenever the Habits screen appears (app launch, or logging in) — the closest realistic stand-in for "once a day" without adding background task infrastructure. If you open the app once in a typical day, this covers it.

**One thing worth knowing:** the nudge fires at the same time as your habit's existing daily reminder (to keep this simple — no second time picker to build). On a day you missed the habit, you could get two notifications close together: the regular "did you do X today?" and the new "you missed X yesterday" one. If that ends up feeling redundant once you see it in practice, say so and I'll fold them into a single smarter message instead.

---

## 1. `StreakCalculator.swift` — add this method inside the `struct`

```swift
// Returns true if the habit's daily target was met yesterday.
static func wasCompletedYesterday(_ habit: Habit) -> Bool {
    let calendar = Calendar.current
    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) else { return false }
    let start = calendar.startOfDay(for: yesterday)
    let count = habit.completions.filter { calendar.isDate($0.date, inSameDayAs: start) }.count
    return count >= habit.targetPerDay
}
```

## 2. `NotificationManager.swift` — add this method, and update `cancel`

Add:

```swift
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
```

Replace the existing `cancel` method with this (it now also clears any pending nudge, so deleting a habit doesn't leave one behind):

```swift
// Cancels the daily reminder and any pending missed-day nudge for a habit
static func cancel(habitId: String) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(
        withIdentifiers: [habitId, "\(habitId)-missed"]
    )
}
```

## 3. `HabitListView.swift` — add one `.onAppear`

In the `NavigationStack`'s body, right after `.toolbar(.hidden, for: .navigationBar)` (order relative to the other modifiers doesn't matter, this is just a clear spot), add:

```swift
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
```

Only habits with a reminder time set get a nudge — matches the existing rule that reminders are opt-in per habit.

That's it — three edits, no new files, `BrickTheme.swift` and the visual work are untouched.
