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
        Settings {
            SettingsView(clock: appDelegate.clock)
        }
    }
}
