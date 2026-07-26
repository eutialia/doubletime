//
//  TimezoneRow.swift
//  doubletime
//

import SwiftUI

/// One row in the zone-picker popover: city + IANA id on the left, the zone's
/// current time and signed offset from the reference zone on the right.
struct TimezoneRow: View {
    let option: TimezoneOption
    let now: Date
    let referenceTimezone: TimeZone

    /// Always 24-hour, whatever the glyph is set to: the picker is a scan across
    /// hundreds of zones, where a period suffix is noise.
    private var timeString: String {
        ClockModel.time(for: option.timezone, at: now, hour12: false)
    }

    private var offsetString: String {
        ClockModel.offsetCaption(
            minutes: ClockModel.offsetMinutes(from: option.timezone, to: referenceTimezone, at: now),
            style: .terse
        )
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(option.city)
                    .font(DesignTokens.settingsBody)
                    .foregroundStyle(DesignTokens.textStrong)
                Text(option.id)
                    .font(DesignTokens.settingsFootnote)
                    .foregroundStyle(DesignTokens.textMuted)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(timeString)
                    .font(DesignTokens.settingsMono)
                    .foregroundStyle(DesignTokens.textBody)
                Text(offsetString)
                    .font(DesignTokens.settingsMonoCaption)
                    .foregroundStyle(DesignTokens.textFaint)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}
