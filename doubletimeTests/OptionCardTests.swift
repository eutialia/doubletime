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

    /// `selected` toggles the radio dot fill and the card border width/opacity
    /// — a real visible difference, not just an accessibility trait.
    @Test @MainActor func selectedStateChangesRenderedPixels() throws {
        #expect(try render(selected: false, variant: .arc, hour12: false)
                 != render(selected: true, variant: .arc, hour12: false))
    }

    /// Both embedded GlyphExample chips follow `hour12` — the card must
    /// visibly repaint when the setting changes.
    @Test @MainActor func hour12TogglesChangeRenderedPixels() throws {
        #expect(try render(selected: true, variant: .arc, hour12: false)
                 != render(selected: true, variant: .arc, hour12: true))
    }

    /// The card's own `variant` picks which indicator style its exemplar
    /// chips draw.
    @Test @MainActor func variantTogglesChangeRenderedPixels() throws {
        #expect(try render(selected: true, variant: .arc, hour12: false)
                 != render(selected: true, variant: .segmented, hour12: false))
    }

    /// The two GlyphExample chips render at a HARDCODED exemplar instant
    /// (`OptionCard.exemplar`), not `.now` — re-rendering must be
    /// byte-identical, or the settings surface would visibly flicker on
    /// every incidental redraw.
    @Test @MainActor func exemplarChipsAreDeterministicAcrossRepeatedRenders() throws {
        #expect(try render(selected: true, variant: .arc, hour12: false)
                 == render(selected: true, variant: .arc, hour12: false))
    }
}
