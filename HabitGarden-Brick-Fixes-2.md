# HabitGarden — Garden fix + Insights restyle

## What was wrong in Garden

1. **"Starts in the middle"** — the `ZStack(alignment: .bottom)` holding the ground + trees never got told to fill the screen, so SwiftUI sized it to just fit its own content (~300pt) and centered that short block in the middle of the full-height screen. The pale green you saw below it was the tail end of the sky gradient showing through the empty space underneath.
2. **"Sun disappeared"** — it was never actually in the SwiftUI code. The mockup had one, but Step 4's code only ported over the ground/trees/header, not the sun. My mistake — added back below.
3. **"No back button"** — `.toolbar(.hidden, for: .navigationBar)` removes the *entire* nav bar, back button included, since GardenView is a pushed screen (not the root). Fixed with a small custom back button in the header, same brick style as everything else.

Replace `GardenView.swift` with the file below.

## GardenView.swift (replace the whole file)

```swift
//
//  GardenView.swift
//  HabitGarden
//

import SwiftUI
import SwiftData

struct GardenView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Habit.createdAt) private var habits: [Habit]

    private var userHabits: [Habit] {
        guard let userId = auth.currentUser?.id else { return [] }
        return habits.filter { $0.userId == userId }
    }

    private let maxTrunkBricks = 8

    var body: some View {
        ZStack {
            skyGradient.ignoresSafeArea()

            sun

            ZStack(alignment: .bottom) {
                ground

                if userHabits.isEmpty {
                    ContentUnavailableView(
                        "Your garden is empty",
                        systemImage: "leaf.circle",
                        description: Text("Add a habit to plant your first seed.")
                    )
                    .padding(.bottom, 100)
                } else {
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(userHabits) { habit in
                            Spacer(minLength: 4)
                            treeView(for: habit)
                        }
                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 78)
                }
            }
            // The fix: force this block to fill all available height and pin
            // its content to the bottom, instead of letting it hug its own
            // (much shorter) content height and get centered by the outer ZStack.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)

            VStack {
                topBar
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Top bar (back button + title)

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            backButton
            VStack(alignment: .leading, spacing: 2) {
                Text("Garden").font(.brickTitle(28)).foregroundStyle(Brick.ink)
                Text("Brick by brick — bloom when you hit your goal")
                    .font(.brickBody(14)).foregroundStyle(Brick.ink.opacity(0.75))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Brick.ink)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Brick.white))
                .overlay(Circle().stroke(Brick.ink, lineWidth: 2.5))
                .compositingGroup()
                .shadow(color: Brick.ink, radius: 0, x: 3, y: 3)
        }
    }

    // MARK: - Sky, sun, ground

    private var sun: some View {
        GeometryReader { proxy in
            Circle()
                .fill(Brick.yellow)
                .overlay(Circle().stroke(Brick.ink, lineWidth: 3))
                .compositingGroup()
                .shadow(color: Brick.ink, radius: 0, x: 5, y: 5)
                .frame(width: 64, height: 64)
                .position(x: proxy.size.width - 68, y: 108)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private var skyGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#5EC8F2"), Color(hex: "#8ED8F5"),
                Color(hex: "#BDE8D8"), Color(hex: "#9FDBA8"), Color(hex: "#7FCB86")
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var ground: some View {
        Rectangle()
            .fill(Brick.green)
            .overlay(Rectangle().frame(height: 3).foregroundStyle(Brick.ink), alignment: .top)
            .frame(height: 210)
    }

    // MARK: - Tree stage

    private enum TreeStage {
        case seed
        case growing(bricks: Int)
        case bloomed(bricks: Int)
    }

    private func stage(for habit: Habit) -> TreeStage {
        if let goal = habit.goalDays {
            let completed = daysCompleted(for: habit)
            if completed >= goal {
                return .bloomed(bricks: min(goal, maxTrunkBricks))
            } else if completed == 0 {
                return .seed
            } else {
                return .growing(bricks: min(completed, maxTrunkBricks))
            }
        } else {
            let streak = StreakCalculator.currentStreak(for: habit)
            if streak == 0 { return .seed }
            return .growing(bricks: min(streak, maxTrunkBricks))
        }
    }

    // Same "days meeting target since creation" definition HabitDetailView
    // already uses for goal progress, kept consistent here.
    private func daysCompleted(for habit: Habit) -> Int {
        let calendar = Calendar.current
        let perDay = Dictionary(grouping: habit.completions) { calendar.startOfDay(for: $0.date) }
        return perDay.filter { $0.value.count >= habit.targetPerDay }.count
    }

    // MARK: - Tree drawing

    @ViewBuilder
    private func treeView(for habit: Habit) -> some View {
        let streak = StreakCalculator.currentStreak(for: habit)
        VStack(spacing: 0) {
            switch stage(for: habit) {
            case .seed:
                seedView
            case .growing(let bricks):
                trunkView(count: bricks)
            case .bloomed(let bricks):
                VStack(spacing: 2) {
                    canopyView
                    trunkView(count: bricks, showTopStuds: false)
                }
            }
            label(for: habit, streak: streak)
                .padding(.top, 10)
        }
    }

    private var seedView: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 9)
                .fill(Brick.brown)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Brick.ink, lineWidth: 2))
                .frame(width: 22, height: 15)
            Capsule()
                .fill(Brick.green)
                .overlay(Capsule().stroke(Brick.ink, lineWidth: 1.5))
                .frame(width: 7, height: 11)
                .rotationEffect(.degrees(-6))
                .offset(y: -9)
        }
        .compositingGroup()
        .shadow(color: Brick.ink, radius: 0, x: 2, y: 2)
    }

    private func trunkView(count: Int, showTopStuds: Bool = true) -> some View {
        VStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 8)
                    .fill(Brick.brown)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brick.ink, lineWidth: 2.5))
                    .frame(width: 52, height: 24)
                    .compositingGroup()
                    .shadow(color: Brick.ink, radius: 0, x: 3, y: 3)
                    .overlay(
                        (showTopStuds && i == count - 1)
                            ? AnyView(BrickStuds(count: 2, diameter: 9, color: Brick.brown))
                            : AnyView(EmptyView()),
                        alignment: .top
                    )
            }
        }
    }

    private var canopyView: some View {
        VStack(spacing: -7) {
            HStack(spacing: 3) {
                canopyBrick(withStud: true)
                canopyBrick(withStud: true)
            }
            HStack(spacing: 3) {
                canopyBrick(withStud: false)
                canopyBrick(withStud: false)
                canopyBrick(withStud: false)
            }
        }
    }

    private func canopyBrick(withStud: Bool) -> some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(Brick.green)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Brick.ink, lineWidth: 2))
            .frame(width: 26, height: 20)
            .compositingGroup()
            .shadow(color: Brick.ink, radius: 0, x: 2, y: 2)
            .overlay(
                withStud ? AnyView(BrickStuds(count: 1, diameter: 7, color: Brick.green)) : AnyView(EmptyView()),
                alignment: .top
            )
    }

    private func label(for habit: Habit, streak: Int) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 4) {
                Text(habit.emoji.isEmpty ? "🌱" : habit.emoji).font(.system(size: 13))
                Text(habit.name).font(.brickHeading(11.5)).foregroundStyle(Brick.ink)
            }
            switch stage(for: habit) {
            case .bloomed:
                Text("🌿 Goal reached · \(streak) days")
                    .font(.brickBodyHeavy(10)).foregroundStyle(Brick.ink.opacity(0.8))
            case .seed:
                Text("🌰 Just planted")
                    .font(.brickBodyHeavy(10)).foregroundStyle(Brick.ink.opacity(0.8))
            case .growing:
                if let goal = habit.goalDays {
                    Text("🔥 \(daysCompleted(for: habit))/\(goal) days")
                        .font(.brickBodyHeavy(10)).foregroundStyle(Brick.ink.opacity(0.8))
                } else {
                    Text("🔥 \(streak) days")
                        .font(.brickBodyHeavy(10)).foregroundStyle(Brick.ink.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .brickCard(fill: Brick.cream, cornerRadius: 12, borderWidth: 2.5, shadowOffset: 2.5)
    }
}

#Preview {
    NavigationStack { GardenView() }
        .modelContainer(for: [Habit.self, HabitCompletion.self], inMemory: true)
}
```

---

## Step 5 (new) — Restyle `InsightsView.swift`

This one wasn't part of Steps 3/4 at all, which is why it still looked like plain default SwiftUI — not a bug, just not done yet. Same treatment as the other two screens: baseplate background, brick stat cards, a brick-framed chart, brick insight cards, and a custom back button + header (same fix as Garden, applied here too since this screen is also pushed, not the root).

Replace `InsightsView.swift` with the file below. `InsightEngine.swift` and the `SmartInsight` model don't need to change — this only touches how the screen presents the data.

```swift
//
//  InsightsView.swift
//  HabitGarden
//
//  VG Track 3 — Data & Statistics with SwiftUI Charts
//

import SwiftUI
import SwiftData
import Charts

// The Insights screen — shows charts, stats, and smart insights about the user's habits
struct InsightsView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Query private var habits: [Habit]

    // Only this account's habits — keeps stats and insights private per user
    private var userHabits: [Habit] {
        guard let userId = auth.currentUser?.id else { return [] }
        return habits.filter { $0.userId == userId }
    }

    // Calculates total completions per day for the last 7 days (used by the bar chart)
    private var last7Days: [DailyCount] {
        let calendar = Calendar.current
        let allCompletions = userHabits.flatMap { $0.completions }

        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: .now)!
            let start = calendar.startOfDay(for: day)
            let count = allCompletions.filter {
                calendar.isDate($0.date, inSameDayAs: start)
            }.count
            return DailyCount(date: start, count: count)
        }
    }

    // Total completions across all habits this week
    private var weekTotal: Int {
        last7Days.reduce(0) { $0 + $1.count }
    }

    // Longest current streak across all habits
    private var bestStreak: Int {
        userHabits
            .map { StreakCalculator.currentStreak(for: $0) }
            .max() ?? 0
    }

    // Smart insights generated by analyzing habit patterns
    private var insights: [SmartInsight] {
        InsightEngine.generate(habits: userHabits)
    }

    var body: some View {
        ZStack {
            BaseplateBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    topBar

                    // MARK: Headline cards
                    HStack(spacing: 12) {
                        BrickStatCard(
                            title: "This week",
                            value: "\(weekTotal)",
                            subtitle: "completions",
                            symbol: "checkmark.seal.fill",
                            tint: Brick.green
                        )
                        BrickStatCard(
                            title: "Best streak",
                            value: "\(bestStreak)",
                            subtitle: "days",
                            symbol: "flame.fill",
                            tint: Brick.red
                        )
                    }

                    // MARK: 7-day bar chart
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Last 7 days").font(.brickHeading(17)).foregroundStyle(Brick.ink)
                        Chart(last7Days) { item in
                            BarMark(
                                x: .value("Day", item.date, unit: .day),
                                y: .value("Completed", item.count)
                            )
                            .foregroundStyle(Brick.blue)
                            .cornerRadius(6)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { value in
                                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            }
                        }
                        .frame(height: 200)
                    }
                    .padding(16)
                    .brickCard(fill: Brick.white, cornerRadius: 18, borderWidth: 2.5, shadowOffset: 4)

                    // MARK: Smart Insights
                    if !insights.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles").foregroundStyle(Brick.purple)
                                Text("Smart insights").font(.brickHeading(17)).foregroundStyle(Brick.ink)
                            }
                            ForEach(insights) { insight in
                                BrickInsightCard(insight: insight)
                            }
                        }
                    }

                    // MARK: Per-habit streaks
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Streaks per habit").font(.brickHeading(17)).foregroundStyle(Brick.ink)

                        if userHabits.isEmpty {
                            Text("Add a habit to see your stats here.")
                                .font(.brickBody(14))
                                .foregroundStyle(Brick.ink.opacity(0.6))
                        } else {
                            VStack(spacing: 10) {
                                ForEach(userHabits) { habit in
                                    HStack {
                                        Text(habit.emoji.isEmpty ? "🌱" : habit.emoji).font(.title3)
                                        Text(habit.name).font(.brickBody(15)).foregroundStyle(Brick.ink)
                                        Spacer()
                                        Text("🔥 \(StreakCalculator.currentStreak(for: habit))")
                                            .font(.brickBodyHeavy(14))
                                            .foregroundStyle(Brick.ink)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .brickCard(fill: Brick.cream, cornerRadius: 14, borderWidth: 2, shadowOffset: 3)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Brick.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Brick.white))
                    .overlay(Circle().stroke(Brick.ink, lineWidth: 2.5))
                    .compositingGroup()
                    .shadow(color: Brick.ink, radius: 0, x: 3, y: 3)
            }
            Text("Insights").font(.brickTitle(26)).foregroundStyle(Brick.ink)
            Spacer()
        }
        .padding(.top, 4)
    }
}

// MARK: - Helpers

/// One day worth of completion data, used as the Chart data type.
private struct DailyCount: Identifiable {
    var id: Date { date }
    let date: Date
    let count: Int
}

/// One smart-insight row. Handles both SF Symbol names and emoji symbols.
private struct BrickInsightCard: View {
    let insight: SmartInsight

    /// True if the symbol string is an emoji rather than an SF Symbol name.
    private var symbolIsEmoji: Bool {
        guard let first = insight.symbol.unicodeScalars.first else { return false }
        return first.value > 127
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if symbolIsEmoji {
                    Text(insight.symbol).font(.title2)
                } else {
                    Image(systemName: insight.symbol)
                        .font(.title2)
                        .foregroundStyle(insight.color)
                }
            }
            .frame(width: 40, height: 40)
            .background(Circle().fill(Brick.white))
            .overlay(Circle().stroke(Brick.ink, lineWidth: 2))

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title).font(.brickHeading(14)).foregroundStyle(Brick.ink)
                Text(insight.message).font(.brickBody(13)).foregroundStyle(Brick.ink.opacity(0.75))
            }
            Spacer()
        }
        .padding(14)
        .brickCard(fill: Brick.cream, cornerRadius: 16, borderWidth: 2.5, shadowOffset: 3.5)
    }
}

/// A small reusable brick card for top-level stats.
private struct BrickStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let symbol: String
    let tint: Color

    private var textColor: Color { tint.brickTextColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.brickBodyHeavy(12))
                .foregroundStyle(textColor.opacity(0.9))
            Text(value)
                .font(.brickTitle(34))
                .foregroundStyle(textColor)
            Text(subtitle)
                .font(.brickBody(12))
                .foregroundStyle(textColor.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .brickCard(fill: tint, cornerRadius: 18, borderWidth: 2.5, shadowOffset: 4)
        .overlay(BrickStuds(count: 3, diameter: 8, color: tint), alignment: .top)
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
    .modelContainer(for: [Habit.self, HabitCompletion.self], inMemory: true)
}
```

That's everything — `BrickTheme.swift` from Step 2 already has every helper both files above use (`Brick`, `Color(hex:)`, the font shortcuts, `.brickCard()`, `BrickStuds`, `BaseplateBackground`), so no other file needs to change.
