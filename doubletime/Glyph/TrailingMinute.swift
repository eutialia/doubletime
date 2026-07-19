//
//  TrailingMinute.swift
//  doubletime
//

import SwiftUI

/// The trailing `:mm` — the PRIMARY minute, except while the status item is
/// hovered over a sub-hour pair (`carded`), when the digits roll — like a
/// split-flap line — to the SECONDARY minute over a chip-fill card. The card
/// fades in and persists for the whole hover: it is the "you're reading the
/// other zone" cue, not just a transition effect. The colon sits outside the
/// roll (a separator never animates) and can hide every other second (opt-in
/// blink) at opacity 0 so the glyph width never changes.
struct TrailingMinute: View {
    let minute: String
    var blink: Bool = false
    /// True while showing the secondary minute (rolls the digits, fades the card in).
    var carded: Bool = false
    /// Roll direction: true when the secondary zone is ahead of the primary
    /// (anchoredSweep clockwise) — a later time rolls up like an advancing
    /// counter, an earlier one rolls down. Un-carding rolls back the way it came.
    var rollsUp: Bool = true
    /// The secondary zone's period, hue-pairing the card with the secondary
    /// cell in 12-hour mode; nil in 24-hour mode (neutral fill).
    var cardPeriod: ClockModel.Period? = nil

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
        .background { card.opacity(carded ? 1 : 0) }
        .animation(
            .easeInOut(duration: reduceMotion ? DesignTokens.minuteCrossfadeDuration
                                              : DesignTokens.minuteRollDuration),
            value: carded
        )
    }

    /// Two identities so the swap runs as a transition (the outgoing digits
    /// keep their old minute string while they roll away), clipped to the
    /// digits' own box so the roll reads through an odometer window. On
    /// hover-in the plain digits exit one edge while the carded digits enter
    /// from the other; symmetric per-branch edges make hover-out retrace the
    /// motion in reverse for free.
    private var digits: some View {
        ZStack {
            if carded {
                Text(minute).transition(roll(from: rollsUp ? .bottom : .top))
            } else {
                Text(minute).transition(roll(from: rollsUp ? .top : .bottom))
            }
        }
        .clipped()
    }

    private func roll(from edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge)
    }

    /// The chip riding under the whole `:mm`. Drawn as a background so it
    /// never affects layout: it pins to the hour cells' height and outsets past
    /// the text box purely visually. It uses the PRIMARY fill strength (the
    /// secondary tier is too faint to read as a cue) with the SECONDARY
    /// period's hue, visually pairing the card with the cell whose minute it
    /// shows.
    private var card: some View {
        RoundedRectangle(cornerRadius: DesignTokens.cellCornerRadius)
            .fill(DesignTokens.chipFill(isPrimary: true, period: cardPeriod, colorScheme: colorScheme))
            .frame(height: DesignTokens.cellSize.height)
            .padding(.horizontal, -DesignTokens.minuteCardOutset)
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
