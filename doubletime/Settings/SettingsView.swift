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

    var body: some View {
        TabView {
            Tab("Settings", systemImage: "slider.horizontal.3") {
                SettingsPane(clock: clock)
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
