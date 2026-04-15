//
//  SectionHeader.swift
//  doubletime
//

import SwiftUI

struct SectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(.tertiary)
    }
}
