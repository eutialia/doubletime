//
//  SettingsPane.swift
//  doubletime
//

import AppKit
import ServiceManagement
import SwiftUI

/// The "Settings" tab: immediate-apply rows for the two zones, time format,
/// glyph style, the blinking colon, and launch at login. There is no
/// Apply/Cancel — every change hits ClockModel directly and the real menu bar
/// is the live preview.
struct SettingsPane: View {
    @Bindable var clock: ClockModel
    @State private var loginItem: LoginItemModel

    /// `loginItem` is injectable so tests can drive the pane off a stubbed
    /// `LoginItemService` instead of `SMAppService.mainApp` — without it the
    /// pane's geometry (the extra `.requiresApproval` row) would depend on the
    /// developer's real Login Items. Production passes nothing and gets the
    /// real model. (`nil` rather than a `LoginItemModel()` default argument:
    /// under the Swift 5 language mode a default expression is evaluated in the
    /// caller's isolation, where a main-actor initializer is unreachable.)
    @MainActor init(clock: ClockModel, loginItem: LoginItemModel? = nil) {
        _clock = Bindable(wrappedValue: clock)
        _loginItem = State(initialValue: loginItem ?? LoginItemModel())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow(
                label: "Primary city",
                caption: "Your home zone. It gets the brighter cell, and the trailing :mm always shows its minute."
            ) {
                ZoneRowControl(clock: clock, isPrimary: true)
            }

            SettingsRow(
                label: "Secondary city",
                caption: "The foreign zone. It gets the dimmer leading cell."
            ) {
                ZoneRowControl(clock: clock, isPrimary: false)
            }

            SettingsDivider()

            SettingsRow(
                label: "Time format",
                caption: "In 12-hour mode there is no AM/PM text. The cells tint instead: warm amber for AM, cool indigo for PM."
            ) {
                Picker("Time format", selection: $clock.hour12) {
                    Text("24-hour").tag(false)
                    Text("12-hour").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            SettingsDivider()

            SettingsRow(
                label: "Glyph style",
                caption: "Both examples use a 30-minute offset. The sweep runs clockwise when the secondary zone is ahead and counterclockwise when it is behind.",
                alignTop: true
            ) {
                VStack(spacing: 8) {
                    OptionCard(
                        title: "Arc",
                        caption: "thin sweep from 12 o'clock",
                        selected: clock.variant == .arc,
                        variant: .arc,
                        hour12: clock.hour12
                    ) { clock.variant = .arc }

                    OptionCard(
                        title: "Segmented",
                        caption: "quarter-hour segments",
                        selected: clock.variant == .segmented,
                        variant: .segmented,
                        hour12: clock.hour12
                    ) { clock.variant = .segmented }
                }
                .frame(width: DesignTokens.settingsControlWidth)
            }

            SettingsDivider()

            SettingsRow(
                label: "Blinking colon",
                caption: "The trailing colon hides every other second. It cuts instantly instead of fading."
            ) {
                Toggle("Blinking colon", isOn: $clock.blinkColon)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            SettingsDivider()

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
        .padding(EdgeInsets(top: 8, leading: 28, bottom: 22, trailing: 28))
        .frame(width: DesignTokens.settingsWidth, alignment: .leading)
        .background(DesignTokens.canvas)
        .onAppear { loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refresh()
        }
    }
}
