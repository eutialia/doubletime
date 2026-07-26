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
    private var statusMenu: StatusMenuController?
    /// Gates the hover flag while the item's menu is up (see the tracker
    /// closure): tracking events must not resurface the swap behind the menu.
    private var menuIsOpen = false

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
            // hover surface. This closure is the SINGLE write point for the
            // flag: hover means pointer-over AND no open menu (the .activeAlways
            // area outlives menu tracking, so an enter mustn't resurface the
            // swap behind an open menu), and the @Observable flag only mutates
            // on real changes — every write invalidates the live status item.
            hoverTracker = StatusItemHoverTracker(view: button) { [weak self] hovering in
                guard let self else { return }
                let hovered = hovering && !self.menuIsOpen
                if self.clock.statusItemHovered != hovered {
                    self.clock.statusItemHovered = hovered
                }
            }
        }

        // AppKit guarantees neither a mouseExited when the menu captures the
        // pointer nor a mouseEntered if the pointer is still over the item when
        // the menu closes — force-sync hover around the menu's lifetime.
        let statusMenu = StatusMenuController(
            clock: clock,
            onOpen: { [weak self] in
                guard let self else { return }
                menuIsOpen = true
                if clock.statusItemHovered {
                    clock.statusItemHovered = false
                }
            },
            onClose: { [weak self] in
                guard let self else { return }
                menuIsOpen = false
                hoverTracker?.sync()
            },
            onSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
        self.statusMenu = statusMenu
        statusItem.menu = statusMenu.menu
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openAppSettings, object: nil)
    }
}
