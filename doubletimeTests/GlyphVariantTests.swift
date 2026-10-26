//
//  GlyphVariantTests.swift
//  doubletimeTests
//

import Testing
@testable import doubletime

struct GlyphVariantTests {
    @Test func allCasesCoversBothVariants() {
        #expect(GlyphVariant.allCases == [.arc, .segmented])
        #expect(Set(GlyphVariant.allCases.map(\.rawValue)) == ["arc", "segmented"])
        // An unknown persisted string must not resolve — ClockModel relies on
        // the nil to fall back to `.arc`.
        #expect(GlyphVariant(rawValue: "ring") == nil)
    }
}
