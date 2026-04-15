//
//  PrimaryTimezoneColumn.swift
//  doubletime
//

import SwiftUI

struct PrimaryTimezoneColumn: View {
    let label: String
    let timezone: TimeZone
    let now: Date

    var body: some View {
        let hour = ClockModel.hour(for: timezone, at: now)
        let minute = ClockModel.minute(for: timezone, at: now)
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(DesignTokens.labelFont)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(hour)
                    .font(DesignTokens.hourFont)
                    .foregroundStyle(.background)
                    .padding(.horizontal, 3)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.chipCornerRadius)
                            .fill(.primary)
                    )
                    .contentTransition(.numericText())
                    .animation(DesignTokens.digitAnimation, value: hour)

                Text(":\(minute)")
                    .font(DesignTokens.hourFont)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(DesignTokens.digitAnimation, value: minute)
            }
        }
    }
}
