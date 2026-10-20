# HABITGARDEN

![Platform](https://img.shields.io/badge/Platform-iOS_17+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![SwiftUI](https://img.shields.io/badge/SwiftUI-5-green) ![SwiftData](https://img.shields.io/badge/SwiftData-1.0-purple)

---

## Introduction to HabitGarden

HabitGarden is a native iOS habit-tracking application built with SwiftUI and SwiftData. The app transforms daily habits into a visual garden where each habit grows as a plant based on the user's consistency. The core idea is to make habit tracking fun, visual and motivating by combining practical tracking tools with a gamified garden experience.

Users can create accounts, track habits, set daily targets, enable reminders, monitor streaks and view smart insights — all while watching their garden grow.

---

## UX

### Site Goals & Audience

HabitGarden is designed for individuals who want to build and maintain positive daily habits. The target audience ranges from students to professionals who benefit from a simple, visually rewarding tracking system. The app avoids complexity and focuses on a clean, distraction-free experience that encourages consistency.

The broader goals include:
- Making habit tracking feel rewarding through visual plant growth.
- Providing actionable insights based on user behavior patterns.
- Keeping all data local and private on the user's device.
- Supporting multiple user accounts on a single device.

### App Layout

The app follows a clean, minimal layout using native SwiftUI components:
- **Navigation-based flow** — all screens are accessible from the main habit list via the toolbar.
- **Form-based input** for creating and editing habits, following iOS design conventions.
- **Card-based insights** for displaying statistics and smart patterns.
- **Canvas-based garden** for the animated plant visualisation rendered at 30fps.

### Color Scheme

HabitGarden uses a nature-inspired, soft green palette that reinforces the gardening theme:
- **Primary Green** (`#34C759`) — used for buttons, checkmarks, and active states.
- **Soft system backgrounds** — ensuring readability across light and dark mode.
- **Time-of-day gradients** — the Garden view changes sky colors dynamically based on the current hour (sunrise, daytime, sunset, night).

---

## UX Design

### User Stories
* All user stories can be found [Here](USERSTORIES.md)
* Organised into 7 Epics: Authentication, Habit Management, Daily Tracking, Reminders, Garden View, Insights & Statistics, Data & Privacy
* Prioritised using **MoSCoW** method: 13 Must Have, 7 Should Have, 3 Could Have

---

### Navigation Map

```
App Launch
    │
    ├── Not logged in ──> LoginView (Sign In / Sign Up)
    │                         │
    │                         └── On success ──> HabitListView
    │
    └── Logged in ──> HabitListView (Main Screen)
                          │
                          ├── + Button ──> AddHabitView (Sheet)
                          ├── Tap Habit ──> HabitDetailView
                          ├── Chart Icon ──> InsightsView
                          ├── Leaf Icon ──> GardenView
                          └── Sign Out ──> LoginView
```

---

## Main Features

### User Authentication
Local account system with sign up and sign in functionality. Passwords are hashed using **SHA-256** via Apple's CryptoKit framework before storage — plain text passwords are never saved. Sessions persist between app launches using UserDefaults so the user stays logged in.

### Habit Tracking
Users can create habits with a custom name, emoji symbol, daily target (1–20 times per day), and an optional daily reminder. Each habit is linked to the logged-in user, ensuring complete data isolation between accounts.

### Daily Completion Toggle
Tap the checkmark to mark a habit as done for today. For multi-target habits (e.g. "3 times per day"), each tap adds one completion. Tapping again after the target is met removes the last completion (undo).

### Streak Calculator
Counts consecutive days a habit was completed, working backwards from today. If the user hasn't completed the habit yet today, the streak counts from yesterday to avoid breaking active streaks unfairly.

### Daily Reminders
Users can enable a daily notification for each habit at a chosen time. Notifications are scheduled using `UNCalendarNotificationTrigger` and repeat every day. Deleting a habit automatically cancels its pending notification.

### Garden View
A visual representation of all habits as animated plants drawn on a SwiftUI Canvas. Each plant's height reflects the user's consistency over the last 7 days (0–100% growth). Plants sway gently using sine-wave animation, and the sky gradient changes based on the real time of day.

### Smart Insights
The InsightEngine analyzes habit completion data and surfaces up to 4 pattern-based insights:
- **Best time of day** — Morning, Afternoon, Evening, or Night.
- **Strongest day of the week** — the weekday with the most completions.
- **Weekly trend** — percentage change comparing this week vs. last week.
- **Most consistent habit** — the habit with the highest 7-day completion rate.

### Insights Dashboard
A statistics screen featuring:
- Headline cards showing weekly completions and best streak.
- A **7-day bar chart** built with Swift Charts.
- Smart insight cards generated by the InsightEngine.
- A per-habit streak breakdown list.

### Emoji Picker
A categorised emoji browser with 100+ emojis across 6 categories (Faces, Activities, Food, Nature, Objects, Symbols). Quick-pick presets are shown in the Add Habit form for fast selection, with a "Browse more" option for the full picker.

### Per-User Data Isolation
Each user only sees their own habits. The habit list is filtered by `userId` to ensure complete data separation between accounts on the same device.

---

## Visualised Features

<p align="center">
  <img src="docs/screenshots/02-habit-list.png" alt="Habit list" width="200">
  <img src="docs/screenshots/06-garden.png" alt="Garden" width="200">
  <img src="docs/screenshots/07-insights.png" alt="Insights" width="200">
</p>

### Login Screen
A clean sign in / sign up form with a segmented control to switch between modes. The name field only appears in sign up mode. The submit button is disabled until all required fields are filled. Error alerts appear for invalid input or duplicate emails.

<p align="center"><img src="docs/screenshots/01-login.png" alt="Login screen" width="300"></p>

### Habit List
The main screen showing all habits with their emoji, name, streak count, reminder indicator, and a completion toggle button. Multi-target habits show their progress (e.g. 2/3). The header gives access to Insights, Garden, the account menu (Sign Out / Delete Account) and Add Habit.

<p align="center"><img src="docs/screenshots/02-habit-list.png" alt="Habit list" width="300"></p>

### Add Habit Form
A form-based sheet with sections for name, daily target (stepper), emoji selection (grid + full picker), and an optional daily reminder with a time picker.

<p align="center"><img src="docs/screenshots/03-add-habit.png" alt="Add habit form" width="300"></p>

### Emoji Picker
A categorised emoji browser opened from "Browse more" in the Add Habit form or by tapping the emoji on the Habit Detail screen.

<p align="center"><img src="docs/screenshots/04-emoji-picker.png" alt="Emoji picker" width="300"></p>

### Habit Detail
An edit screen displaying the habit's name, emoji (tap to change), and read-only statistics including current streak, total completions, target per day, and creation date.

<p align="center"><img src="docs/screenshots/05-habit-detail.png" alt="Habit detail" width="300"></p>

### Garden View
An animated canvas rendering plants growing from the ground. Each habit is a plant whose height reflects the last 7 days of consistency, with its emoji displayed as the flower at the top. A sun or moon is drawn based on the time of day, and the sky gradient changes for sunrise, daytime, sunset, and nighttime.

<p align="center"><img src="docs/screenshots/06-garden.png" alt="Garden view" width="300"></p>

### Insights Screen
A scrollable dashboard with stat cards at the top, a weekly bar chart in the middle, smart insight cards below, and a per-habit streak list at the bottom.

<p align="center"><img src="docs/screenshots/07-insights.png" alt="Insights screen" width="300"></p>

### Empty State
What a brand-new account sees before adding a first habit.

<p align="center"><img src="docs/screenshots/08-empty-state.png" alt="Empty habit list" width="300"></p>

### Updating the Screenshots

All screenshots are generated from the real app with one command (run on a Mac with Xcode):

```bash
./scripts/take-screenshots.sh
```

The script builds the app, launches it in the iOS Simulator once per screen and saves the images to `docs/screenshots/`. It uses a DEBUG-only screenshot mode (`Helpers/ScreenshotMode.swift`) that opens each screen directly with demo habits in a temporary in-memory database, so your own data is never touched and none of this ships in the App Store build. Options: `DEVICE="iPhone 17 Pro Max"` to choose a simulator, `APPEARANCE=dark` for dark-mode shots.

---

## Tech Used

### Languages & Frameworks

| Technology | Purpose |
|-----------|---------|
| **Swift 5.9** | Primary programming language |
| **SwiftUI** | Declarative UI framework for all views |
| **SwiftData** | Local database persistence (Apple's modern replacement for Core Data) |
| **Swift Charts** | Bar chart on the Insights screen |
| **CryptoKit** | SHA-256 password hashing |
| **UserNotifications** | Daily reminder notifications |
| **Canvas / TimelineView** | Animated garden rendering at 30fps |

### Architecture & Patterns

| Pattern | Usage |
|---------|-------|
| **MVVM** | Model-View-ViewModel separation of concerns |
| **@Observable** | Swift's modern observation framework for reactive UI updates |
| **@Environment** | Dependency injection for sharing AuthViewModel across all views |
| **SwiftData @Model** | Declarative data models with automatic persistence |
| **@Relationship** | Cascade delete rules between Habit and HabitCompletion |

### Tools

| Tool | Purpose |
|------|---------|
| **Xcode 16** | IDE and build system |
| **Git & GitHub** | Version control and repository hosting |
| **SF Symbols** | System icons used throughout the app |

---

## Project Structure

The project follows the **MVVM (Model-View-ViewModel)** architecture:

```
HabitGarden/
├── Models (SwiftData)/
│   ├── AppAccount.swift        — Registered user account (stored in database)
│   ├── AppUser.swift           — Lightweight session info (stored in UserDefaults)
│   ├── Habit.swift             — Main habit model with properties and relationships
│   ├── HabitCompletion.swift   — Records each time a habit is completed
│   └── Insght.swift            — Data model for smart insight cards
│
├── ViewModels/
│   ├── AuthViewModel.swift     — Sign up, sign in, sign out, session persistence
│   └── HabitListViewModel.swift— Add, toggle, and delete habits
│
├── Views/
│   ├── LoginView.swift         — Sign in / Sign up screen
│   ├── HabitListView.swift     — Main habit list with toolbar navigation
│   ├── AddHabitView.swift      — Form to create a new habit
│   ├── HabitDetailView.swift   — Edit screen with statistics
│   ├── EmojiPickerView.swift   — Full emoji browser for habit symbols
│   ├── GardenView.swift        — Animated garden with growing plants
│   └── InsightsView.swift      — Charts, stats, and smart insights
│
├── Helpers/
│   ├── NotificationManager.swift — Daily reminder notifications
│   ├── StreakCalculater.swift    — Streak counting logic
│   └── InsightEngine.swift       — Pattern detection for smart insights
│
└── HabitGardenApp.swift        — App entry point with auth gate and database setup
```

---

## Data Models

The app uses **SwiftData** as the local database:

| Model | Purpose |
|-------|---------|
| `AppAccount` | Stores registered user accounts with hashed passwords and unique emails |
| `AppUser` | Lightweight Codable struct saved in UserDefaults for session persistence |
| `Habit` | The main model — name, emoji, target per day, reminder time, linked to a user |
| `HabitCompletion` | A single completion record with a timestamp, linked to a Habit via relationship |
| `SmartInsight` | Represents an insight card generated by the InsightEngine (not persisted) |

**Relationships:**
- Each `Habit` has many `HabitCompletion` records (cascade delete — deleting a habit removes all its completions).
- Each `Habit` belongs to a user via `userId` (links to `AppAccount`).

---

## Testing

### Manual Testing

| Feature | Test | Result |
|---------|------|--------|
| Sign Up | Create account with name, email, password | Account created, auto logged in |
| Sign Up | Attempt duplicate email | Error alert: "An account with that email already exists" |
| Sign Up | Password under 6 characters | Error alert: "Password must be at least 6 characters" |
| Sign Up | Empty name field | Error alert: "Please enter your name" |
| Sign In | Login with valid credentials | Logged in, user's habits displayed |
| Sign In | Wrong password | Error alert: "Incorrect password" |
| Sign In | Non-existent email | Error alert: "No account found with that email" |
| Sign Out | Tap sign-out button | Returns to login screen, session cleared |
| Session | Close and reopen app | User stays logged in automatically |
| Add Habit | Create habit with name, emoji, and reminder | Habit appears in list, notification scheduled |
| Add Habit | Try to save with empty name | Save button is disabled |
| Toggle | Tap checkmark on incomplete habit | Completion recorded, icon changes to filled |
| Toggle | Tap checkmark on completed habit | Last completion removed (undo) |
| Multi-target | Tap 3 times on a 3/day habit | Progress shows 1/3, 2/3, 3/3 |
| Streak | Complete habit on consecutive days | Streak count increases correctly |
| Delete | Swipe to delete a habit | Habit removed, notification cancelled |
| Reminder | Enable reminder with a time | Daily notification appears at set time |
| Garden | View garden with habits at various growth | Plants display correct heights based on 7-day data |
| Insights | View dashboard with completion data | Chart, stat cards, and insight cards displayed |
| User isolation | Log in as a different user | Only that user's habits are visible |

### Validator Testing

- All Swift files compile without errors or warnings in Xcode.
- SwiftUI previews render correctly for all views.

---

## Bugs

### Resolved Bugs

| Bug | Cause | Fix |
|-----|-------|-----|
| `Value of type 'AppAccount' has no member 'passwordHash'` | Property was named `password` in the model but referenced as `passwordHash` in the ViewModel | Renamed the property to `passwordHash` in AppAccount.swift |
| Compiler type-check timeout in AddHabitView | Too many nested views in a single body expression | Extracted `symbolSection` into a separate computed property |
| `Value of optional type 'String?' must be unwrapped` | `auth.currentUser?.id` passed where non-optional `String` was expected | Added `?? ""` fallback |
| All users see all habits | Habit list was using the unfiltered `@Query` instead of per-user filtering | Replaced `habits` with `userHabits` (filtered by current user's ID) |

### Known Bugs

No known bugs at this time.

---

## Deployment

### Requirements
- **macOS 14.0+** (Sonoma or later)
- **Xcode 16+**
- **iOS 17.0+** target device or simulator

### Steps to Run Locally

1. Clone the repository:
   ```bash
   git clone https://github.com/ibrahimjasim/HabitGarden.git
   ```

2. Open the project in Xcode:
   ```bash
   cd HabitGarden
   open HabitGarden.xcodeproj
   ```

3. Select a target device or simulator (iPhone 15 or newer recommended).

4. Build and run the project (`Cmd + R`).

5. The app uses SwiftData with a local SQLite database — no external services, backend servers, or API keys are required.

### App Store Deployment

To deploy to the App Store:
1. Configure signing with a valid Apple Developer account in Xcode.
2. Set the Bundle Identifier to a unique value.
3. Archive the build via **Product > Archive** in Xcode.
4. Upload to App Store Connect and submit for review.

---

## Credits

### Frameworks & Documentation
- [Apple SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Apple SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Apple Swift Charts Documentation](https://developer.apple.com/documentation/charts)
- [Apple CryptoKit Documentation](https://developer.apple.com/documentation/cryptokit)
- [Apple UserNotifications Documentation](https://developer.apple.com/documentation/usernotifications)

### Icons
- [SF Symbols](https://developer.apple.com/sf-symbols/) — Apple's system icon library used for all navigation and UI icons throughout the app.

### Inspiration
- The garden visualisation concept is inspired by gamified habit apps that turn daily consistency into visible, growing progress.

---

Built by Ibrahim Jasim Alsalih — May 2026.
