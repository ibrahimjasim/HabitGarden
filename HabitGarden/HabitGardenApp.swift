//
//  HabitGardenApp.swift
//  HabitGarden
//
//  Created by Ibrahim Jasim Alsalih on 2026-04-30.
//

import SwiftUI
import SwiftData

// The entry point of the app — this is where everything starts
@main
struct HabitGardenApp: App {

    // Holds the current user's login state (shared across all views)
    @State private var auth = AuthViewModel()

    init() {
        // Ask the user for permission to send daily reminders
        #if DEBUG
        // Screenshot runs skip the permission alert so it doesn't cover the screen
        if ScreenshotMode.isActive { return }
        #endif
        Task {
            await NotificationManager.requestNotificationPermission()
        }
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let screen = ScreenshotMode.screen {
                // Used by scripts/take-screenshots.sh — opens one screen with demo data
                ScreenshotRootView(screen: screen, auth: auth)
            } else if ScreenshotMode.autoCapture {
                // Run from Xcode while build/capture-screenshots exists → saves every screen
                ScreenshotCaptureView(auth: auth)
            } else {
                authGate
            }
            #else
            authGate
            #endif
        }
        // Make the auth view-model available to every view in the app
        .environment(auth)
        // Set up the local database with all the models the app uses
        .modelContainer(
            for: [Habit.self, HabitCompletion.self, AppAccount.self, Program.self, ProgramStep.self],
            inMemory: Self.useInMemoryStore
        )
    }

    // Auth gate: show the main screen if logged in, otherwise show login
    @ViewBuilder
    private var authGate: some View {
        if auth.isLoggedIn {
            HabitListView()
        } else {
            LoginView(auth: auth)
        }
    }

    // Screenshot runs use a throwaway database so demo data never mixes with real data
    private static var useInMemoryStore: Bool {
        #if DEBUG
        return ScreenshotMode.isActive
        #else
        return false
        #endif
    }
}
