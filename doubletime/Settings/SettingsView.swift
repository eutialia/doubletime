//
//  SettingsView.swift
//  doubletime
//

import SwiftUI

/// The Settings window: a macOS-System-Settings-style TabView that follows the
/// system appearance. The surface stays monochrome (no accent hues outside the
/// 12-hour glyph itself); every chrome color is a dynamic DesignTokens token.
struct SettingsView: View {
    @Bindable var clock: ClockModel
    /// Threaded straight through to `SettingsPane` (see its init) so a test can
    /// render the whole window off a stubbed login-item service; `nil` leaves
    /// the pane to build the real, `SMAppService`-backed model.
    private let loginItem: LoginItemModel?

    @MainActor init(clock: ClockModel, loginItem: LoginItemModel? = nil) {
        _clock = Bindable(wrappedValue: clock)
        self.loginItem = loginItem
    }

    var body: some View {
        TabView {
            Tab("Settings", systemImage: "slider.horizontal.3") {
                SettingsPane(clock: clock, loginItem: loginItem)
            }

            Tab("About", systemImage: "info.circle") {
                AboutPane()
            }
        }
        .frame(width: DesignTokens.settingsWidth)
        .background(DesignTokens.canvas)
        .tint(DesignTokens.controlTint)
    }
}

#Preview {
    SettingsView(clock: ClockModel())
}
