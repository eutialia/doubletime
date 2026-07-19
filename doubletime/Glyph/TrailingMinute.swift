//
//  TrailingMinute.swift
//  doubletime
//

import SwiftUI

/// The trailing `:mm` — the PRIMARY minute, except while the status item is
/// hovered over a sub-hour pair (`carded`), when the digits roll, odometer
/// style, to the SECONDARY minute over a chip-fill card. The card fades in,
/// sits behind the digits ONLY (never the colon), and persists for the whole
/// hover: it is the "you're reading the other zone" cue, not just a transition
/// effect. The colon can hide every other second (opt-in blink) at opacity 0
/// so the glyph width never changes.
///
/// The digits are ONE always-present Text swapped via contentTransition —
/// deliberately not conditional view identities with enter/exit transitions:
/// macOS renders status items on non-focused displays through replica windows,
/// and transition/clip machinery has been observed to render empty there. A
/// plain Text with a content transition uses the same rendering path as every
/// other glyph run, which replicas mirror correctly.
struct TrailingMinute: View {
    let primaryMinute: String
    let secondaryMinute: String
    var blink: Bool = false
    /// True while showing the secondary minute (rolls the digits, fades the card in).
    var carded: Bool = false
    /// Roll direction: true when the secondary zone is ahead of the primary
    /// (anchoredSweep clockwise) — a later time rolls like an advancing
    /// counter. numericText's countsDown is the inverse notion.
    ///
    /// countsDown is keyed on `carded`, not fixed, so hover-out retraces the
    /// hover-in roll instead of repeating it: the transition reads the
    /// modifier's value in the same transaction as the string change, so
    /// flipping which value it computes when `carded` flips reverses the
    /// perceived direction on the way back.
    var rollsUp: Bool = true
    /// The secondary zone's period, hue-pairing the card with the secondary
    /// cell in 12-hour mode; nil in 24-hour mode (neutral fill).
    var cardPeriod: ClockModel.Period? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: DesignTokens.minuteColonGap) {
            colon
            digits
        }
        .font(DesignTokens.timeFont)
        .tracking(DesignTokens.timeTracking)
        .foregroundStyle(.primary.opacity(DesignTokens.inkOpacity))
        .animation(
            .easeInOut(duration: reduceMotion ? DesignTokens.minuteCrossfadeDuration
                                              : DesignTokens.minuteRollDuration),
            value: carded
        )
    }

    /// numericText rolls only the digits that actually change (a ±30 offset
    /// rolls just the tens digit). A minute tick mid-hover changes the string
    /// with no animated transaction (`.animation` above is keyed to `carded`,
    /// not to the minute values), so it snaps — the same ordinary per-minute
    /// snap as when not hovered.
    private var digits: some View {
        Text(carded ? secondaryMinute : primaryMinute)
            .contentTransition(reduceMotion ? .opacity
                : .numericText(countsDown: carded ? !rollsUp : rollsUp))
            .background { card.opacity(carded ? 1 : 0) }
    }

    /// The chip riding under the digits. Drawn as a background so it never
    /// affects layout: it pins to the hour cells' height and outsets past the
    /// digit box purely visually. It uses the PRIMARY fill strength (the
    /// secondary tier is too faint to read as a cue) with the SECONDARY
    /// period's hue, visually pairing the card with the cell whose minute it
    /// shows.
    private var card: some View {
        RoundedRectangle(cornerRadius: DesignTokens.cellCornerRadius)
            .fill(DesignTokens.chipFill(isPrimary: true, period: cardPeriod, colorScheme: colorScheme))
            .frame(height: DesignTokens.cellSize.height)
            .padding(.leading, -DesignTokens.minuteCardLeadingOutset)
            .padding(.trailing, -DesignTokens.minuteCardTrailingOutset)
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
