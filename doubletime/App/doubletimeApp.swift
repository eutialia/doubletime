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
            SettingsView(clock: appDelegate.clock, loginItem: appDelegate.loginItem)
        }
        .defaultLaunchBehavior(.suppressed)

        Window("Welcome to Doubletime", id: "onboarding") {
            OnboardingView(clock: appDelegate.clock, loginItem: appDelegate.loginItem)
                .windowDismissBehavior(.disabled)
                .windowMinimizeBehavior(.disabled)
                .onDisappear { onboardingCompleted = true }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(onboardingCompleted ? .suppressed : .presented)
    }
}
