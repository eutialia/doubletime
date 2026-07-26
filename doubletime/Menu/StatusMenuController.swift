//
//  StatusMenuController.swift
//  doubletime
//

import AppKit
import SwiftUI

/// Builds and owns the status item's dropdown: two informational zone rows
/// (custom `NSHostingView` items) above a separator and the command items.
///
/// The command items stay STANDARD `NSMenuItem`s, so macOS draws its own accent
/// highlight, renders ⌘, / ⌘Q, dismisses on click and keeps their VoiceOver
/// menu-item semantics. Canon asks for a monochrome ink-at-alpha highlight, but
/// AppKit only stops drawing the accent pill for custom-view items — buying the
/// pill would mean reimplementing every one of those behaviours. The accent is
/// also a user preference the OS propagates (Graphite users already get
/// monochrome), so it reads as the system speaking rather than the app picking a
/// hue. Deliberate deviation; do not "fix" it back toward the web mock.
///
/// Menu material is the system's `.menu` vibrancy — the design's `--dt-menu-*`
/// surface tokens are web stand-ins for it and have no native counterpart.
@MainActor
final class StatusMenuController: NSObject {
    let menu = NSMenu()

    private let clock: ClockModel
    private let onOpen: () -> Void
    private let onClose: () -> Void
    private let onSettings: () -> Void
    private let onQuit: () -> Void

    private let primaryRow: NSHostingView<StatusMenuZoneRow>
    private let secondaryRow: NSHostingView<StatusMenuZoneRow>

    init(
        clock: ClockModel,
        onOpen: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.clock = clock
        self.onOpen = onOpen
        self.onClose = onClose
        self.onSettings = onSettings
        self.onQuit = onQuit

        let rows = StatusMenuZone.rows(from: clock, at: .now)
        primaryRow = NSHostingView(rootView: StatusMenuZoneRow(zone: rows.primary))
        secondaryRow = NSHostingView(rootView: StatusMenuZoneRow(zone: rows.secondary))

        super.init()

        // Explicit enablement: with auto-enabling on, AppKit recomputes every
        // item's state at open time from target/action validation and would
        // overrule the rows' disabled flag.
        menu.autoenablesItems = false
        menu.delegate = self

        // KNOWN LIMITATION: AppKit skips disabled items during menu navigation,
        // so each row's accessibilityLabel may not be reachable by VoiceOver
        // inside the menu. Enabling the items would make them focusable but also
        // selectable and click-dismissable, which is exactly what "informational
        // rows never highlight" rules out. The status item's own label already
        // speaks both zones' code and hour (TimeGlyph), so what a VoiceOver user
        // loses here is the city, date and offset detail — not the times.
        for host in [primaryRow, secondaryRow] {
            let item = NSMenuItem()
            item.view = host
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let settings = NSMenuItem(
            title: "Settings…", action: #selector(selectSettings), keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(
            title: "Quit Doubletime", action: #selector(selectQuit), keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        sizeRows()
    }

    /// Re-reads the clock into both rows. Called on every open rather than on a
    /// timer — see `StatusMenuZone`'s note on the menu's tracking run loop.
    private func refreshRows(at date: Date) {
        let rows = StatusMenuZone.rows(from: clock, at: date)
        primaryRow.rootView = StatusMenuZoneRow(zone: rows.primary)
        secondaryRow.rootView = StatusMenuZoneRow(zone: rows.secondary)
        sizeRows()
    }

    /// `NSMenu` measures a custom item from its view's FRAME, never from SwiftUI
    /// content (the same rule that collapses an unsized status item to zero
    /// width) — an unsized hosting view here renders as an invisible row. Both
    /// rows are then pinned to the SAME width, the wider of the two, so their
    /// time chips line up however the city names differ.
    private func sizeRows() {
        let hosts = [primaryRow, secondaryRow]
        for host in hosts {
            host.layoutSubtreeIfNeeded()
        }
        // The row's own `menuRowMinWidth` frame is the floor, so this only has to
        // pick the wider of the two — there is no empty case to fall back from.
        let width = max(primaryRow.fittingSize.width, secondaryRow.fittingSize.width)
        for host in hosts {
            // Size only — the menu owns the origin. Width first, then re-measure
            // the height at that width rather than at the previous one.
            host.setFrameSize(NSSize(width: width, height: host.frame.height))
            host.layoutSubtreeIfNeeded()
            host.setFrameSize(NSSize(width: width, height: host.fittingSize.height))
            host.layoutSubtreeIfNeeded()
        }
    }

    @objc private func selectSettings() {
        onSettings()
    }

    @objc private func selectQuit() {
        onQuit()
    }
}

extension StatusMenuController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        refreshRows(at: .now)
        onOpen()
    }

    func menuDidClose(_ menu: NSMenu) {
        onClose()
    }
}
