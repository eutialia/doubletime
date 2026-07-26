//
//  GlyphRenderTests.swift
//  doubletimeTests
//

import AppKit
import SwiftUI
import Testing
@testable import doubletime

struct GlyphRenderTests {
    // MARK: HourCell.Tone.isDim (trivial, direct)

    @Test func toneIsDimReflectsOnlySecondary() {
        #expect(HourCell.Tone.primary.isDim == false)
        #expect(HourCell.Tone.secondary.isDim == true)
    }

    // MARK: 12-hour glyph path (TimeGlyph + HourCell period/hue branch)

    /// LA (PDT) is 05:00 AM and Kolkata (IST) is 17:30 PM at `reference`, so
    /// this pair exercises both periods. hour12 tints the chips with a real
    /// hue (see DesignTokens.hueChipFill) instead of the neutral 24-hour
    /// fill, so the two renders must differ pixel-for-pixel even though the
    /// zero-padded hour STRING happens to read "05" in both formats here.
    @Test @MainActor func twelveHourModeChangesRenderedPixelsFromTwentyFourHour() throws {
        func render(hour12: Bool) throws -> Data {
            let raster = StatusItemRaster(scale: 1) {
                TimeGlyph(
                    secondaryLabel: "IST", secondaryTimezone: timezone("Asia/Kolkata"),
                    primaryLabel: "PDT", primaryTimezone: timezone("America/Los_Angeles"),
                    now: reference, hour12: hour12, variant: .arc
                )
            }
            return try pixelData(of: raster.rasterize(pixelScale: 4))
        }
        #expect(try render(hour12: false) != render(hour12: true))
    }

    /// The hovered swap-minute path is exercised elsewhere in 24-hour mode
    /// (doubletimeTests.hoverSwapsMinuteWidthNeutrally); this pins the same
    /// behavior for the 12-hour path, where the swapped ink also picks up the
    /// secondary zone's period hue (TrailingMinute.digits, minuteSwapInk).
    @Test @MainActor func hoveredTwelveHourMinuteSwapChangesRenderedPixels() throws {
        func render(hovered: Bool) throws -> Data {
            let raster = StatusItemRaster(scale: 1) {
                TimeGlyph(
                    secondaryLabel: "KAT", secondaryTimezone: timezone("Asia/Kathmandu"),
                    primaryLabel: "PDT", primaryTimezone: timezone("America/Los_Angeles"),
                    now: reference, hour12: true, variant: .arc, hovered: hovered
                )
            }
            return try pixelData(of: raster.rasterize(pixelScale: 4))
        }
        #expect(try render(hovered: false) != render(hovered: true))
    }

    // MARK: Segmented vs arc variant (HourCell's segmented quarters>0 branch)

    /// Kolkata over Los Angeles is a 750-minute offset (12:30h): a genuine
    /// :30 fractional remainder, so the arc draws a continuous half-sweep
    /// while segmented draws two dashed quarter-ticks — the renders must
    /// differ.
    @Test @MainActor func segmentedVariantRendersDifferentlyFromArcForAFractionalOffset() throws {
        func render(variant: GlyphVariant) throws -> Data {
            let raster = StatusItemRaster(scale: 1) {
                TimeGlyph(
                    secondaryLabel: "IST", secondaryTimezone: timezone("Asia/Kolkata"),
                    primaryLabel: "PDT", primaryTimezone: timezone("America/Los_Angeles"),
                    now: reference, variant: variant
                )
            }
            return try pixelData(of: raster.rasterize(pixelScale: 4))
        }
        let arc = try render(variant: .arc)
        let segmented = try render(variant: .segmented)
        #expect(arc != segmented)
    }

    /// Tokyo over Los Angeles is a whole-hour (960 min) offset — fraction 0 —
    /// so HourCell's indicator overlay draws nothing for EITHER variant (the
    /// `if fraction > 0` guard wraps both the .arc and .segmented cases): the
    /// two renders must be pixel-identical.
    @Test @MainActor func segmentedVariantMatchesArcForAWholeHourOffset() throws {
        func render(variant: GlyphVariant) throws -> Data {
            let raster = StatusItemRaster(scale: 1) {
                TimeGlyph(
                    secondaryLabel: "JST", secondaryTimezone: timezone("Asia/Tokyo"),
                    primaryLabel: "PDT", primaryTimezone: timezone("America/Los_Angeles"),
                    now: reference, variant: variant
                )
            }
            return try pixelData(of: raster.rasterize(pixelScale: 4))
        }
        let arc = try render(variant: .arc)
        let segmented = try render(variant: .segmented)
        #expect(arc == segmented)
    }

    // MARK: TrailingMinute defaults (lines 26, 28, 38, 41 — property initializers)

    /// Constructs TrailingMinute with every parameter but `minute` left at
    /// its default (blink=false, swapped=false, rollsUp=true,
    /// secondaryPeriod=nil), which is the only way those default-value
    /// expressions execute — every other call site in the app (TimeGlyph)
    /// always passes them explicitly.
    @Test @MainActor func trailingMinuteWithAllDefaultsRendersNonVacuousInk() throws {
        let scan = try RasterScan(
            of: TrailingMinute(minute: "42")
                .padding(4)
                .background(Color(hex: 0x2D2D_2D))
                .environment(\.colorScheme, .dark),
            compositedOn: 0x2D
        )
        let hasInk = (0..<scan.height).contains { y in (0..<scan.width).contains { x in scan.isInk(x, y) } }
        #expect(hasInk)
    }

    // MARK: TrailingMinute blink path (lines 77–79)

    /// TrailingMinute's blink colon is a `TimelineView(.periodic(from: .now,
    /// by: 1))` with no injectable date — the ONLY way to exercise
    /// `ClockModel.colonVisible(at:)` on this actual rendering path (rather
    /// than as the pure function tested in doubletimeTests.colonParity) is to
    /// render at a real wall-clock instant and pin the result to that
    /// instant's second parity. Ink-pixel COUNT (not a hardcoded column) is
    /// the comparison, so it survives font/tracking changes.
    @Test @MainActor func blinkingColonHasMoreInkOnAnEvenSecondThanAnOdd() throws {
        /// Enters the wanted parity at the START of a second: spin until the
        /// parity is WRONG (the second under way has just run out), then spin
        /// until it flips back. Waiting only for the right parity would return
        /// with however little of that second remained — possibly ~0ms — and
        /// the render could land on the far side of the flip.
        func waitForEpochSecondParity(even: Bool) {
            func hasWantedParity() -> Bool {
                Int(Date().timeIntervalSince1970.rounded(.down)) % 2 == (even ? 0 : 1)
            }
            while hasWantedParity() { usleep(15_000) }
            while !hasWantedParity() { usleep(15_000) }
        }
        func inkPixelCount() throws -> Int {
            let scan = try RasterScan(
                of: TrailingMinute(minute: "00", blink: true)
                    .padding(4)
                    .background(Color(hex: 0x2D2D_2D))
                    .environment(\.colorScheme, .dark),
                compositedOn: 0x2D
            )
            var count = 0
            for y in 0..<scan.height {
                for x in 0..<scan.width where scan.isInk(x, y) {
                    count += 1
                }
            }
            return count
        }

        waitForEpochSecondParity(even: true)
        let evenCount = try inkPixelCount()
        waitForEpochSecondParity(even: false)
        let oddCount = try inkPixelCount()

        #expect(evenCount > oddCount, "colon ink should disappear on an odd second (blink hides it at opacity 0)")
    }
}
