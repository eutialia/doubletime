//
//  GlyphVariantTests.swift
//  doubletimeTests
//

import Testing
@testable import doubletime

struct GlyphVariantTests {
    /// The raw values are a storage contract (ClockModel persists them), so
    /// they must survive a write/read cycle and keep their spelling: renaming
    /// a case would silently reset every user's chosen variant to `.arc`.
    @Test(arguments: GlyphVariant.allCases)
    func rawValueRoundTrips(variant: GlyphVariant) {
        #expect(GlyphVariant(rawValue: variant.rawValue) == variant)
    }

    @Test func allCasesCoversBothVariants() {
        #expect(GlyphVariant.allCases == [.arc, .segmented])
        #expect(Set(GlyphVariant.allCases.map(\.rawValue)) == ["arc", "segmented"])
        // An unknown persisted string must not resolve — ClockModel relies on
        // the nil to fall back to `.arc`.
        #expect(GlyphVariant(rawValue: "ring") == nil)
    }
}
