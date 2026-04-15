//
//  SecondaryTimezoneColumn.swift
//  doubletime
//

import SwiftUI

struct SecondaryTimezoneColumn: View {
    let label: String
    let timezone: TimeZone
    let now: Date

    var body: some View {
        let hour = ClockModel.hour(for: timezone, at: now)
        VStack(alignment: .leading, spacing: 0) {
            Text(label.isEmpty ? " " : label)
                .font(DesignTokens.labelFont)
                .foregroundStyle(.secondary)
            Text(hour)
                .font(DesignTokens.hourFont)
                .foregroundStyle(.primary.opacity(DesignTokens.secondaryHourOpacity))
                .padding(.horizontal, 3)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.chipCornerRadius)
                        .fill(.primary.opacity(DesignTokens.secondaryChipFillOpacity))
                )
                .contentTransition(.numericText())
                .animation(DesignTokens.digitAnimation, value: hour)
        }
    }
}
