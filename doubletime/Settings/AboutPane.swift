//
//  AboutPane.swift
//  doubletime
//

import SwiftUI

/// The "About" tab: app name, version, and license.
///
/// The design's glyph showcase above the name and the source link are
/// intentionally not implemented yet (showcase design undecided, repository
/// unpublished); the blurb was dropped on purpose.
struct AboutPane: View {
    private var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Doubletime")
                .font(DesignTokens.settingsTitle)
                .foregroundStyle(DesignTokens.textStrong)

            Text(versionString)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(DesignTokens.textMuted)
                .padding(.top, 4)

            Text("© 2026 · MIT License")
                .font(DesignTokens.settingsCaption)
                .foregroundStyle(DesignTokens.textFaint)
                .padding(.top, 18)
        }
        .padding(EdgeInsets(top: 30, leading: 32, bottom: 32, trailing: 32))
        .frame(width: DesignTokens.settingsWidth)
        .background(DesignTokens.canvas)
    }
}
