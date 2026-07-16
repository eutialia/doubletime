//
//  doubletimeTests.swift
//  doubletimeTests
//

import Foundation
import SwiftUI
import Testing
@testable import doubletime

struct doubletimeTests {
    /// 2026-04-20 12:00:00 UTC — a DST-stable reference instant (PDT in effect
    /// for Los Angeles).
    private static let reference: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: 2026, month: 4, day: 20, hour: 12))!
    }()

    private func timezone(_ identifier: String) -> TimeZone {
        TimeZone(identifier: identifier)!
    }

    // MARK: anchoredSweep (signed, from UTC offsets)

    @Test func anchoredSweepHalfHourAhead() {
        let sweep = ClockModel.anchoredSweep(
            secondary: timezone("Asia/Kolkata"),
            primary: timezone("America/Los_Angeles"),
            at: Self.reference
        )
        #expect(sweep.fraction == 0.5)
        #expect(sweep.clockwise)
    }

    @Test func anchoredSweepThreeQuarterAhead() {
        let sweep = ClockModel.anchoredSweep(
            secondary: timezone("Asia/Kathmandu"),
            primary: timezone("America/Los_Angeles"),
            at: Self.reference
        )
        #expect(sweep.fraction == 0.75)
        #expect(sweep.clockwise)
    }

    @Test func anchoredSweepHalfHourBehindIsCounterclockwise() {
        let sweep = ClockModel.anchoredSweep(
            secondary: timezone("America/Los_Angeles"),
            primary: timezone("Asia/Kolkata"),
            at: Self.reference
        )
        #expect(sweep.fraction == 0.5)
        #expect(!sweep.clockwise)
    }

    @Test func anchoredSweepThreeQuarterBehindIsCounterclockwise() {
        let sweep = ClockModel.anchoredSweep(
            secondary: timezone("America/Los_Angeles"),
            primary: timezone("Asia/Kathmandu"),
            at: Self.reference
        )
        #expect(sweep.fraction == 0.75)
        #expect(!sweep.clockwise)
    }

    @Test func anchoredSweepWholeHourHasNoFraction() {
        let sweep = ClockModel.anchoredSweep(
            secondary: timezone("Asia/Tokyo"),
            primary: timezone("America/Los_Angeles"),
            at: Self.reference
        )
        #expect(sweep.fraction == 0.0)
    }

    // MARK: 24-hour formatting

    @Test func hourRendersMidnightAsDoubleZero() {
        // 12:00 UTC is 00:00 in a UTC+12 zone (no DST) — "24" must render "00".
        let hour = ClockModel.hour(for: timezone("Pacific/Wallis"), at: Self.reference)
        #expect(hour == "00")
    }

    @Test func hourIsZeroPadded() {
        // 12:00 UTC is 21:00 JST and 05:00 in Los Angeles (PDT, UTC-7).
        #expect(ClockModel.hour(for: timezone("Asia/Tokyo"), at: Self.reference) == "21")
        #expect(ClockModel.hour(for: timezone("America/Los_Angeles"), at: Self.reference) == "05")
    }

    // MARK: 12-hour mapping

    @Test func hour12MapsMidnightToTwelveAM() {
        // Pacific/Wallis (UTC+12, no DST) is 00:00 at the reference instant.
        #expect(ClockModel.hour12(for: timezone("Pacific/Wallis"), at: Self.reference) == "12")
        #expect(ClockModel.period(for: timezone("Pacific/Wallis"), at: Self.reference) == .am)
    }

    @Test func hour12MapsNoonToTwelvePM() {
        // UTC is 12:00 at the reference instant.
        #expect(ClockModel.hour12(for: timezone("UTC"), at: Self.reference) == "12")
        #expect(ClockModel.period(for: timezone("UTC"), at: Self.reference) == .pm)
    }

    @Test func hour12MapsThirteenToOnePM() {
        // Etc/GMT-1 is UTC+1 (sign inverted) — 13:00 at the reference instant.
        #expect(ClockModel.hour12(for: timezone("Etc/GMT-1"), at: Self.reference) == "01")
        #expect(ClockModel.period(for: timezone("Etc/GMT-1"), at: Self.reference) == .pm)
    }

    @Test func hour12MapsFiveToFiveAM() {
        // Los Angeles (PDT) is 05:00 at the reference instant.
        #expect(ClockModel.hour12(for: timezone("America/Los_Angeles"), at: Self.reference) == "05")
        #expect(ClockModel.period(for: timezone("America/Los_Angeles"), at: Self.reference) == .am)
    }

    // MARK: Segmented snap

    @Test func segmentQuartersSnap() {
        #expect(ClockModel.segmentQuarters(fraction: 0.5) == 2)
        #expect(ClockModel.segmentQuarters(fraction: 0.75) == 3)
        #expect(ClockModel.segmentQuarters(fraction: 0.0) == 0)
    }

    // MARK: Colon parity

    @Test func colonParity() {
        #expect(ClockModel.colonVisible(at: Date(timeIntervalSince1970: 100)))  // even
        #expect(!ClockModel.colonVisible(at: Date(timeIntervalSince1970: 101))) // odd
    }

    // MARK: Default label

    /// Noon UTC in each season — DST is in effect in July, not January.
    private func instant(year: Int = 2026, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func defaultLabelUsesDictionaryAbbreviationBothSeasons() {
        let jan = instant(month: 1, day: 15)
        let jul = instant(month: 7, day: 15)
        // Kolkata/Tokyo have no DST; abbreviation(for:) returns an offset string,
        // so the purely-alphabetic dictionary entry wins in both seasons.
        #expect(ClockModel.defaultLabel(for: timezone("Asia/Kolkata"), at: jan) == "IST")
        #expect(ClockModel.defaultLabel(for: timezone("Asia/Kolkata"), at: jul) == "IST")
        #expect(ClockModel.defaultLabel(for: timezone("Asia/Tokyo"), at: jan) == "JST")
        #expect(ClockModel.defaultLabel(for: timezone("Asia/Tokyo"), at: jul) == "JST")
    }

    @Test func defaultLabelIsDaylightSavingAware() {
        // New_York: EST in winter, EDT in summer (abbreviation(for:) is alphabetic).
        #expect(ClockModel.defaultLabel(for: timezone("America/New_York"), at: instant(month: 1, day: 15)) == "EST")
        #expect(ClockModel.defaultLabel(for: timezone("America/New_York"), at: instant(month: 7, day: 15)) == "EDT")
        // London: GMT in winter (alphabetic abbreviation), BST in summer (its
        // summer abbreviation is an offset string, so the dictionary entry wins).
        #expect(ClockModel.defaultLabel(for: timezone("Europe/London"), at: instant(month: 1, day: 15)) == "GMT")
        #expect(ClockModel.defaultLabel(for: timezone("Europe/London"), at: instant(month: 7, day: 15)) == "BST")
    }

    @Test func defaultLabelFallsBackToCityPrefix() {
        // Kathmandu has no alphabetic abbreviation and no dictionary entry.
        #expect(ClockModel.defaultLabel(for: timezone("Asia/Kathmandu"), at: Self.reference) == "KAT")
    }

    // MARK: Label sanitizer

    @Test func sanitizedLabelClampsAndUppercases() {
        #expect(ClockModel.sanitizedLabel("Tokyo Office") == "TOKYO")
        #expect(ClockModel.sanitizedLabel("pacific") == "PACIF")
    }

    @Test func sanitizedLabelStripsSymbolsAndEmoji() {
        #expect(ClockModel.sanitizedLabel("N.Y.C!") == "NYC")
        #expect(ClockModel.sanitizedLabel("🕐JST") == "JST")
    }

    @Test func sanitizedLabelEmptyBecomesNil() {
        #expect(ClockModel.sanitizedLabel(nil) == nil)
        #expect(ClockModel.sanitizedLabel("   ") == nil)
        #expect(ClockModel.sanitizedLabel("···") == nil)
    }

    @Test func resolvedLabelSanitizesStaleOverride() {
        // A persisted pre-v2 override is repaired at resolve time…
        #expect(ClockModel.resolvedLabel(override: "Tokyo Office", for: timezone("Asia/Tokyo"), at: Self.reference) == "TOKYO")
        // …and an empty/whitespace override falls through to the derived default.
        #expect(ClockModel.resolvedLabel(override: "  ", for: timezone("Asia/Tokyo"), at: Self.reference) == "JST")
    }

    // MARK: Offset minutes (sign convention)

    @Test func offsetMinutesSign() {
        // Kolkata (UTC+5:30) is 750 min ahead of Los Angeles (PDT, UTC-7) at the
        // reference instant; the reverse is negative.
        let kolkata = timezone("Asia/Kolkata")
        let la = timezone("America/Los_Angeles")
        #expect(ClockModel.offsetMinutes(from: kolkata, to: la, at: Self.reference) == 750)
        #expect(ClockModel.offsetMinutes(from: la, to: kolkata, at: Self.reference) == -750)
        #expect(ClockModel.offsetMinutes(from: la, to: la, at: Self.reference) == 0)
    }

    // MARK: Clock-face perimeter

    /// The arc is parameterized by path length from 12 o'clock, clockwise:
    /// trim 0.25/0.5/0.75 must land exactly on the right/bottom/left edge
    /// centers (each edge-center→edge-center quadrant is (w+h)/2 long
    /// regardless of aspect ratio).
    @Test(arguments: [
        (0.25, CGPoint(x: 19, y: 8)),
        (0.5, CGPoint(x: 9.5, y: 16)),
        (0.75, CGPoint(x: 0, y: 8)),
    ])
    @MainActor func perimeterQuarterLandsOnEdgeCenter(fraction: Double, expected: CGPoint) {
        let rect = CGRect(origin: .zero, size: DesignTokens.cellSize)
        let path = CellPerimeter().path(in: rect)
        let end = path.trimmedPath(from: 0, to: fraction).currentPoint
        #expect(end != nil)
        if let end {
            #expect(abs(end.x - expected.x) < 0.05)
            #expect(abs(end.y - expected.y) < 0.05)
        }
    }

    @Test @MainActor func perimeterStartsAtTopCenter() {
        let rect = CGRect(origin: .zero, size: DesignTokens.cellSize)
        let start = CellPerimeter().path(in: rect)
            .trimmedPath(from: 0, to: 0.001).currentPoint
        #expect(start != nil)
        if let start {
            #expect(abs(start.x - 9.5) < 0.15)
            #expect(abs(start.y - 0) < 0.15)
        }
    }

    @Test @MainActor func perimeterLengthMatchesFormula() {
        let rect = CGRect(origin: .zero, size: DesignTokens.cellSize)
        let r = DesignTokens.cellCornerRadius
        let expected = 2 * (rect.width + rect.height) - 8 * r + 2 * .pi * r
        #expect(abs(CellPerimeter.perimeterLength(in: rect) - expected) < 0.001)
    }

    /// The indicator ring must draw fully inside the cell (its whole reason to
    /// exist: clearing the zone label) and stay concentric, at every scale.
    @Test(arguments: [1.0, 1.6] as [CGFloat])
    @MainActor func indicatorRingStaysConcentricInsideCell(scale: CGFloat) {
        let m = GlyphMetrics(scale: scale)
        // Outer stroke edge sits indicatorExtraInset inside the cell edge (> 0 ⇒ no
        // contact with the cell bounds or the label ink dipping past the top edge).
        #expect(abs((m.indicatorInset - m.arcLineWidth / 2) - m.indicatorExtraInset) < 1e-9)
        #expect(m.indicatorInset - m.arcLineWidth / 2 > 0)
        // Concentric radius stays positive (the max(_, 0) floor is never hit).
        #expect(m.indicatorCornerRadius > 0)
        #expect(abs(m.indicatorCornerRadius - (m.cellCornerRadius - m.indicatorInset)) < 1e-9)
    }
}
