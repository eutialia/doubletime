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
            SettingsPane(clock: clock)
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }

            AboutPane()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: DesignTokens.settingsWidth)
        .background(DesignTokens.canvas)
        .tint(DesignTokens.controlTint)
    }
}

#Preview {
    SettingsView(clock: ClockModel())
}
