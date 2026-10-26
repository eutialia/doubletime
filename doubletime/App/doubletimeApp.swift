//
//  doubletimeApp.swift
//  doubletime
//

import SwiftUI

extension Notification.Name {
    static let openAppSettings = Notification.Name("openAppSettings")
}

@main
struct doubletimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false

    var body: some Scene {
        Settings {
            SettingsView(clock: appDelegate.clock)
        }
        .defaultLaunchBehavior(.suppressed)

        Window("Welcome to Doubletime", id: "onboarding") {
            OnboardingView(clock: appDelegate.clock)
                .onDisappear { onboardingCompleted = true }
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(onboardingCompleted ? .suppressed : .presented)
    }
}
