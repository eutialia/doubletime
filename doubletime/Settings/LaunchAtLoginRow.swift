//
//  LaunchAtLoginRow.swift
//  doubletime
//

import AppKit
import ServiceManagement
import SwiftUI

/// The launch-at-login row, shared by Settings and onboarding. It owns the
/// login-item model and refreshes it whenever the app comes forward, since the
/// user can flip the item in System Settings while the window is open.
struct LaunchAtLoginRow: View {
    @State private var loginItem: LoginItemModel

    /// `nil` rather than a `LoginItemModel()` default argument: under the
    /// Swift 5 language mode a default expression is evaluated in the caller's
    /// isolation, where a main-actor initializer is unreachable.
    @MainActor init(loginItem: LoginItemModel? = nil) {
        _loginItem = State(initialValue: loginItem ?? LoginItemModel())
    }

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
        .onAppear { loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refresh()
        }
    }
}
