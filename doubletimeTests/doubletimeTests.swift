//
//  doubletimeTests.swift
//  doubletimeTests
//

import Foundation
import SwiftUI
import Testing
@testable import doubletime

struct doubletimeTests {
    // MARK: anchoredSweep (signed, from UTC offsets)

    @Test(arguments: [
        ("Asia/Kolkata", "America/Los_Angeles", 0.5, true),      // half hour ahead ⇒ clockwise
        ("Asia/Kathmandu", "America/Los_Angeles", 0.75, true),   // three-quarter ahead ⇒ clockwise
        ("America/Los_Angeles", "Asia/Kolkata", 0.5, false),     // half hour behind ⇒ counterclockwise
        ("America/Los_Angeles", "Asia/Kathmandu", 0.75, false),  // three-quarter behind ⇒ counterclockwise
        ("Asia/Tokyo", "America/Los_Angeles", 0.0, true),        // whole-hour offset ⇒ no fraction, still a deterministic direction
    ])
    func anchoredSweepFractionAndDirection(
        secondaryId: String, primaryId: String, expectedFraction: Double, expectedClockwise: Bool
    ) {
        let sweep = ClockModel.anchoredSweep(
            secondary: timezone(secondaryId),
            primary: timezone(primaryId),
            at: reference
        )
        #expect(sweep.fraction == expectedFraction)
        #expect(sweep.clockwise == expectedClockwise)
    }

    // MARK: 24-hour formatting

    @Test(arguments: [
        ("Pacific/Wallis", "00"),        // 12:00 UTC is 00:00 in a UTC+12 zone (no DST) — "24" must render "00".
        ("Asia/Tokyo", "21"),            // 12:00 UTC is 21:00 JST.
        ("America/Los_Angeles", "05"),   // 12:00 UTC is 05:00 in Los Angeles (PDT, UTC-7).
    ])
    func hourIsZeroPaddedAndWrapsMidnightToDoubleZero(timezoneId: String, expectedHour: String) {
        #expect(ClockModel.hour(for: timezone(timezoneId), at: reference) == expectedHour)
    }

    // MARK: 12-hour mapping

    @Test(arguments: [
        ("Pacific/Wallis", "12", ClockModel.Period.am),        // UTC+12, no DST — 00:00 at the reference instant.
        ("UTC", "12", ClockModel.Period.pm),                   // UTC is 12:00 at the reference instant.
        ("Etc/GMT-1", "01", ClockModel.Period.pm),             // Etc/GMT-1 is UTC+1 (sign inverted) — 13:00 at the reference instant.
        ("America/Los_Angeles", "05", ClockModel.Period.am),   // Los Angeles (PDT) is 05:00 at the reference instant.
    ])
    func hour12MapsTwentyFourHourToTwelveHourWithPeriod(
        timezoneId: String, expectedHour: String, expectedPeriod: ClockModel.Period
    ) {
        #expect(ClockModel.hour12(for: timezone(timezoneId), at: reference) == expectedHour)
        #expect(ClockModel.period(for: timezone(timezoneId), at: reference) == expectedPeriod)
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

    @Test func defaultLabelUsesDictionaryAbbreviationBothSeasons() {
        let jan = utcInstant(month: 1, day: 15, hour: 12)
        let jul = utcInstant(month: 7, day: 15, hour: 12)
        // Kolkata/Tokyo have no DST; abbreviation(for:) returns an offset string,
        // so the purely-alphabetic dictionary entry wins in both seasons.
        #expect(ClockModel.defaultLabel(for: timezone("Asia/Kolkata"), at: jan) == "IST")
        #expect(ClockModel.defaultLabel(for: timezone("Asia/Kolkata"), at: jul) == "IST")
        #expect(ClockModel.defaultLabel(for: timezone("Asia/Tokyo"), at: jan) == "JST")
        #expect(ClockModel.defaultLabel(for: timezone("Asia/Tokyo"), at: jul) == "JST")
    }

    @Test func defaultLabelIsDaylightSavingAware() {
        // New_York: EST in winter, EDT in summer (abbreviation(for:) is alphabetic).
        #expect(ClockModel.defaultLabel(for: timezone("America/New_York"), at: utcInstant(month: 1, day: 15, hour: 12)) == "EST")
        #expect(ClockModel.defaultLabel(for: timezone("America/New_York"), at: utcInstant(month: 7, day: 15, hour: 12)) == "EDT")
        // London: GMT in winter (alphabetic abbreviation), BST in summer (its
        // summer abbreviation is an offset string, so the dictionary entry wins).
        #expect(ClockModel.defaultLabel(for: timezone("Europe/London"), at: utcInstant(month: 1, day: 15, hour: 12)) == "GMT")
        #expect(ClockModel.defaultLabel(for: timezone("Europe/London"), at: utcInstant(month: 7, day: 15, hour: 12)) == "BST")
    }

    @Test func defaultLabelFallsBackToCityPrefix() {
        // Kathmandu has no alphabetic abbreviation and no dictionary entry.
        #expect(ClockModel.defaultLabel(for: timezone("Asia/Kathmandu"), at: reference) == "KAT")
    }

    // MARK: Label sanitizer

    @Test(arguments: [
        ("Tokyo Office", "TOKYO"),  // clamps to 5 chars and uppercases
        ("pacific", "PACIF"),       // clamps to 5 chars and uppercases
        ("N.Y.C!", "NYC"),          // strips symbols
        ("🕐JST", "JST"),           // strips emoji
        (nil, nil),                 // nil stays nil
        ("   ", nil),               // pure whitespace becomes nil
        ("···", nil),               // pure symbols become nil
    ])
    func sanitizedLabel(input: String?, expected: String?) {
        #expect(ClockModel.sanitizedLabel(input) == expected)
    }

    @Test func resolvedLabelSanitizesStaleOverride() {
        // A persisted pre-v2 override is repaired at resolve time…
        #expect(ClockModel.resolvedLabel(override: "Tokyo Office", for: timezone("Asia/Tokyo"), at: reference) == "TOKYO")
        // …and an empty/whitespace override falls through to the derived default.
        #expect(ClockModel.resolvedLabel(override: "  ", for: timezone("Asia/Tokyo"), at: reference) == "JST")
    }

    // MARK: Offset minutes (sign convention)

    @Test func offsetMinutesSign() {
        // Kolkata (UTC+5:30) is 750 min ahead of Los Angeles (PDT, UTC-7) at the
        // reference instant; the reverse is negative.
        let kolkata = timezone("Asia/Kolkata")
        let la = timezone("America/Los_Angeles")
        #expect(ClockModel.offsetMinutes(from: kolkata, to: la, at: reference) == 750)
        #expect(ClockModel.offsetMinutes(from: la, to: kolkata, at: reference) == -750)
        #expect(ClockModel.offsetMinutes(from: la, to: la, at: reference) == 0)
    }

    // MARK: Offset captions

    /// The status menu's caption never collapses: whole hours keep `:00` and a
    /// zero offset still renders, so the row's layout can't reflow. 750 is the
    /// design card's own example (Kolkata over Los Angeles) — a two-digit hour
    /// that must not lose its padding.
    @Test(arguments: [
        (330, "+5:30"),
        (-120, "\u{2212}2:00"),
        (0, "+0:00"),
        (345, "+5:45"),
        (750, "+12:30"),
    ])
    func offsetCaptionExactKeepsAFixedShape(minutes: Int, expected: String) {
        #expect(ClockModel.offsetCaption(minutes: minutes, style: .exact) == expected)
    }

    @Test(arguments: [
        (0, "same"),
        (300, "+5h"),
        (-480, "\u{2212}8h"),
        (330, "+5:30"),
    ])
    func offsetCaptionTerseCollapsesCommonCases(minutes: Int, expected: String) {
        #expect(ClockModel.offsetCaption(minutes: minutes, style: .terse) == expected)
    }

    @Test func offsetCaptionSignIsMinusNotHyphen() {
        // U+2212 shares the tabular digits' width; a hyphen would sit narrow.
        let negative = ClockModel.offsetCaption(minutes: -750, style: .exact)
        #expect(negative.hasPrefix("\u{2212}"))
        #expect(!negative.contains("-"))
    }

    @Test func spokenOffsetReadsAsWords() {
        #expect(ClockModel.spokenOffset(minutes: 0) == "same time")
        #expect(ClockModel.spokenOffset(minutes: 750).hasSuffix("ahead"))
        #expect(ClockModel.spokenOffset(minutes: -750).hasSuffix("behind"))
        // Zero-value units are hidden, so a whole-hour offset says no "0 minutes".
        #expect(!ClockModel.spokenOffset(minutes: 300).contains("0 minutes"))
    }

    // MARK: Date label

    @Test func dateLabelPutsDayBeforeMonth() {
        // Canon shape: `Mon 20 Apr`, matching the 24-hour digits' reading order.
        #expect(ClockModel.dateLabel(for: timezone("America/Los_Angeles"), at: reference) == "Mon 20 Apr")
        // 12:00 UTC is already the 21st in Auckland (UTC+12).
        #expect(ClockModel.dateLabel(for: timezone("Pacific/Auckland"), at: reference) == "Tue 21 Apr")
    }

    @Test func dateLabelIsFixedNotLocalized() throws {
        // A localized style would reorder to `Mon, Apr 20` and add a comma; the
        // verbatim style must not, whatever locale the host happens to run under.
        let label = ClockModel.dateLabel(for: timezone("UTC"), at: reference)
        let day = try #require(label.range(of: "20"))
        let month = try #require(label.range(of: "Apr"))
        #expect(day.lowerBound < month.lowerBound)
        #expect(!label.contains(","))
    }

    // MARK: Day delta

    @Test func dayDeltaCrossesTheDateBoundary() {
        // 12:00 UTC — Auckland is already the 21st, Los Angeles still the 20th.
        let auckland = timezone("Pacific/Auckland")
        let la = timezone("America/Los_Angeles")
        #expect(ClockModel.dayDelta(from: auckland, to: la, at: reference) == 1)
        #expect(ClockModel.dayDelta(from: la, to: auckland, at: reference) == -1)
        #expect(ClockModel.dayDelta(from: la, to: la, at: reference) == 0)
    }

    @Test func dayDeltaIsZeroForALargeSameDayOffset() {
        // Kolkata is 750 minutes ahead of LA yet the calendar day is the same —
        // the delta must come from the dates, not from the offset's magnitude.
        #expect(ClockModel.offsetMinutes(from: timezone("Asia/Kolkata"), to: timezone("America/Los_Angeles"), at: reference) == 750)
        #expect(ClockModel.dayDelta(from: timezone("Asia/Kolkata"), to: timezone("America/Los_Angeles"), at: reference) == 0)
    }

    @Test func dayDeltaSurvivesADstTransition() throws {
        // 2026-03-08 10:30 UTC: Los Angeles has just sprung forward to PDT
        // (02:30 local), London is still on GMT (10:30). Same calendar day, and
        // the zone whose clock jumped must not read as a day apart.
        let springForward = utcInstant(month: 3, day: 8, hour: 10, minute: 30)
        #expect(ClockModel.dayDelta(from: timezone("Europe/London"), to: timezone("America/Los_Angeles"), at: springForward) == 0)
        #expect(ClockModel.dateLabel(for: timezone("America/Los_Angeles"), at: springForward) == "Sun 08 Mar")
    }

    @Test func dayDeltaReachesTwoDaysAcrossTheFullZoneSpan() {
        // The zone span is 26 hours, not 24: at 10:00 UTC, Kiritimati (UTC+14) is
        // 00:00 on the 21st while Midway (UTC−11) is still 23:00 on the 19th. The
        // row must not describe that as "next day".
        let instant = utcInstant(month: 4, day: 20, hour: 10)
        let kiritimati = timezone("Pacific/Kiritimati")
        let midway = timezone("Pacific/Midway")
        #expect(ClockModel.dayDelta(from: kiritimati, to: midway, at: instant) == 2)
    }

    @Test(arguments: [
        (2, "2 days later"),
        (-2, "2 days earlier"),
        (1, "next day"),
        (-1, "previous day"),
        (0, nil),
    ])
    func spokenDayDelta(delta: Int, expected: String?) {
        #expect(ClockModel.spokenDayDelta(delta) == expected)
    }

    // MARK: Status menu rows

    @Test func statusMenuSecondaryRowCarriesOffsetAndDayDelta() {
        let auckland = timezone("Pacific/Auckland")
        let row = StatusMenuZone.make(
            timezone: auckland,
            code: "NZST",
            hour12: false,
            isPrimary: false,
            offsetMinutes: ClockModel.offsetMinutes(from: auckland, to: timezone("America/Los_Angeles"), at: reference),
            dayDelta: 1,
            at: reference
        )
        #expect(row.city == "Auckland")
        #expect(row.time == "00:00")
        #expect(row.caption == "Tue 21 Apr")
        #expect(row.offset == "+19:00  +1d")
        #expect(row.period == nil)
    }

    @Test func statusMenuPrimaryRowHasNoOffset() {
        // The primary zone is the anchor everything else is measured from.
        let row = StatusMenuZone.make(
            timezone: timezone("America/Los_Angeles"),
            code: "PDT", hour12: false, isPrimary: true,
            offsetMinutes: nil, dayDelta: 0, at: reference
        )
        #expect(row.offset == nil)
        #expect(row.isPrimary)
        #expect(row.time == "05:00")
    }

    @Test func statusMenuSpellsPeriodInTheCaptionNotOnTheChip() {
        // The one surface where AM/PM is written out — and it goes in the
        // caption, so the time chip itself stays pure hue.
        let row = StatusMenuZone.make(
            timezone: timezone("America/Los_Angeles"),
            code: "PDT", hour12: true, isPrimary: true,
            offsetMinutes: nil, dayDelta: 0, at: reference
        )
        #expect(row.time == "05:00")
        #expect(row.period == .am)
        #expect(row.caption == "Mon 20 Apr · AM")
        #expect(!row.time.contains("AM"))
    }

    @Test func statusMenuAccessibilityLabelSpeaksOffsetAsWords() {
        let row = StatusMenuZone.make(
            timezone: timezone("Pacific/Auckland"),
            code: "NZST", hour12: false, isPrimary: false,
            offsetMinutes: 1140, dayDelta: 1, at: reference
        )
        #expect(row.accessibilityLabel.contains("Auckland"))
        #expect(row.accessibilityLabel.contains("ahead"))
        #expect(row.accessibilityLabel.contains("next day"))
        // The visible "+19:00" glyph must not be what VoiceOver reads.
        #expect(!row.accessibilityLabel.contains("+19:00"))
    }

    // MARK: Minute digits

    @Test func minuteRendersZoneWallClock() {
        // 12:00 UTC → Kathmandu (UTC+5:45) 17:45, Kolkata (UTC+5:30) 17:30,
        // Los Angeles (PDT) 05:00.
        #expect(ClockModel.minute(for: timezone("Asia/Kathmandu"), at: reference) == "45")
        #expect(ClockModel.minute(for: timezone("Asia/Kolkata"), at: reference) == "30")
        #expect(ClockModel.minute(for: timezone("America/Los_Angeles"), at: reference) == "00")
    }

    // MARK: Hover (secondary-minute swap)

    /// Hover must swap the trailing minute (pixels change) WITHOUT changing
    /// the rendered footprint — the status item length must never move.
    @Test @MainActor func hoverSwapsMinuteWidthNeutrally() throws {
        func render(hovered: Bool) throws -> NSImage {
            // Through the production raster path (internal for exactly this
            // purpose), so the test fails if rasterize() drifts from the strip.
            try #require(StatusItemRaster(scale: 1) { hoverGlyph(hovered: hovered) }
                .rasterize(pixelScale: 4))
        }
        let plain = try render(hovered: false)
        let hovered = try render(hovered: true)
        #expect(try pixelData(of: plain) != pixelData(of: hovered))
        #expect(plain.size == hovered.size)
    }

    /// A whole-hour pair draws no indicator, and hover must be a complete
    /// no-op — pixel-identical output.
    @Test @MainActor func hoverIsNoOpForWholeHourPair() throws {
        func render(hovered: Bool) throws -> Data {
            let raster = StatusItemRaster(scale: 1) {
                hoverGlyph(hovered: hovered, secondaryId: "Asia/Tokyo")
            }
            return try pixelData(of: raster.rasterize(pixelScale: 4))
        }
        #expect(try render(hovered: false) == render(hovered: true))
    }

    /// The hovered state obeys the same zero-overflow rule as the rest of the
    /// ensemble inside the fixed 22pt strip (macOS clips status items).
    @Test @MainActor func hoveredEnsembleFitsInsideStatusStrip() throws {
        let scan = try RasterScan(of: hoverGlyph(hovered: true).statusItemStrip())

        func rowHasInk(_ y: Int) -> Bool {
            (0..<scan.width).contains { scan.isInk($0, y) }
        }

        let firstInkRow = try #require((0..<scan.height).first(where: rowHasInk))
        let lastInkRow = try #require((0..<scan.height).reversed().first(where: rowHasInk))
        #expect(firstInkRow > 0, "hovered ink clips at the status button top")
        #expect(lastInkRow < scan.height - 1, "hovered ink clips at the status button bottom")
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
    @MainActor func perimeterQuarterLandsOnEdgeCenter(fraction: Double, expected: CGPoint) throws {
        let rect = CGRect(origin: .zero, size: DesignTokens.cellSize)
        let path = CellPerimeter().path(in: rect)
        let end = try #require(path.trimmedPath(from: 0, to: fraction).currentPoint)
        #expect(abs(end.x - expected.x) < 0.05)
        #expect(abs(end.y - expected.y) < 0.05)
    }

    @Test @MainActor func perimeterStartsAtTopCenter() throws {
        let rect = CGRect(origin: .zero, size: DesignTokens.cellSize)
        let start = try #require(CellPerimeter().path(in: rect)
            .trimmedPath(from: 0, to: 0.001).currentPoint)
        #expect(abs(start.x - 9.5) < 0.15)
        #expect(abs(start.y - 0) < 0.15)
    }

    /// Cross-checks `CellPerimeter.perimeterLength` against the path SwiftUI
    /// actually draws, not against a copy of its own formula (which could
    /// never fail): sample `trimmedPath(from:to:)` at ~200 evenly spaced `t`
    /// and sum the resulting chord lengths. Trim is proportional to arc
    /// length, so this reconstructs the true perimeter length. The formula
    /// sizes segmented-tick dash patterns, so it must track the drawn path
    /// exactly.
    @Test @MainActor func perimeterLengthMatchesFormula() throws {
        let rect = CGRect(origin: .zero, size: DesignTokens.cellSize)
        let path = CellPerimeter().path(in: rect)

        let sampleCount = 200
        var measuredLength: CGFloat = 0
        var previousPoint: CGPoint?
        for i in 0...sampleCount {
            let t = max(Double(i) / Double(sampleCount), 0.0001)
            let point = try #require(path.trimmedPath(from: 0, to: t).currentPoint)
            if let previousPoint {
                let dx = point.x - previousPoint.x
                let dy = point.y - previousPoint.y
                measuredLength += (dx * dx + dy * dy).squareRoot()
            }
            previousPoint = point
        }

        let formulaLength = CellPerimeter.perimeterLength(in: rect)
        #expect(abs(formulaLength - measuredLength) < 0.1)
    }

    /// The indicator ring must draw inside (or flush with) the cell bounds —
    /// never past them, where macOS would clip it — and stay concentric.
    /// These guard the currently tuned token VALUES (re-tuning arcLineWidth,
    /// indicatorExtraInset, or cellCornerRadius must not silently violate the
    /// invariant); they deliberately don't re-derive DesignTokens' own
    /// formulas, which would be tautological and could never fail.
    @Test @MainActor func indicatorRingStaysConcentricInsideCell() {
        // Outer stroke edge stays inside the cell edge (≥ 0 ⇒ the stroke never
        // escapes the cell bounds; 0 = flush).
        #expect(DesignTokens.indicatorInset - DesignTokens.arcLineWidth / 2 >= 0)
        // Concentric radius stays positive (the max(_, 0) floor is never hit).
        #expect(DesignTokens.indicatorCornerRadius > 0)
    }

    /// Regression guard for the settings exemplars: GlyphChip shows whatever
    /// StatusItemRaster.rasterize produces, so that production path must yield
    /// exactly the canonical status strip (View.statusItemStrip) at the chip's
    /// pixel density — catching rasterize() drifting from the shared
    /// composition (wrong scale math, dropped or extra modifiers).
    @Test @MainActor func statusItemRasterMatchesCanonicalStrip() throws {
        let pixelScale: CGFloat = 2 * 1.6  // retina display × chip magnification
        let raster = StatusItemRaster(scale: 1.6) { exemplarGlyph }
        let produced = try #require(raster.rasterize(pixelScale: pixelScale))
        // Pt geometry: the raster is exactly the 22pt status strip.
        #expect(produced.size.height == DesignTokens.statusItemHeight)
        #expect(produced.size.width > 0)

        #expect(try pixelData(of: produced)
                 == pixelData(of: exemplarGlyph.statusItemStrip(), scale: pixelScale))
    }

    /// The documented core invariant, verified on real pixels: the zone label's
    /// ink must float clear of the cell top (labelCellGap's whole purpose — the
    /// label must read as detached from the hour block) and therefore never
    /// merge with the indicator ring's ink (a full-sweep arc is the worst case —
    /// the whole top edge is stroked). Scans every column of a rendered
    /// secondary cell.
    @Test @MainActor func labelInkFloatsClearOfCellAndIndicator() throws {
        let padding: CGFloat = 8
        let scan = try RasterScan(
            of: HourCell(label: "PDT", hour: "09", fraction: 1, variant: .arc, tone: .secondary)
                .padding(padding)
                .background(Color(hex: 0x2D2D2D))
                .environment(\.colorScheme, .dark),
            compositedOn: 0x2D
        )

        let cellTop = Int(padding * RasterScan.pixelScale)
        // The label's ink seats ~0.25pt below its line-box bottom (which sits
        // labelCellGap above the cell top), and antialiasing can eat another
        // ~0.25pt — the remainder of the gap must survive as visible clearance.
        let requiredClearance = Int((DesignTokens.labelCellGap - 0.5) * RasterScan.pixelScale)
        #expect(requiredClearance > 0, "labelCellGap too small to ever read as detached")
        // Scan past the ring band's inner edge; deeper is digit territory.
        let scanBottom = cellTop
            + Int((DesignTokens.indicatorInset + DesignTokens.arcLineWidth) * RasterScan.pixelScale)
        var labelInkBottom = -1  // deepest ink belonging to a run that began above the cell
        for x in 0..<scan.width {
            var previousWasInk = false
            var inkStart = 0
            for y in 0..<min(scanBottom, scan.height) {
                let ink = scan.isInk(x, y)
                if ink && !previousWasInk { inkStart = y }
                if ink, inkStart < cellTop {
                    labelInkBottom = max(labelInkBottom, y)
                }
                previousWasInk = ink
            }
        }
        #expect(labelInkBottom >= 0, "no label ink found above the cell")
        #expect(labelInkBottom < cellTop - requiredClearance,
                "label ink crowds the cell top — reads as attached to the block")
    }

    /// The ensemble (label + gap + cell) must fit the fixed 22pt status button
    /// with zero overflow — macOS clips status items on every mirrored display.
    /// labelCellGap and statusItemGlyphNudge are coupled; this catches either
    /// drifting without the other being re-measured.
    @Test @MainActor func ensembleFitsInsideStatusStrip() throws {
        let scan = try RasterScan(of: exemplarGlyph.statusItemStrip())

        func rowHasInk(_ y: Int) -> Bool {
            (0..<scan.width).contains { scan.isInk($0, y) }
        }

        let firstInkRow = try #require((0..<scan.height).first(where: rowHasInk))
        let lastInkRow = try #require((0..<scan.height).reversed().first(where: rowHasInk))
        // Ink must not touch the strip edges (a touching row means clipping).
        #expect(firstInkRow > 0, "label ink clips at the status button top")
        #expect(lastInkRow < scan.height - 1, "cell ink clips at the status button bottom")
    }
}
