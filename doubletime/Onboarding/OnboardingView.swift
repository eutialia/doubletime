//
//  OnboardingView.swift
//  doubletime
//

import AppKit
import SwiftUI

/// The first-launch window: the two city rows and the login toggle from
/// Settings. Every edit applies immediately, so the real menu bar is the
/// preview and Done only dismisses.
struct OnboardingView: View {
    @Bindable var clock: ClockModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to Doubletime")
                    .font(DesignTokens.settingsTitle)
                    .foregroundStyle(DesignTokens.textStrong)
                Text("Your clock lives in the menu bar, top right.")
                    .font(DesignTokens.settingsBody)
                    .foregroundStyle(DesignTokens.textMuted)
            }
            .padding(.bottom, 10)

            ZoneRows(clock: clock)
            SettingsDivider()
            LaunchAtLoginRow()
            SettingsDivider()

            HStack {
                Text("Everything else is in Settings.")
                    .font(DesignTokens.settingsCaption)
                    .foregroundStyle(DesignTokens.textFaint)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding(.top, 4)
        }
        .padding(EdgeInsets(top: 20, leading: 28, bottom: 22, trailing: 28))
        .frame(width: DesignTokens.settingsWidth, alignment: .leading)
        .background(DesignTokens.canvas)
        .tint(DesignTokens.controlTint)
        // An LSUIElement app is never activated at launch, so the window would
        // open behind whatever app is frontmost.
        .onAppear { NSApp.activate() }
    }
}
