//
//  StatusBarView.swift
//  doubletime
//

import SwiftUI

struct StatusBarView: View {
    var clock: ClockModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 4) {
                SecondaryTimezoneColumn(
                    label: clock.leftLabel,
                    timezone: clock.leftTimezone,
                    now: context.date
                )
                PrimaryTimezoneColumn(
                    label: clock.rightLabel,
                    timezone: clock.rightTimezone,
                    now: context.date
                )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(now: context.date))
        }
    }

    private func accessibilityLabel(now: Date) -> String {
        let lh = ClockModel.hour(for: clock.leftTimezone, at: now)
        let rh = ClockModel.hour(for: clock.rightTimezone, at: now)
        let m = ClockModel.minute(for: clock.rightTimezone, at: now)
        return "\(clock.leftLabel) \(lh), \(clock.rightLabel) \(rh) \(m)"
    }
}
