//
//  AppDelegate.swift
//  doubletime
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let clock = ClockModel()
    private var statusItem: NSStatusItem!
    private var hostingView: NSHostingView<StatusBarView>!

    func applicationDidFinishLaunching(_ notification: Notification) {
        hostingView = NSHostingView(rootView: StatusBarView(clock: clock))
        hostingView.layoutSubtreeIfNeeded()
        let size = hostingView.fittingSize

        statusItem = NSStatusBar.system.statusItem(withLength: size.width + 4)
        if let button = statusItem.button {
            hostingView.frame = button.bounds
            hostingView.autoresizingMask = [.width, .height]
            button.addSubview(hostingView)
        }

        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit doubletime", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openAppSettings, object: nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
