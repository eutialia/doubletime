//
//  OptionCardTests.swift
//  doubletimeTests
//

import Foundation
import SwiftUI
import Testing
@testable import doubletime

struct OptionCardTests {
    @MainActor
    private func render(selected: Bool, variant: GlyphVariant, hour12: Bool) throws -> Data {
        try pixelData(of: OptionCard(
            title: "Arc", caption: "thin sweep from 12 o'clock",
            selected: selected, variant: variant, hour12: hour12, onSelect: {}
        ).frame(width: DesignTokens.settingsControlWidth))
    }

    /// The card's own `variant` picks which indicator style its exemplar
    /// chips draw.
    @Test @MainActor func variantTogglesChangeRenderedPixels() throws {
        #expect(try render(selected: true, variant: .arc, hour12: false)
                 != render(selected: true, variant: .segmented, hour12: false))
    }
}
