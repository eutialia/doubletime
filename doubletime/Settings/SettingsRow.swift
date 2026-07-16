//
//  SettingsRow.swift
//  doubletime
//

import SwiftUI

/// A macOS-System-Settings-style row: a right-aligned 150pt label column, a 14pt
/// gap, then a left-aligned control with an optional muted caption beneath it.
struct SettingsRow<Control: View>: View {
    let label: String
    var caption: String? = nil
    /// Top-align the label with a tall control (e.g. the glyph-style cards).
    var alignTop: Bool = false
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: alignTop ? .top : .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(DesignTokens.settingsLabel)
                .foregroundStyle(DesignTokens.textStrong)
                .frame(width: 150, alignment: .trailing)
                // Nudge a top-aligned label onto the control's optical baseline.
                .padding(.top, alignTop ? 2 : 0)

            VStack(alignment: .leading, spacing: 6) {
                control
                if let caption {
                    Text(caption)
                        .font(DesignTokens.settingsCaption)
                        .foregroundStyle(DesignTokens.textMuted)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: DesignTokens.settingsControlWidth, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 9)
    }
}
