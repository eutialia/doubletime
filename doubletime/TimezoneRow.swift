//
//  TimezoneRow.swift
//  doubletime
//

import SwiftUI

struct TimezoneRow: View {
    let option: TimezoneOption
    let now: Date
    let referenceTimezone: TimeZone

    private var timezone: TimeZone {
        TimeZone(identifier: option.id) ?? .current
    }

    private var timeString: String {
        let h = ClockModel.hour(for: timezone, at: now)
        let m = ClockModel.minute(for: timezone, at: now)
        return "\(h):\(m)"
    }

    private var offsetString: String {
        let deltaSeconds = timezone.secondsFromGMT(for: now) - referenceTimezone.secondsFromGMT(for: now)
        let minutes = deltaSeconds / 60
        if minutes == 0 { return "local" }
        let hours = minutes / 60
        let remainder = abs(minutes % 60)
        let sign = minutes >= 0 ? "+" : "−"
        if remainder == 0 {
            return "\(sign)\(abs(hours))h"
        }
        let padded = remainder < 10 ? "0\(remainder)" : "\(remainder)"
        return "\(sign)\(abs(hours)):\(padded)"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(option.city)
                    .font(.system(.body, design: .rounded))
                Text(option.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(timeString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text(offsetString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }
}
