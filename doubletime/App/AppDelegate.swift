//
//  AppDelegate.swift
//  doubletime
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let statusItemPadding: CGFloat = 4

    let clock = ClockModel()
    private var statusItem: NSStatusItem?
    private var hostingView: NSHostingView<StatusBarView>!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The status bar never derives an item's length from SwiftUI content
        // (variableLength + subview constraints collapses to zero width), so
        // the view reports its ideal width and we set the length explicitly —
        // at launch and again whenever labels/timezone change in Settings.
        hostingView = NSHostingView(rootView: StatusBarView(clock: clock) { [weak self] width in
            let length = ceil(width) + Self.statusItemPadding
            Task { @MainActor in
                self?.statusItem?.length = length
            }
        })
        hostingView.layoutSubtreeIfNeeded()

        let statusItem = NSStatusBar.system.statusItem(
            withLength: ceil(hostingView.fittingSize.width) + Self.statusItemPadding
        )
        self.statusItem = statusItem
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
        let quitItem = NSMenuItem(title: "Quit Doubletime", action: #selector(quitApp), keyEquivalent: "q")
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
