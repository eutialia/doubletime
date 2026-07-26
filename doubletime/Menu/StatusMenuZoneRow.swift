//
//  StatusMenuZoneRow.swift
//  doubletime
//

import SwiftUI

/// One informational row in the status menu — the glyph's zone, unfolded: code
/// and city, date and signed offset beneath, and the enlarged time on the SAME
/// chip token the glyph uses, so the two surfaces cannot drift apart.
///
/// Hosted as a custom `NSMenuItem` view, which is also why it never highlights:
/// AppKit hands highlight drawing to the view, and canon says informational rows
/// don't highlight. Ink is `Color.primary` at the token alphas rather than
/// literal white, so the row follows the menu's own appearance.
struct StatusMenuZoneRow: View {
    let zone: StatusMenuZone

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Flexible rather than a Spacer: an HStack puts its spacing on BOTH
            // sides of a Spacer, so a long city name would open a 12+8+12 gap
            // instead of the single 12 the design asks for.
            VStack(alignment: .leading, spacing: 2) {
                identity
                caption
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            timeChip
        }
        .padding(.horizontal, DesignTokens.menuRowPaddingX)
        .padding(.vertical, DesignTokens.menuRowPaddingY)
        .frame(minWidth: DesignTokens.menuRowMinWidth, alignment: .leading)
        // A custom menu item is an anonymous group to VoiceOver; without this it
        // announces as loose fragments with no menu semantics at all.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(zone.accessibilityLabel)
    }

    private var identity: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(zone.code)
                .font(DesignTokens.settingsMonoCaption.weight(.bold))
                .tracking(DesignTokens.labelTracking)
                .foregroundStyle(Color.primary.opacity(DesignTokens.dimInkOpacity))
            Text(zone.city)
                .font(DesignTokens.settingsLabel)
                .foregroundStyle(Color.primary.opacity(DesignTokens.inkOpacity))
                .lineLimit(1)
        }
    }

    private var caption: some View {
        HStack(spacing: 6) {
            Text(zone.caption)
                .font(DesignTokens.settingsCaption)
            if let offset = zone.offset {
                Text(offset)
                    .font(DesignTokens.settingsMonoCaption)
            }
        }
        .foregroundStyle(Color.primary.opacity(DesignTokens.dimInkOpacity))
    }

    private var timeChip: some View {
        Text(zone.time)
            .font(DesignTokens.menuTime)
            .tracking(DesignTokens.timeTracking)
            .foregroundStyle(Color.primary.opacity(DesignTokens.inkOpacity))
            // Tracking is applied after the last digit too, so the text box is a
            // tracking unit wider than its ink — pad the leading edge to put the
            // digits back on the chip's center (the same compensation HourCell
            // and the web port carry).
            .padding(.leading, DesignTokens.timeTracking)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                DesignTokens.chipFill(
                    isPrimary: zone.isPrimary, period: zone.period, colorScheme: colorScheme
                ),
                in: .rect(cornerRadius: DesignTokens.menuChipCornerRadius)
            )
    }
}

#Preview {
    // The design card's own instant: LAX 12:00 Mon 20 Apr, IST 00:30 Tue 21 Apr
    // — a sub-hour offset that straddles midnight, so the `+1d` state shows.
    let reference = Calendar(identifier: .gregorian).date(
        from: DateComponents(timeZone: .gmt, year: 2026, month: 4, day: 20, hour: 19)
    ) ?? .now
    VStack(alignment: .leading, spacing: 0) {
        StatusMenuZoneRow(
            zone: .make(
                timezone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt,
                code: "LAX", hour12: false, isPrimary: true,
                offsetMinutes: nil, dayDelta: 0, at: reference
            )
        )
        StatusMenuZoneRow(
            zone: .make(
                timezone: TimeZone(identifier: "Asia/Kolkata") ?? .gmt,
                code: "IST", hour12: false, isPrimary: false,
                offsetMinutes: 750, dayDelta: 1, at: reference
            )
        )
    }
    .padding(.vertical, 6)
}
