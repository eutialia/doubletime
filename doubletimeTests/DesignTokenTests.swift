//
//  DesignTokenTests.swift
//  doubletimeTests
//

import AppKit
import SwiftUI
import Testing
@testable import doubletime

/// Local color-inspection helpers for this file's coverage of DesignTokens'
/// pure color/animation functions. sRGB-space NSColor components are the
/// common currency: exact for the explicit `Color(red:green:blue:opacity:)`
/// literals (chipFill/minuteSwapInk/Color(hex:)), and — wrapped in
/// `NSAppearance.performAsCurrentDrawingAppearance` — the way to force a
/// dynamic-provider `Color(nsColor:)` token (the settings surface tokens) to
/// resolve under a specific appearance outside of any real drawing context.
@MainActor
private func srgbComponents(_ color: NSColor) -> (r: Double, g: Double, b: Double, a: Double) {
    let resolved = color.usingColorSpace(.sRGB) ?? color
    return (Double(resolved.redComponent), Double(resolved.greenComponent),
            Double(resolved.blueComponent), Double(resolved.alphaComponent))
}

@MainActor
private func srgbComponents(_ color: Color) -> (r: Double, g: Double, b: Double, a: Double) {
    srgbComponents(NSColor(color))
}

/// Resolves a (possibly dynamic-provider-backed) `Color` under a specific
/// `NSAppearance`, the way AppKit resolves it during real drawing.
@MainActor
private func srgbComponents(_ color: Color, resolvingUnder appearance: NSAppearance) -> (r: Double, g: Double, b: Double, a: Double) {
    let nsColor = NSColor(color)
    var result: (r: Double, g: Double, b: Double, a: Double) = (0, 0, 0, 0)
    appearance.performAsCurrentDrawingAppearance {
        result = srgbComponents(nsColor)
    }
    return result
}

private func approximatelyEqual(
    _ lhs: (r: Double, g: Double, b: Double, a: Double),
    _ rhs: (r: Double, g: Double, b: Double, a: Double),
    tolerance: Double = 0.004
) -> Bool {
    abs(lhs.r - rhs.r) < tolerance && abs(lhs.g - rhs.g) < tolerance
        && abs(lhs.b - rhs.b) < tolerance && abs(lhs.a - rhs.a) < tolerance
}

/// One dynamic token under test. Carrying the accessor in the case means the
/// argument list IS the table — there is no stringly-typed lookup that can go
/// stale; `name` is display only.
fileprivate struct DynamicTokenCase: Sendable, CustomTestStringConvertible {
    let name: String
    let color: @MainActor @Sendable () -> Color

    var testDescription: String { name }

    static let all: [DynamicTokenCase] = [
        DynamicTokenCase(name: "canvas", color: { DesignTokens.canvas }),
        DynamicTokenCase(name: "card", color: { DesignTokens.card }),
        DynamicTokenCase(name: "fieldBackground", color: { DesignTokens.fieldBackground }),
        DynamicTokenCase(name: "textStrong", color: { DesignTokens.textStrong }),
        DynamicTokenCase(name: "textBody", color: { DesignTokens.textBody }),
        DynamicTokenCase(name: "textMuted", color: { DesignTokens.textMuted }),
        DynamicTokenCase(name: "textFaint", color: { DesignTokens.textFaint }),
        DynamicTokenCase(name: "hairline", color: { DesignTokens.hairline }),
        DynamicTokenCase(name: "cardBorder", color: { DesignTokens.cardBorder }),
        DynamicTokenCase(name: "fieldBorder", color: { DesignTokens.fieldBorder }),
        DynamicTokenCase(name: "radioRing", color: { DesignTokens.radioRing }),
        DynamicTokenCase(name: "searchFieldFill", color: { DesignTokens.searchFieldFill }),
        DynamicTokenCase(name: "controlTint", color: { DesignTokens.controlTint }),
    ]
}

struct DesignTokenTests {
    // MARK: chipFillAlpha / markOpacity — hierarchy invariants

    /// Fill contrast is the only hierarchy channel in 24-hour mode; the doc
    /// promises a gap of about 4.5x.
    @Test(arguments: [ColorScheme.light, .dark])
    func primaryChipFillAlphaClearlyExceedsSecondary(colorScheme: ColorScheme) {
        let primary = DesignTokens.chipFillAlpha(isPrimary: true, colorScheme: colorScheme)
        let secondary = DesignTokens.chipFillAlpha(isPrimary: false, colorScheme: colorScheme)
        #expect(primary > secondary * 4)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func brightMarkOpacityExceedsDim(colorScheme: ColorScheme) {
        #expect(DesignTokens.markOpacity(isDim: false, colorScheme: colorScheme)
                > DesignTokens.markOpacity(isDim: true, colorScheme: colorScheme))
    }

    // MARK: chipFill — period == nil path

    @Test(arguments: [true, false], [ColorScheme.light, .dark])
    @MainActor func chipFillWithNilPeriodIsPrimaryAtItsAlpha(isPrimary: Bool, colorScheme: ColorScheme) {
        let expected = Color.primary.opacity(DesignTokens.chipFillAlpha(isPrimary: isPrimary, colorScheme: colorScheme))
        #expect(DesignTokens.chipFill(isPrimary: isPrimary, period: nil, colorScheme: colorScheme) == expected)
    }

    // MARK: chipFill — the 8 (isPrimary × period × colorScheme) hue combos (lines 168–196)

    /// Pins the "single source" doc claim without copying the private
    /// `periodHue` table into the test: chipFill's hue (its rgb, ignoring
    /// alpha) must equal minuteSwapInk's hue for the SAME period/colorScheme,
    /// because both derive from the one private lookup.
    @Test(arguments: [ClockModel.Period.am, .pm], [ColorScheme.light, .dark])
    @MainActor func chipFillHueMatchesMinuteSwapInkForSamePeriodAndScheme(period: ClockModel.Period, colorScheme: ColorScheme) {
        let chip = srgbComponents(DesignTokens.chipFill(isPrimary: true, period: period, colorScheme: colorScheme))
        let ink = srgbComponents(DesignTokens.minuteSwapInk(period: period, colorScheme: colorScheme))
        #expect(abs(chip.r - ink.r) < 0.004)
        #expect(abs(chip.g - ink.g) < 0.004)
        #expect(abs(chip.b - ink.b) < 0.004)
        // The alphas must NOT coincidentally match — chipFill uses a
        // per-branch fill alpha (0.12–0.40) while minuteSwapInk always uses
        // full inkOpacity (0.96); if they ever did match it would mean one
        // of the two call sites regressed to sharing the wrong constant.
        #expect(abs(chip.a - ink.a) > 0.1)
    }

    @Test @MainActor func amHueDiffersBetweenLightAndDarkAppearance() {
        let light = srgbComponents(DesignTokens.chipFill(isPrimary: true, period: .am, colorScheme: .light))
        let dark = srgbComponents(DesignTokens.chipFill(isPrimary: true, period: .am, colorScheme: .dark))
        #expect(light.r != dark.r || light.g != dark.g || light.b != dark.b)
    }

    @Test @MainActor func pmHueDiffersBetweenLightAndDarkAppearance() {
        let light = srgbComponents(DesignTokens.chipFill(isPrimary: true, period: .pm, colorScheme: .light))
        let dark = srgbComponents(DesignTokens.chipFill(isPrimary: true, period: .pm, colorScheme: .dark))
        #expect(light.r != dark.r || light.g != dark.g || light.b != dark.b)
    }

    @Test @MainActor func amAndPmHuesDifferFromEachOther() {
        let am = srgbComponents(DesignTokens.chipFill(isPrimary: true, period: .am, colorScheme: .dark))
        let pm = srgbComponents(DesignTokens.chipFill(isPrimary: true, period: .pm, colorScheme: .dark))
        #expect(am.r != pm.r || am.g != pm.g || am.b != pm.b)
    }

    /// The primary/secondary fill-alpha gap is the ONLY hierarchy channel in
    /// 12-hour mode too (same doc rationale as the 24-hour chipFillAlpha
    /// table), across every period/scheme combination.
    @Test(arguments: [ClockModel.Period.am, .pm], [ColorScheme.light, .dark])
    @MainActor func primaryFillAlphaExceedsSecondaryForSamePeriodAndScheme(period: ClockModel.Period, colorScheme: ColorScheme) {
        let primaryAlpha = srgbComponents(DesignTokens.chipFill(isPrimary: true, period: period, colorScheme: colorScheme)).a
        let secondaryAlpha = srgbComponents(DesignTokens.chipFill(isPrimary: false, period: period, colorScheme: colorScheme)).a
        #expect(primaryAlpha > secondaryAlpha)
    }

    // MARK: minuteSwapInk

    @Test(arguments: [ColorScheme.light, .dark])
    @MainActor func minuteSwapInkWithNilPeriodIsPrimaryAtSecondaryLabelOpacity(colorScheme: ColorScheme) {
        let expected = Color.primary.opacity(DesignTokens.secondaryLabelOpacity)
        #expect(DesignTokens.minuteSwapInk(period: nil, colorScheme: colorScheme) == expected)
    }

    @Test(arguments: [ClockModel.Period.am, .pm], [ColorScheme.light, .dark])
    @MainActor func minuteSwapInkWithAPeriodUsesFullInkOpacity(period: ClockModel.Period, colorScheme: ColorScheme) {
        let alpha = srgbComponents(DesignTokens.minuteSwapInk(period: period, colorScheme: colorScheme)).a
        #expect(abs(alpha - DesignTokens.inkOpacity) < 0.004)
    }

    // MARK: minuteSwapAnimation(reduceMotion:)

    @Test func minuteSwapAnimationReduceMotionUsesTheCrossfadeDuration() {
        #expect(DesignTokens.minuteSwapAnimation(reduceMotion: true) == .easeInOut(duration: DesignTokens.minuteCrossfadeDuration))
    }

    @Test func minuteSwapAnimationNormallyUsesTheRollDuration() {
        #expect(DesignTokens.minuteSwapAnimation(reduceMotion: false) == .easeInOut(duration: DesignTokens.minuteRollDuration))
    }

    // MARK: Color(hex:) / NSColor(hex:) round trip

    @Test(arguments: [0xF0EE_E9, 0x2626_24, 0x0000_00, 0xFFFF_FF, 0x1A2B_3C] as [UInt32])
    @MainActor func colorHexRoundTripsTheLiteralsComponents(hex: UInt32) {
        let expectedR = Double((hex >> 16) & 0xFF) / 255
        let expectedG = Double((hex >> 8) & 0xFF) / 255
        let expectedB = Double(hex & 0xFF) / 255
        let actual = srgbComponents(Color(hex: hex))
        #expect(abs(actual.r - expectedR) < 0.004)
        #expect(abs(actual.g - expectedG) < 0.004)
        #expect(abs(actual.b - expectedB) < 0.004)
        #expect(abs(actual.a - 1) < 0.004)
    }

    @Test(arguments: [0xF0EE_E9, 0x2626_24, 0x0000_00, 0xFFFF_FF, 0x1A2B_3C] as [UInt32])
    @MainActor func nsColorHexRoundTripsTheLiteralsComponents(hex: UInt32) {
        let expectedR = Double((hex >> 16) & 0xFF) / 255
        let expectedG = Double((hex >> 8) & 0xFF) / 255
        let expectedB = Double(hex & 0xFF) / 255
        let actual = srgbComponents(NSColor(hex: hex))
        #expect(abs(actual.r - expectedR) < 0.004)
        #expect(abs(actual.g - expectedG) < 0.004)
        #expect(abs(actual.b - expectedB) < 0.004)
        #expect(actual.a == 1)
    }

    // MARK: Dynamic settings-surface tokens

    /// Resolves the provider under `.aqua` and `.darkAqua` explicitly (outside
    /// any real drawing context): canvas must land on its two literals.
    @MainActor @Test func canvasResolvesToItsLightAndDarkLiterals() throws {
        let aqua = try #require(NSAppearance(named: .aqua))
        let darkAqua = try #require(NSAppearance(named: .darkAqua))

        #expect(approximatelyEqual(
            srgbComponents(DesignTokens.canvas, resolvingUnder: aqua), srgbComponents(NSColor(hex: 0xF0EE_E9))))
        #expect(approximatelyEqual(
            srgbComponents(DesignTokens.canvas, resolvingUnder: darkAqua), srgbComponents(NSColor(hex: 0x2626_24))))
    }

    @Test(arguments: DynamicTokenCase.all)
    @MainActor fileprivate func dynamicTokenChangesBetweenAppearances(token: DynamicTokenCase) throws {
        let aqua = try #require(NSAppearance(named: .aqua))
        let darkAqua = try #require(NSAppearance(named: .darkAqua))
        let color = token.color()

        let resolvedLight = srgbComponents(color, resolvingUnder: aqua)
        let resolvedDark = srgbComponents(color, resolvingUnder: darkAqua)
        #expect(approximatelyEqual(resolvedLight, resolvedDark) == false, "\(token.name) must actually change between appearances")
    }
}
