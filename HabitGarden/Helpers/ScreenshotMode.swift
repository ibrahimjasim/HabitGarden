//
//  ScreenshotMode.swift
//  HabitGarden
//
//  DEBUG-only helper used by scripts/take-screenshots.sh.
//  Launch the app with `-screenshot <screen>` and it opens straight on that
//  screen, filled with demo data in an in-memory store (your real data is
//  never touched). Not compiled into Release / App Store builds.
//

#if DEBUG
import SwiftUI
import SwiftData

enum ScreenshotScreen: String, CaseIterable {
    case login
    case habits
    case addHabit = "add-habit"
    case emojiPicker = "emoji-picker"
    case habitDetail = "habit-detail"
    case garden
    case insights
    case empty
}

enum ScreenshotMode {
    static let screen: ScreenshotScreen? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screenshot"), args.indices.contains(i + 1) else { return nil }
        return ScreenshotScreen(rawValue: args[i + 1])
    }()

    static var isActive: Bool { screen != nil }
}

struct ScreenshotRootView: View {
    let screen: ScreenshotScreen
    let auth: AuthViewModel

    @Environment(\.modelContext) private var context
    @State private var ready = false
    @State private var featured: Habit?
    @State private var pickedEmoji = "🌱"

    var body: some View {
        Group {
            if ready { content } else { Color.clear }
        }
        .task { prepare() }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .login:
            LoginView(auth: auth)
        case .habits, .empty:
            HabitListView()
        case .addHabit:
            HabitListView()
                .sheet(isPresented: .constant(true)) {
                    AddHabitView(viewModel: HabitListViewModel())
                }
        case .emojiPicker:
            HabitListView()
                .sheet(isPresented: .constant(true)) {
                    EmojiPickerView(selectedEmoji: $pickedEmoji)
                }
        case .habitDetail:
            NavigationStack {
                if let featured { HabitDetailView(habit: featured) }
            }
        case .garden:
            NavigationStack { GardenView() }
        case .insights:
            NavigationStack { InsightsView() }
        }
    }

    private func prepare() {
        guard !ready else { return }
        if screen == .login {
            auth.debugSetSession(nil)
            ready = true
            return
        }
        let account = AppAccount(email: "demo@habitgarden.app", name: "Alex", passwordHash: "")
        context.insert(account)
        let userId = account.id.uuidString
        auth.debugSetSession(AppUser(id: userId, name: account.name, email: account.email))
        if screen != .empty {
            featured = DemoData.seed(userId: userId, context: context)
        }
        try? context.save()
        ready = true
    }
}

// Realistic sample habits with ~3 weeks of history so streaks, garden
// growth and insights all have something to show.
enum DemoData {
    private struct Spec {
        let name: String
        let emoji: String
        let color: String
        let target: Int
        let hour: Int          // typical time of day it gets done
        let streak: Int        // consecutive days ending yesterday
        let doneToday: Int     // completions already logged today
        let reminderHour: Int?
    }

    private static let specs: [Spec] = [
        Spec(name: "Morning walk", emoji: "🏃", color: "#33AE64", target: 1, hour: 7,  streak: 12, doneToday: 1, reminderHour: 7),
        Spec(name: "Drink water",  emoji: "💧", color: "#3E86F0", target: 3, hour: 13, streak: 9,  doneToday: 2, reminderHour: nil),
        Spec(name: "Read 20 pages", emoji: "📚", color: "#F5B72E", target: 1, hour: 21, streak: 5,  doneToday: 0, reminderHour: 21),
        Spec(name: "Meditate",     emoji: "🧘", color: "#8C5CF5", target: 1, hour: 6,  streak: 3,  doneToday: 1, reminderHour: nil),
        Spec(name: "Sleep by 11",  emoji: "💤", color: "#E8483C", target: 1, hour: 22, streak: 1,  doneToday: 0, reminderHour: nil),
    ]

    @discardableResult
    static func seed(userId: String, context: ModelContext) -> Habit? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var first: Habit?

        for (index, spec) in specs.enumerated() {
            let habit = Habit(name: spec.name, emoji: spec.emoji, colorHex: spec.color,
                              targetPerDay: spec.target, userId: userId)
            habit.createdAt = cal.date(byAdding: .day, value: -21, to: today) ?? today
            if let h = spec.reminderHour {
                habit.reminderTime = cal.date(bySettingHour: h, minute: 0, second: 0, of: today)
            }
            context.insert(habit)

            for offset in 0...21 {
                let count: Int
                if offset == 0 {
                    count = spec.doneToday
                } else if offset <= spec.streak {
                    count = spec.target
                } else if offset == spec.streak + 1 {
                    count = 0                                  // the day the streak started
                } else {
                    count = (offset + index) % 3 == 0 ? 0 : spec.target
                }
                guard count > 0, let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                for n in 0..<count {
                    let hour = min(spec.hour + n * 3, 23)
                    let date = cal.date(bySettingHour: hour, minute: 15 * n, second: 0, of: day) ?? day
                    // Keep today's completions in the past so nothing is "in the future".
                    let completion = HabitCompletion(date: offset == 0 ? min(date, .now) : date)
                    completion.habit = habit
                    context.insert(completion)
                }
            }
            if first == nil { first = habit }
        }
        return first
    }
}
#endif
