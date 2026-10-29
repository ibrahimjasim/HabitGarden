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
            // Emoji sits above the name so the name gets the full column width;
            // side by side, narrow columns broke names mid-word ("Medi / tate").
            Text(habit.emoji.isEmpty ? "🌱" : habit.emoji).font(.system(size: 13))
            Text(habit.name)
                .font(.brickHeading(11.5)).foregroundStyle(Brick.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            switch stage(for: habit) {
            case .bloomed:
                Text("🌿 Goal reached · \(streak) \(streak == 1 ? "day" : "days")")
                    .font(.brickBodyHeavy(10)).foregroundStyle(Brick.ink.opacity(0.8))
            case .seed:
                Text("🌰 Just planted")
                    .font(.brickBodyHeavy(10)).foregroundStyle(Brick.ink.opacity(0.8))
            case .growing:
                if let goal = habit.goalDays {
                    Text("🔥 \(daysCompleted(for: habit))/\(goal) days")
                        .font(.brickBodyHeavy(10)).foregroundStyle(Brick.ink.opacity(0.8))
                } else {
                    Text("🔥 \(streak) \(streak == 1 ? "day" : "days")")
                        .font(.brickBodyHeavy(10)).foregroundStyle(Brick.ink.opacity(0.8))
                }
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .brickCard(fill: Brick.cream, cornerRadius: 12, borderWidth: 2.5, shadowOffset: 2.5)
    }
}

#Preview {
    NavigationStack { GardenView() }
        .modelContainer(for: [Habit.self, HabitCompletion.self], inMemory: true)
}
