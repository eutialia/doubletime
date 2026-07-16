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

    private var timeString: String {
        let h = ClockModel.hour(for: option.timezone, at: now)
        let m = ClockModel.minute(for: option.timezone, at: now)
        return "\(h):\(m)"
    }

    private var offsetString: String {
        let minutes = ClockModel.offsetMinutes(from: option.timezone, to: referenceTimezone, at: now)
        if minutes == 0 { return "same" }
        let hours = minutes / 60
        let remainder = abs(minutes % 60)
        let sign = minutes >= 0 ? "+" : "−"
        if remainder == 0 {
            return "\(sign)\(abs(hours))h"
        }
        return "\(sign)\(abs(hours)):\(remainder.formatted(.number.precision(.integerLength(2))))"
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
