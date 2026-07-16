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

    var body: some Scene {
        WindowGroup(id: "settingsOpener") {
            SettingsOpenerScene()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)

        Settings {
            SettingsView(clock: appDelegate.clock)
        }
    }
}
