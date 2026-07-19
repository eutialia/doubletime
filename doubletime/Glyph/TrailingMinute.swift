//
//  TrailingMinute.swift
//  doubletime
//

import SwiftUI

/// The trailing `:mm` — the PRIMARY minute, except while the status item is
/// hovered over a sub-hour pair (`swapped`), when the digits roll, odometer
/// style, to the SECONDARY minute and recolor to the secondary tone
/// (DesignTokens.minuteSwapInk). The ink IS the swap cue — no card, so the
/// colon needs no clearance and the glyph keeps its canon spacing. The colon
/// stays plain primary ink (a separator is neutral chrome) and can hide every
/// other second (opt-in blink) at opacity 0 so the glyph width never changes.
///
/// The digits are ONE always-present Text swapped via contentTransition —
/// deliberately not conditional view identities with enter/exit transitions:
/// macOS renders status items on non-focused displays through replica windows,
/// and transition/clip machinery has been observed to render empty there. A
/// plain Text with a content transition uses the same rendering path as every
/// other glyph run, which replicas mirror correctly.
struct TrailingMinute: View {
    /// The one string on display — TimeGlyph resolves which zone's minute this
    /// is; the single always-present Text content-transitions when it changes.
    let minute: String
    var blink: Bool = false
    /// True while showing the secondary minute (rolls and recolors the digits).
    var swapped: Bool = false
    /// Roll direction: true when the secondary zone is ahead of the primary
    /// (anchoredSweep clockwise) — a later time rolls like an advancing
    /// counter. numericText's countsDown is the inverse notion.
    ///
    /// countsDown is keyed on `swapped`, not fixed, so hover-out retraces the
    /// hover-in roll instead of repeating it: the transition reads the
    /// modifier's value in the same transaction as the string change, so
    /// flipping which value it computes when `swapped` flips reverses the
    /// perceived direction on the way back.
    var rollsUp: Bool = true
    /// The secondary zone's period, hue-tinting the swapped ink in 12-hour
    /// mode; nil in 24-hour mode (dimmed neutral ink instead).
    var secondaryPeriod: ClockModel.Period? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            colon
            digits
        }
        .font(DesignTokens.timeFont)
        .tracking(DesignTokens.timeTracking)
        .foregroundStyle(.primary.opacity(DesignTokens.inkOpacity))
        .animation(DesignTokens.minuteSwapAnimation(reduceMotion: reduceMotion), value: swapped)
    }

    /// numericText rolls only the digits that actually change (a ±30 offset
    /// rolls just the tens digit). A minute tick mid-hover changes the string
    /// with no animated transaction (`.animation` above is keyed to `swapped`,
    /// not to the minute values), so it snaps — the same ordinary per-minute
    /// snap as when not hovered. The ink recolors in the same transaction as
    /// the roll, so digits and tone arrive together.
    private var digits: some View {
        Text(minute)
            .contentTransition(reduceMotion ? .opacity
                : .numericText(countsDown: swapped ? !rollsUp : rollsUp))
            .foregroundStyle(swapped
                ? DesignTokens.minuteSwapInk(period: secondaryPeriod, colorScheme: colorScheme)
                : Color.primary.opacity(DesignTokens.inkOpacity))
    }

    /// When blinking, ONLY the colon runs a per-second timeline (the rest of the
    /// glyph stays on the per-minute tick). It stays laid out at opacity 0 rather
    /// than being removed, so the glyph width never changes.
    @ViewBuilder private var colon: some View {
        if blink {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(":").opacity(ClockModel.colonVisible(at: context.date) ? 1 : 0)
            }
        } else {
            Text(":")
        }
    }
}
