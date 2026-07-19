//
//  TrailingMinute.swift
//  doubletime
//

import SwiftUI

/// The trailing `:mm` — the PRIMARY minute, except while the status item is
/// hovered over a sub-hour pair (`carded`), when it flips, flip-clock style, to
/// the SECONDARY minute riding on a chip-fill card. The card persists for the
/// whole hover: it is the "you're reading the other zone" cue, not just a
/// transition effect. The colon can hide every other second (opt-in blink) at
/// opacity 0 so the glyph width never changes.
struct TrailingMinute: View {
    let minute: String
    var blink: Bool = false
    /// True while showing the secondary minute (draws the card and flips).
    var carded: Bool = false
    /// The secondary zone's period, hue-pairing the card with the secondary
    /// cell in 12-hour mode; nil in 24-hour mode (neutral fill).
    var cardPeriod: ClockModel.Period? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Two identities so the swap runs as a transition: the outgoing
            // face keeps its old minute string while it animates away.
            if carded {
                face.background { card }
                    .transition(reduceMotion ? .opacity : .flip(entering: true))
            } else {
                face
                    .transition(reduceMotion ? .opacity : .flip(entering: false))
            }
        }
        .animation(
            .easeInOut(duration: reduceMotion ? DesignTokens.minuteCrossfadeDuration : DesignTokens.minuteFlipDuration),
            value: carded
        )
    }

    private var face: some View {
        HStack(spacing: 0) {
            colon
            Text(minute)
        }
        .font(DesignTokens.timeFont)
        .tracking(DesignTokens.timeTracking)
        .foregroundStyle(.primary.opacity(DesignTokens.inkOpacity))
    }

    /// The chip riding under the secondary minute. Drawn as a background so it
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

/// Rotation about the horizontal axis with slight perspective. Animatable so
/// the transition system can interpolate the angle; the face hides past ~89°
/// so text never renders mirrored mid-flip.
private struct FlipEffect: ViewModifier, Animatable {
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
            .opacity(abs(angle) < 89 ? 1 : 0)
    }
}

extension AnyTransition {
    /// Half of a flip-clock turn. The entering face arrives from −90° → 0
    /// while the exiting face leaves 0 → +90°, meeting edge-on at the
    /// midpoint; reversing the state runs both in reverse, so the flip-back
    /// mirrors the flip-in.
    static func flip(entering: Bool) -> AnyTransition {
        .modifier(
            active: FlipEffect(angle: entering ? -90 : 90),
            identity: FlipEffect(angle: 0)
        )
    }
}
