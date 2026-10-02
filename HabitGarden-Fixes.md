# HabitGarden — Blocker Fixes (patches to apply yourself)

These are the code changes for the top issues from the checklist, written out so you can read them, understand *why*, and type/paste them into Xcode yourself rather than having them appear in your project already done. I haven't touched any file in your project — everything below is for you to apply.

Order: do these top to bottom. The first two are the most important (App Store will reject the app or leak data without them).

---

## 1. Fix the deployment target

**File:** `HabitGarden.xcodeproj/project.pbxproj`

**Why:** `IPHONEOS_DEPLOYMENT_TARGET = 26.4` currently locks the app to devices already running the newest iOS — basically nobody. Nothing in your code needs more than iOS 17 (that's SwiftData's own minimum).

Easiest way to fix it — don't hand-edit the `.pbxproj`:
1. Open the project in Xcode.
2. Select the **HabitGarden** project in the navigator → the **HabitGarden** target → **General** tab.
3. Under **Minimum Deployments**, set iOS to **17.0**.

That updates both the Debug and Release build settings for you. (If you ever do want to hand-edit the file, it's the two lines that currently read `IPHONEOS_DEPLOYMENT_TARGET = 26.4;` — one per configuration.)

---

## 2. Stop Garden and Insights from mixing accounts together

**Files:** `Views/GardenView.swift`, `Views/InsightsView.swift`

**Why:** Both screens currently do `@Query(sort: \Habit.createdAt) private var habits: [Habit]` with no filter, so if two people use the app on the same device, each one's garden and stats include the *other* person's habits. `HabitListView` already solved this with a `userHabits` computed property filtered by `auth.currentUser?.id` — copy that same pattern here.

### GardenView.swift

```swift
struct GardenView: View {
    @Environment(AuthViewModel.self) private var auth          // ADD THIS
    @Query(sort: \Habit.createdAt) private var habits: [Habit]

    // ADD THIS — same pattern as HabitListView.userHabits
    private var userHabits: [Habit] {
        guard let userId = auth.currentUser?.id else { return [] }
        return habits.filter { $0.userId == userId }
    }

    var body: some View {
        ZStack {
            timeOfDayGradient
                .ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    drawGarden(context: context, size: size, time: time)
                }
            }

            if userHabits.isEmpty {                             // CHANGE habits -> userHabits
                ContentUnavailableView(
                    "Your garden is empty",
                    systemImage: "leaf.circle",
                    description: Text("Add a habit to plant your first seed.")
                )
            }
        }
        .navigationTitle("Garden")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ...

    private func drawGarden(context: GraphicsContext, size: CGSize, time: Double) {
        let groundY = size.height * 0.78
        // ... sun/moon + ground drawing unchanged ...

        guard !userHabits.isEmpty else { return }                // CHANGE habits -> userHabits
        let calendar = Calendar.current
        let plantSpacing = size.width / CGFloat(userHabits.count + 1)  // CHANGE

        for (index, habit) in userHabits.enumerated() {          // CHANGE habits -> userHabits
            // ... unchanged ...
        }
    }
```

Note `GardenView` will need `.environment(auth)` to already be visible — it is, because `HabitGardenApp` sets `.environment(auth)` on the whole `WindowGroup`, so every pushed view (including this one, reached via `NavigationLink`) already has access. You don't need to pass it manually.

### InsightsView.swift

```swift
struct InsightsView: View {
    @Environment(AuthViewModel.self) private var auth          // ADD THIS
    @Query private var habits: [Habit]

    // ADD THIS
    private var userHabits: [Habit] {
        guard let userId = auth.currentUser?.id else { return [] }
        return habits.filter { $0.userId == userId }
    }

    private var last7Days: [DailyCount] {
        let calendar = Calendar.current
        let allCompletions = userHabits.flatMap { $0.completions }   // CHANGE habits -> userHabits
        // ... rest unchanged ...
    }

    private var bestStreak: Int {
        userHabits                                                   // CHANGE habits -> userHabits
            .map { StreakCalculator.currentStreak(for: $0) }
            .max() ?? 0
    }

    private var insights: [SmartInsight] {
        InsightEngine.generate(habits: userHabits)                    // CHANGE habits -> userHabits
    }

    var body: some View {
        // ... headline cards + chart unchanged ...

        // MARK: Per-habit streaks
        VStack(alignment: .leading, spacing: 12) {
            Text("Streaks per habit").font(.headline)
            if userHabits.isEmpty {                                   // CHANGE habits -> userHabits
                Text("Add a habit to see your stats here.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(userHabits) { habit in                        // CHANGE habits -> userHabits
                    // ... unchanged ...
                }
            }
        }
        // ...
    }
}
```

Every other place `habits` appears in these two files, swap in `userHabits`. There should be no remaining unfiltered `habits` reference left in either file when you're done — search the file for `habits` to double check.

---

## 3. Add in-app account deletion

**Why:** Apple's App Store Review Guideline 5.1.1(v) requires an in-app way to delete an account whenever an app lets people create one — yours does (email/password *and* Sign in with Apple), so this is required, not optional.

### Step A — add the delete method to `ViewModels/AuthViewModel.swift`

Add this alongside `signOut()`:

```swift
// MARK: - Delete account

// Permanently removes the current user's account and everything they own.
// Call this only after the person has confirmed — there's no undo.
func deleteAccount(context: ModelContext) {
    guard let userId = currentUser?.id else { return }

    // Delete every habit owned by this user first — HabitCompletion cascades
    // automatically via the @Relationship(deleteRule: .cascade) on Habit.
    let habitDescriptor = FetchDescriptor<Habit>(
        predicate: #Predicate { $0.userId == userId }
    )
    if let habits = try? context.fetch(habitDescriptor) {
        for habit in habits {
            NotificationManager.cancel(habitId: habit.id.uuidString)
            context.delete(habit)
        }
    }

    // Delete the account record. Fetching all accounts and matching in memory
    // (rather than inside #Predicate) because calling .uuidString on a UUID
    // isn't reliably supported inside the SwiftData predicate macro.
    if let accounts = try? context.fetch(FetchDescriptor<AppAccount>()) {
        if let account = accounts.first(where: { $0.id.uuidString == userId }) {
            context.delete(account)
        }
    }

    try? context.save()
    signOut()
}
```

### Step B — add a confirm-and-delete UI to `Views/HabitListView.swift`

Replace the existing sign-out toolbar button with a menu that offers both actions, so delete isn't one accidental tap away:

```swift
@State private var showDeleteAccountConfirm = false   // ADD near your other @State vars

// ... inside .toolbar { ... }, REPLACE the sign-out ToolbarItem with:

ToolbarItem(placement: .topBarTrailing) {
    Menu {
        Button {
            auth.signOut()
        } label: {
            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
        }
        Button(role: .destructive) {
            showDeleteAccountConfirm = true
        } label: {
            Label("Delete Account", systemImage: "trash")
        }
    } label: {
        Image(systemName: "person.crop.circle")
    }
}
```

Then add this modifier alongside the other `.alert(...)` on `HabitListView`'s `NavigationStack`:

```swift
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
```

---

## 4. Set the accent color (5-minute fix, no code needed)

**Why:** Your README describes Primary Green `#34C759` as the app's identity, but `AccentColor.colorset` has no color set, so every tint in the app is falling back to system blue.

In Xcode: open `Assets.xcassets` → select **AccentColor** → in the Attributes Inspector, click the color swatch → **Show Color Panel** → enter `#34C759` as a custom RGB hex value.

If you'd rather edit the file directly, `AccentColor.colorset/Contents.json` becomes:

```json
{
  "colors" : [
    {
      "idiom" : "universal",
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "red" : "0.204",
          "green" : "0.780",
          "blue" : "0.349",
          "alpha" : "1.000"
        }
      }
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

---

## 5. Salt the password hash (optional but cheap, do it before you have real users)

**Why:** Right now `AuthViewModel.hash(_:)` is unsalted SHA-256 — fine-ish since the database never leaves the device, but salting costs almost nothing and you have no real accounts yet to migrate, so now is the moment.

### `Models(SwiftData)/AppAccount.swift`

```swift
@Model
final class AppAccount {
    var id = UUID()
    @Attribute(.unique) var email: String
    var name: String
    var passwordHash: String
    var passwordSalt: String     // ADD THIS
    var createdAt: Date

    init(email: String, name: String, passwordHash: String, passwordSalt: String) {  // ADD passwordSalt param
        self.email = email
        self.name = name
        self.passwordHash = passwordHash
        self.passwordSalt = passwordSalt
        self.createdAt = .now
    }
}
```

### `ViewModels/AuthViewModel.swift`

```swift
// REPLACE the existing hash(_:) with:
private func hash(_ password: String, salt: String) -> String {
    let digest = SHA256.hash(data: Data((salt + password).utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}

private func randomSalt() -> String {
    (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
}
```

Then in `signUp(...)`, generate a salt and pass both into `AppAccount(...)`:

```swift
let salt = randomSalt()
let account = AppAccount(
    email: trimmedEmail,
    name: trimmedName,
    passwordHash: hash(password, salt: salt),
    passwordSalt: salt
)
```

And in `signIn(...)`, use the stored salt to verify:

```swift
guard account.passwordHash == hash(password, salt: account.passwordSalt) else {
    errorMessage = "Incorrect password."
    return
}
```

`handleAppleSignIn` also calls `hash(appleUserId)` — give that call a salt too (a fixed one is fine there, e.g. `hash(appleUserId, salt: "apple")`, since it's not a real password).

---

## Not included here

The checklist covers a few more items I didn't turn into ready-to-paste code because they're judgment calls, not mechanical fixes: what to do with the orphaned `Program`/`ProgramStep`/`ProgramViewModel` code (finish it or delete it), the missing app icon (needs actual artwork), the privacy policy (needs your own words), and the App Store Connect listing itself. Ask me for any of those next if you want a hand.
