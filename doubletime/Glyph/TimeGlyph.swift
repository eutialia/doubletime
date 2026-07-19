//
//  TimeGlyph.swift
//  doubletime
//

import SwiftUI

/// The menu bar glyph: [secondary HourCell][primary HourCell][trailing :mm].
///
/// The trailing `:mm` is the primary minute; while `hovered` over a sub-hour
/// pair it rolls to the SECONDARY minute on a chip-fill card (see
/// TrailingMinute) — gated on the same predicate that draws the indicator, so
/// whole-hour pairs make hover a no-op. The primary cell shows no indicator;
/// the secondary cell shows an arc/segmented indicator encoding the signed
/// sub-hour offset between the two zones. In 12-hour mode each cell tints by
/// ITS OWN period (warm amber = AM, cool indigo = PM) and shows hh12 digits.
struct TimeGlyph: View {
    let secondaryLabel: String
    let secondaryTimezone: TimeZone
    let primaryLabel: String
    let primaryTimezone: TimeZone
    let now: Date
    var hour12: Bool = false
    var variant: GlyphVariant = .arc
    var blinkColon: Bool = false
    /// Pointer-over state of the status item (or a settings exemplar chip).
    var hovered: Bool = false

    var body: some View {
        let sweep = ClockModel.anchoredSweep(secondary: secondaryTimezone, primary: primaryTimezone, at: now)
        let secondaryHour = digits(for: secondaryTimezone)
        let primaryHour = digits(for: primaryTimezone)
        // Hover rolls the minute to the secondary zone ONLY when the sub-hour
        // indicator is showing — the exact predicate that draws the arc.
        // Both minutes are always computed: TrailingMinute keeps one live Text
        // and content-transitions between the strings (replica-safe).
        let showsSecondaryMinute = hovered && sweep.fraction > 0
        let primaryMinute = ClockModel.minute(for: primaryTimezone, at: now)
        let secondaryMinute = ClockModel.minute(for: secondaryTimezone, at: now)
        let secondaryPeriod = hour12 ? ClockModel.period(for: secondaryTimezone, at: now) : nil
        let primaryPeriod = hour12 ? ClockModel.period(for: primaryTimezone, at: now) : nil

        // .center: digits are centered inside the 16pt cells and the 10pt
        // trailing :mm centers against them (web uses flex align center).
        HStack(alignment: .center, spacing: DesignTokens.glyphSpacing) {
            HourCell(label: secondaryLabel, hour: secondaryHour,
                     fraction: sweep.fraction, clockwise: sweep.clockwise,
                     variant: variant, tone: .secondary, period: secondaryPeriod)
            HourCell(label: primaryLabel, hour: primaryHour,
                     fraction: 0, tone: .primary, period: primaryPeriod)
            TrailingMinute(primaryMinute: primaryMinute, secondaryMinute: secondaryMinute,
                           blink: blinkColon, carded: showsSecondaryMinute,
                           rollsUp: sweep.clockwise, cardPeriod: secondaryPeriod)
                .padding(.leading, DesignTokens.trailingMinuteLeadingOffset)
        }
        .padding(.horizontal, DesignTokens.glyphHorizontalPadding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(secondaryLabel) \(secondaryHour)\(spell(secondaryPeriod)), "
            + "\(primaryLabel) \(primaryHour)\(spell(primaryPeriod)) \(primaryMinute)"
        )
    }

    private func digits(for tz: TimeZone) -> String {
        hour12 ? ClockModel.hour12(for: tz, at: now) : ClockModel.hour(for: tz, at: now)
    }

    /// Speaks the 12-hour period for VoiceOver (empty in 24-hour mode, where the
    /// hour is already unambiguous).
    private func spell(_ period: ClockModel.Period?) -> String {
        switch period {
        case .am: " AM"
        case .pm: " PM"
        case nil: ""
        }
    }
}
