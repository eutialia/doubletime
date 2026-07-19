//
//  StatusBarView.swift
//  doubletime
//

import SwiftUI

struct StatusBarView: View {
    var clock: ClockModel
    /// Reports the glyph's ideal width so the owner can size the status item
    /// (an NSStatusBarButton never derives its length from SwiftUI content).
    var onWidthChange: (CGFloat) -> Void = { _ in }

    // The status item's NSHostingView is the app's only always-alive SwiftUI
    // context, so the Settings scene is opened from here (AppDelegate posts
    // .openAppSettings from the AppKit menu item).
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // Read systemZoneGeneration so a Mac-timezone change (which bumps it)
        // repaints a "System (auto)" primary immediately, not at the next tick.
        let _ = clock.systemZoneGeneration
        // Per-minute ticks refresh the digits; the colon runs its own per-second
        // timeline when blinking (see TrailingMinute), so the whole glyph never
        // rebuilds every second.
        TimelineView(.everyMinute) { context in
            glyph(at: context.date)
        }
        // Always lay out at the ideal size so the reported width is
        // independent of the (possibly stale) status item length.
        .fixedSize()
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
            onWidthChange(width)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAppSettings)) { _ in
            openSettings()
        }
    }

    private func glyph(at date: Date) -> some View {
        TimeGlyph(
            secondaryLabel: clock.secondaryLabel(at: date),
            secondaryTimezone: clock.secondaryTimezone,
            primaryLabel: clock.primaryLabel(at: date),
            primaryTimezone: clock.primaryTimezone,
            now: date,
            hour12: clock.hour12,
            variant: clock.variant,
            blinkColon: clock.blinkColon,
            hovered: clock.statusItemHovered
        )
        // Shift the ensemble down so the label rides inside the fixed 22pt
        // status button (no top clip on unfocused displays). Settings exemplars
        // apply the SAME nudge via View.statusItemStrip — only the strip height
        // and appearance differ here, because the real menu bar supplies the
        // button height and its own light/dark appearance.
        .offset(y: DesignTokens.statusItemGlyphNudge)
    }
}
