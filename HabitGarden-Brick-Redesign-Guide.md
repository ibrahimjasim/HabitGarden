# HabitGarden — Brick Redesign, step by step

Four steps, in order. Each one builds on the last, so do them in sequence and build in Xcode after each one to catch typos early.

1. Add two fonts to the project (Fredoka + Nunito)
2. Add `BrickTheme.swift` — the shared colors, fonts, and reusable brick components everything else uses
3. Replace `HabitListView.swift`
4. Replace `GardenView.swift`

---

## Step 1 — Add Fredoka and Nunito

1. Go to [fonts.google.com](https://fonts.google.com) and search **Fredoka**. Click "Get font" → "Download all". Unzip it, open the `static` folder, and pull out these three files:
   - `Fredoka-Medium.ttf`
   - `Fredoka-SemiBold.ttf`
   - `Fredoka-Bold.ttf`
2. Do the same for **Nunito** — unzip, open `static`, pull out:
   - `Nunito-SemiBold.ttf`
   - `Nunito-Bold.ttf`
   - `Nunito-ExtraBold.ttf`
3. In Xcode, drag all six `.ttf` files into your `HabitGarden` group in the Project Navigator. In the dialog that appears, make sure **"Copy items if needed"** is checked and the **HabitGarden target** checkbox is ticked.
4. Open `Info.plist` (or your target's Info tab, whichever your project uses) and add a new array key called **"Fonts provided by application"** (raw key: `UIAppFonts`). Add six string entries, one per file, exactly matching the filenames:
   ```
   Fredoka-Medium.ttf
   Fredoka-SemiBold.ttf
   Fredoka-Bold.ttf
   Nunito-SemiBold.ttf
   Nunito-Bold.ttf
   Nunito-ExtraBold.ttf
   ```
5. Build and run once. Then, temporarily, drop this into any view's `.onAppear` to confirm the exact font names iOS registered them under (Google's static files usually match the filename minus `.ttf`, but this is the way to be 100% sure before moving on):
   ```swift
   .onAppear {
       for family in UIFont.familyNames.sorted() where family.contains("Fredoka") || family.contains("Nunito") {
           print(family, "->", UIFont.fontNames(forFamilyName: family))
       }
   }
   ```
   Check the Xcode console output. If any name printed there doesn't match what's used in `BrickTheme.swift` below (Step 2), swap it in — that's the only thing that would need adjusting.

---

## Step 2 — `BrickTheme.swift`

New file, anywhere in the project (a `Theme` group is a fine place). This is the shared vocabulary every other step uses: colors, fonts, the hex-color helper, and the reusable "brick card" look (thick ink border + hard offset shadow, no blur).

```swift
//
//  BrickTheme.swift
//  HabitGarden
//
//  Shared design tokens for the brick/toy visual style — chunky rounded
//  shapes, thick ink outlines, hard offset shadows (no blur).
//

import SwiftUI

// MARK: - Palette

enum Brick {
    static let ink    = Color(hex: "#2B2118")
    static let cream  = Color(hex: "#FBF6EC")
    static let red    = Color(hex: "#E8483C")
    static let yellow = Color(hex: "#F5B72E")
    static let blue   = Color(hex: "#3E86F0")
    static let green  = Color(hex: "#33AE64")
    static let purple = Color(hex: "#8C5CF5")
    static let brown  = Color(hex: "#A9673B")
    static let white  = Color.white
}

// MARK: - Hex color support

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Rough relative luminance — used to flip label text between
    /// ink and white depending on how bright the card color is.
    var isLight: Bool {
        guard let c = UIColor(self).cgColor.components, c.count >= 3 else { return true }
        let luminance = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
        return luminance > 0.6
    }

    var brickTextColor: Color { isLight ? Brick.ink : .white }
}

// MARK: - Fonts
// Falls back to the system font automatically if a name below isn't
// registered yet — nothing crashes if Step 1 hasn't happened.

extension Font {
    static func brickTitle(_ size: CGFloat) -> Font { .custom("Fredoka-Bold", size: size) }
    static func brickHeading(_ size: CGFloat) -> Font { .custom("Fredoka-SemiBold", size: size) }
    static func brickBody(_ size: CGFloat) -> Font { .custom("Nunito-Bold", size: size) }
    static func brickBodyHeavy(_ size: CGFloat) -> Font { .custom("Nunito-ExtraBold", size: size) }
}

// MARK: - The "brick card" look
// A filled, rounded, thick-bordered shape with a crisp offset shadow
// (radius: 0 on SwiftUI's .shadow gives a hard edge, no blur).

struct BrickCardBackground: ViewModifier {
    var fill: Color
    var cornerRadius: CGFloat = 18
    var borderWidth: CGFloat = 3
    var shadowOffset: CGFloat = 5

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Brick.ink, lineWidth: borderWidth)
                    )
            )
            .compositingGroup()
            .shadow(color: Brick.ink, radius: 0, x: shadowOffset, y: shadowOffset)
    }
}

extension View {
    func brickCard(fill: Color, cornerRadius: CGFloat = 18, borderWidth: CGFloat = 3, shadowOffset: CGFloat = 5) -> some View {
        modifier(BrickCardBackground(fill: fill, cornerRadius: cornerRadius, borderWidth: borderWidth, shadowOffset: shadowOffset))
    }
}

// MARK: - Studs
// The little circles along a brick's top edge. Overlay this with
// alignment: .top on anything using brickCard().

struct BrickStuds: View {
    var count: Int = 3
    var diameter: CGFloat = 10
    var color: Color

    var body: some View {
        HStack {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(color)
                    .frame(width: diameter, height: diameter)
                    .overlay(Circle().stroke(Brick.ink, lineWidth: 2))
                if i < count - 1 { Spacer() }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 1)
        .offset(y: -diameter / 2)
    }
}

// MARK: - Baseplate background
// The dot-grid "toy baseplate" texture used behind the habit list.

struct BaseplateBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 22
            let dot = Path(ellipseIn: CGRect(x: -1.5, y: -1.5, width: 3, height: 3))
            var y: CGFloat = 10
            while y < size.height {
                var x: CGFloat = 10
                while x < size.width {
                    context.translateBy(x: x, y: y)
                    context.fill(dot, with: .color(Brick.ink.opacity(0.10)))
                    context.translateBy(x: -x, y: -y)
                    x += spacing
                }
                y += spacing
            }
        }
        .background(Brick.cream)
        .ignoresSafeArea()
    }
}
```

---

## Step 3 — Replace `HabitListView.swift`

This keeps every bit of existing behavior — data isolation (`userHabits`), sign out, delete account, add sheet, swipe to delete, the error alert — just restyled. Your habit's own `colorHex` becomes its card color, and the text automatically switches between ink and white depending on how light that color is.

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

## Step 4 — Replace `GardenView.swift`

This is the tree logic. Per habit:

- **No goal set** → the trunk height tracks the current day streak (`StreakCalculator.currentStreak`), capped at 8 bricks so it never runs off the screen. Beyond the cap, the label keeps counting the real number even though the trunk stops growing.
- **Goal set, not reached yet** → trunk height tracks days completed toward that goal.
- **Goal reached** → the trunk caps at the goal's brick count and a green canopy blooms on top.
- **Nothing done yet (day 0)** → a small seed nub in the ground instead of an empty trunk.

```swift
//
//  GardenView.swift
//  HabitGarden
//

import SwiftUI
import SwiftData

struct GardenView: View {
    @Environment(AuthViewModel.self) private var auth
    @Query(sort: \Habit.createdAt) private var habits: [Habit]

    private var userHabits: [Habit] {
        guard let userId = auth.currentUser?.id else { return [] }
        return habits.filter { $0.userId == userId }
    }

    private let maxTrunkBricks = 8

    var body: some View {
        ZStack {
            skyGradient.ignoresSafeArea()

            ZStack(alignment: .bottom) {
                ground

                if userHabits.isEmpty {
                    ContentUnavailableView(
                        "Your garden is empty",
                        systemImage: "leaf.circle",
                        description: Text("Add a habit to plant your first seed.")
                    )
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

            VStack {
                header
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Garden").font(.brickTitle(28)).foregroundStyle(Brick.ink)
            Text("Brick by brick — bloom when you hit your goal")
                .font(.brickBody(14)).foregroundStyle(Brick.ink.opacity(0.75))
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
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

## After you've applied all four steps

Build and run. Things worth checking on a real device/simulator:

- If habit names are wide with narrow screens, four cards side-by-side in the Garden can get tight — if labels crowd each other, the easiest fix is dropping `HabitRow`'s `cornerRadius`/`fontSize` slightly or letting the Garden scroll horizontally instead of squeezing everything into one screen width.
- `AddHabitView` and `HabitDetailView` still use the plain system look — the two mocked screens (list + garden) are the ones that changed. Say the word when you want those brought into the same style next.
- The studs on `HabitRow` sit right at the row's top edge — if any get visually clipped by the List's row spacing on your device, increase the `.padding(.vertical, 8)` right above `.listRowBackground` slightly.
