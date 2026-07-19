//
//  OptionCard.swift
//  doubletime
//

import SwiftUI

/// A selectable white card presenting one glyph variant, with a radio dot,
/// title, right-aligned caption, and two glyph examples (a +30 clockwise and a
/// −30 counterclockwise exemplar) that follow the hour-format setting and this
/// card's own variant. Hovering an example swaps its trailing minute to the
/// secondary zone, mirroring the live status item's hover behavior.
struct OptionCard: View {
    let title: String
    let caption: String
    let selected: Bool
    let variant: GlyphVariant
    let hour12: Bool
    let onSelect: () -> Void

    /// Fixed exemplar instant: IST 21:30 / LAX 09:00 — a true ±30 min gap.
    private static let exemplar = Date(timeIntervalSince1970: 1_776_700_800) // 2026-04-20T16:00:00Z
    private static let ist = TimeZone(identifier: "Asia/Kolkata")!
    private static let lax = TimeZone(identifier: "America/Los_Angeles")!

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    radioDot
                    Text(title)
                        .font(DesignTokens.settingsHeading)
                        .foregroundStyle(DesignTokens.textStrong)
                    Spacer(minLength: 8)
                    Text(caption)
                        .font(DesignTokens.settingsCaption)
                        .foregroundStyle(DesignTokens.textMuted)
                }

                HStack(spacing: 8) {
                    GlyphExample(secondary: Self.ist, primary: Self.lax,
                                 caption: "+30 AHEAD · CW", hour12: hour12, variant: variant)
                    GlyphExample(secondary: Self.lax, primary: Self.ist,
                                 caption: "−30 BEHIND · CCW", hour12: hour12, variant: variant)
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignTokens.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selected ? DesignTokens.textStrong : DesignTokens.cardBorder,
                                    lineWidth: selected ? 2 : 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(caption)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var radioDot: some View {
        ZStack {
            // fieldBackground (not plain white) so the dot's center reads in dark.
            Circle().fill(DesignTokens.fieldBackground)
            if selected {
                Circle().strokeBorder(DesignTokens.textStrong, lineWidth: 4.5)
            } else {
                Circle().strokeBorder(DesignTokens.radioRing, lineWidth: 1)
            }
        }
        .frame(width: 14, height: 14)
    }

    /// One exemplar chip. Hovering swaps the trailing minute to the secondary
    /// zone — the same behavior as the live status item — so the feature is
    /// discoverable from Settings. The chip is a re-rasterized still photograph
    /// per state: the swap is instant here; the flip animation exists only in
    /// the live menu bar.
    private struct GlyphExample: View {
        let secondary: TimeZone
        let primary: TimeZone
        let caption: String
        let hour12: Bool
        let variant: GlyphVariant

        @State private var hovered = false

        var body: some View {
            VStack(spacing: 4) {
                GlyphChip(fixedHeight: 52) {
                    TimeGlyph(
                        secondaryLabel: ClockModel.defaultLabel(for: secondary, at: OptionCard.exemplar),
                        secondaryTimezone: secondary,
                        primaryLabel: ClockModel.defaultLabel(for: primary, at: OptionCard.exemplar),
                        primaryTimezone: primary,
                        now: OptionCard.exemplar,
                        hour12: hour12,
                        variant: variant,
                        hovered: hovered
                    )
                }
                .onHover { hovered = $0 }
                Text(caption)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(DesignTokens.textFaint)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
