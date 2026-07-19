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
    private var hoverTracker: StatusItemHoverTracker?

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

            // Hover rolls the trailing :mm to the secondary minute (TimeGlyph).
            // Tracked on the button so the whole item, padding included, is the
            // hover surface.
            hoverTracker = StatusItemHoverTracker(view: button) { [weak self] hovering in
                self?.clock.statusItemHovered = hovering
            }
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
        menu.delegate = self
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openAppSettings, object: nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    // AppKit guarantees neither a mouseExited when the menu captures the
    // pointer nor a mouseEntered if the pointer is still over the item when
    // the menu closes — force-sync hover around the menu's lifetime.
    func menuWillOpen(_ menu: NSMenu) {
        clock.statusItemHovered = false
    }

    func menuDidClose(_ menu: NSMenu) {
        hoverTracker?.sync()
    }
}
