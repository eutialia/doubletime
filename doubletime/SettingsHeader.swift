//
//  SettingsHeader.swift
//  doubletime
//

import SwiftUI

struct SettingsHeader: View {
    let previewSecondaryTimezone: TimeZone
    let secondaryLabel: String
    let primaryTimezone: TimeZone
    let primaryLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("doubletime")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                Text("Secondary timezone for your menu bar clock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            MenuBarPreview(
                secondaryTimezone: previewSecondaryTimezone,
                secondaryLabel: secondaryLabel,
                primaryTimezone: primaryTimezone,
                primaryLabel: primaryLabel
            )
        }
    }
}
