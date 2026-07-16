//
//  SettingsOpenerScene.swift
//  doubletime
//

import SwiftUI

struct SettingsOpenerScene: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onReceive(NotificationCenter.default.publisher(for: .openAppSettings)) { _ in
                openSettings()
            }
            .background(InvisibleWindowConfigurator())
    }
}
