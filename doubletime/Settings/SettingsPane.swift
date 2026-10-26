//
//  SettingsPane.swift
//  doubletime
//

import SwiftUI

/// The "Settings" tab: immediate-apply rows for the two zones, time format,
/// glyph style, the blinking colon, and launch at login. There is no
/// Apply/Cancel — every change hits ClockModel directly and the real menu bar
/// is the live preview.
struct SettingsPane: View {
    @Bindable var clock: ClockModel
    /// Injectable so tests can drive the pane off a stubbed `LoginItemService`
    /// instead of `SMAppService.mainApp` — without it the pane's geometry (the
    /// extra `.requiresApproval` row) would depend on the developer's real
    /// Login Items. Production passes nothing and gets the real model.
    private let loginItem: LoginItemModel?

    @MainActor init(clock: ClockModel, loginItem: LoginItemModel? = nil) {
        _clock = Bindable(wrappedValue: clock)
        self.loginItem = loginItem
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZoneRows(clock: clock)

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

            LaunchAtLoginRow(loginItem: loginItem)
        }
        .padding(EdgeInsets(top: 8, leading: 28, bottom: 22, trailing: 28))
        .frame(width: DesignTokens.settingsWidth, alignment: .leading)
        .background(DesignTokens.canvas)
    }
}
