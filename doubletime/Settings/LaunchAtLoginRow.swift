//
//  LaunchAtLoginRow.swift
//  doubletime
//

import ServiceManagement
import SwiftUI

/// The launch-at-login row, shared by Settings and onboarding. Both bind the
/// app's single `LoginItemModel`, so two open windows never disagree.
struct LaunchAtLoginRow: View {
    @Bindable var loginItem: LoginItemModel

    var body: some View {
        SettingsRow(
            label: "Launch at login",
            caption: "macOS puts the clock back in the menu bar after a restart. You can also manage this in System Settings under Login Items."
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Launch at login", isOn: $loginItem.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(!LoginItemModel.canRegister)

                if loginItem.status == .requiresApproval {
                    HStack(spacing: 8) {
                        Text("Switched off in the system's Login Items.")
                            .font(DesignTokens.settingsCaption)
                            .foregroundStyle(DesignTokens.textMuted)
                        Button("Open Login Items…") {
                            loginItem.openSystemSettings()
                        }
                        .controlSize(.small)
                    }
                }

                if !LoginItemModel.canRegister {
                    Text("Unavailable in debug builds.")
                        .font(DesignTokens.settingsFootnote)
                        .foregroundStyle(DesignTokens.textFaint)
                }
            }
        }
    }
}
