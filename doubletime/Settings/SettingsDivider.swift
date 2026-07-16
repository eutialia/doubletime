//
//  SettingsDivider.swift
//  doubletime
//

import SwiftUI

/// A 1pt hairline with 8pt vertical margin, between settings groups.
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(DesignTokens.hairline)
            .frame(height: 1)
            .padding(.vertical, 8)
    }
}
