//
//  MenuBarPreview.swift
//  doubletime
//

import SwiftUI

struct MenuBarPreview: View {
    let secondaryTimezone: TimeZone
    let secondaryLabel: String
    let primaryTimezone: TimeZone
    let primaryLabel: String

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 4) {
                    SecondaryTimezoneColumn(
                        label: secondaryLabel,
                        timezone: secondaryTimezone,
                        now: context.date
                    )
                    PrimaryTimezoneColumn(
                        label: primaryLabel,
                        timezone: primaryTimezone,
                        now: context.date
                    )
                }
                .padding(.horizontal, 6)
            }
        }
        .frame(height: 26)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.4))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        }
    }
}
