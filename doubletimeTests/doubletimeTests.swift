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
        #expect(ClockModel.dateLabel(for: timezone("America/Los_Angeles"), at: Self.reference) == "Mon 20 Apr")
        // 12:00 UTC is already the 21st in Auckland (UTC+12).
        #expect(ClockModel.dateLabel(for: timezone("Pacific/Auckland"), at: Self.reference) == "Tue 21 Apr")
    }

    @Test func dateLabelIsFixedNotLocalized() throws {
        // A localized style would reorder to `Mon, Apr 20` and add a comma; the
        // verbatim style must not, whatever locale the host happens to run under.
        let label = ClockModel.dateLabel(for: timezone("UTC"), at: Self.reference)
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
        #expect(ClockModel.dayDelta(from: auckland, to: la, at: Self.reference) == 1)
        #expect(ClockModel.dayDelta(from: la, to: auckland, at: Self.reference) == -1)
        #expect(ClockModel.dayDelta(from: la, to: la, at: Self.reference) == 0)
    }

    @Test func dayDeltaIsZeroForALargeSameDayOffset() {
        // Kolkata is 750 minutes ahead of LA yet the calendar day is the same —
        // the delta must come from the dates, not from the offset's magnitude.
        #expect(ClockModel.offsetMinutes(from: timezone("Asia/Kolkata"), to: timezone("America/Los_Angeles"), at: Self.reference) == 750)
        #expect(ClockModel.dayDelta(from: timezone("Asia/Kolkata"), to: timezone("America/Los_Angeles"), at: Self.reference) == 0)
    }

    @Test func dayDeltaSurvivesADstTransition() throws {
        // 2026-03-08 10:30 UTC: Los Angeles has just sprung forward to PDT
        // (02:30 local), London is still on GMT (10:30). Same calendar day, and
        // the zone whose clock jumped must not read as a day apart.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone("UTC")
        let springForward = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 10, minute: 30))
        )
        #expect(ClockModel.dayDelta(from: timezone("Europe/London"), to: timezone("America/Los_Angeles"), at: springForward) == 0)
        #expect(ClockModel.dateLabel(for: timezone("America/Los_Angeles"), at: springForward) == "Sun 08 Mar")
    }

    @Test func dayDeltaReachesTwoDaysAcrossTheFullZoneSpan() throws {
        // The zone span is 26 hours, not 24: at 10:00 UTC, Kiritimati (UTC+14) is
        // 00:00 on the 21st while Midway (UTC−11) is still 23:00 on the 19th. The
        // row must not describe that as "next day".
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone("UTC")
        let instant = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 4, day: 20, hour: 10))
        )
        let kiritimati = timezone("Pacific/Kiritimati")
        let midway = timezone("Pacific/Midway")
        #expect(ClockModel.dayDelta(from: kiritimati, to: midway, at: instant) == 2)
        #expect(ClockModel.spokenDayDelta(2) == "2 days later")
        #expect(ClockModel.spokenDayDelta(-2) == "2 days earlier")
        #expect(ClockModel.spokenDayDelta(1) == "next day")
        #expect(ClockModel.spokenDayDelta(-1) == "previous day")
        #expect(ClockModel.spokenDayDelta(0) == nil)
    }

    // MARK: Status menu rows

    @Test func statusMenuSecondaryRowCarriesOffsetAndDayDelta() {
        let auckland = timezone("Pacific/Auckland")
        let row = StatusMenuZone.make(
            timezone: auckland,
            code: "NZST",
            hour12: false,
            isPrimary: false,
            offsetMinutes: ClockModel.offsetMinutes(from: auckland, to: timezone("America/Los_Angeles"), at: Self.reference),
            dayDelta: 1,
            at: Self.reference
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
            offsetMinutes: nil, dayDelta: 0, at: Self.reference
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
            offsetMinutes: nil, dayDelta: 0, at: Self.reference
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
            offsetMinutes: 1140, dayDelta: 1, at: Self.reference
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
        #expect(ClockModel.minute(for: timezone("Asia/Kathmandu"), at: Self.reference) == "45")
        #expect(ClockModel.minute(for: timezone("Asia/Kolkata"), at: Self.reference) == "30")
        #expect(ClockModel.minute(for: timezone("America/Los_Angeles"), at: Self.reference) == "00")
    }

    // MARK: Hover (secondary-minute swap)

    /// A quarter-hour pair (Kathmandu +5:45 over PDT) so BOTH minute digits
    /// differ between the zones — the strongest swap exercise.
    private func hoverGlyph(hovered: Bool, secondaryId: String = "Asia/Kathmandu") -> some View {
        TimeGlyph(
            secondaryLabel: "KAT", secondaryTimezone: timezone(secondaryId),
            primaryLabel: "PDT", primaryTimezone: timezone("America/Los_Angeles"),
            now: Self.reference, variant: .arc, hovered: hovered
        )
    }

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
        #expect(plain.tiffRepresentation != hovered.tiffRepresentation)
        #expect(plain.size == hovered.size)
    }

    /// A whole-hour pair draws no indicator, and hover must be a complete
    /// no-op — pixel-identical output.
    @Test @MainActor func hoverIsNoOpForWholeHourPair() throws {
        func render(hovered: Bool) throws -> Data? {
            let raster = StatusItemRaster(scale: 1) {
                hoverGlyph(hovered: hovered, secondaryId: "Asia/Tokyo")
            }
            return try #require(raster.rasterize(pixelScale: 4)).tiffRepresentation
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

    @Test @MainActor func perimeterLengthMatchesFormula() {
        let rect = CGRect(origin: .zero, size: DesignTokens.cellSize)
        let r = DesignTokens.cellCornerRadius
        let expected = 2 * (rect.width + rect.height) - 8 * r + 2 * .pi * r
        #expect(abs(CellPerimeter.perimeterLength(in: rect) - expected) < 0.001)
    }

    /// The indicator ring must draw inside (or flush with) the cell bounds —
    /// never past them, where macOS would clip it — and stay concentric.
    @Test @MainActor func indicatorRingStaysConcentricInsideCell() {
        // Outer stroke edge sits indicatorExtraInset inside the cell edge (≥ 0
        // ⇒ the stroke never escapes the cell bounds; 0 = flush).
        #expect(abs((DesignTokens.indicatorInset - DesignTokens.arcLineWidth / 2)
                    - DesignTokens.indicatorExtraInset) < 1e-9)
        #expect(DesignTokens.indicatorInset - DesignTokens.arcLineWidth / 2 >= 0)
        // Concentric radius stays positive (the max(_, 0) floor is never hit).
        #expect(DesignTokens.indicatorCornerRadius > 0)
        #expect(abs(DesignTokens.indicatorCornerRadius
                    - (DesignTokens.cellCornerRadius - DesignTokens.indicatorInset)) < 1e-9)
    }

    /// Exemplar glyph shared by the rendering tests below.
    private var exemplarGlyph: some View {
        TimeGlyph(
            secondaryLabel: "PDT", secondaryTimezone: timezone("America/Los_Angeles"),
            primaryLabel: "IST", primaryTimezone: timezone("Asia/Kolkata"),
            now: Self.reference, variant: .arc
        )
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

        let reference = ImageRenderer(content: exemplarGlyph.statusItemStrip())
        reference.scale = pixelScale
        let referenceImage = try #require(reference.nsImage)
        #expect(produced.tiffRepresentation == referenceImage.tiffRepresentation)
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

/// Rasterizes a view once and answers "is this pixel dense ink?" for the
/// pixel-scanning tests. The ink threshold is DERIVED from DesignTokens —
/// midway between the brightest chip-fill alpha and the dimmest ink alpha
/// (secondary label / dim ring mark) — so re-tuned opacities can't silently
/// blind the scans.
@MainActor private struct RasterScan {
    /// Rendering density shared by all scans (16 subpixels per point).
    static let pixelScale: CGFloat = 16

    let width: Int
    let height: Int
    private let data: Data
    private let bytesPerRow: Int
    private let bytesPerPixel: Int
    /// Opaque backdrop the view was composited onto; nil ⇒ transparent
    /// background, ink is judged by the alpha channel instead of luminance.
    private let background: Int?

    init(of view: some View, compositedOn background: Int? = nil) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = Self.pixelScale
        let image = try #require(renderer.cgImage)
        width = image.width
        height = image.height
        data = try #require(image.dataProvider?.data as Data?)
        bytesPerRow = image.bytesPerRow
        bytesPerPixel = image.bitsPerPixel / 8
        self.background = background
    }

    /// Alpha midway between the faint cell fill and the dimmest dense ink.
    private var inkAlphaThreshold: Double {
        let fill = DesignTokens.chipFillAlpha(isPrimary: false, colorScheme: .dark)
        let ink = min(DesignTokens.secondaryLabelOpacity,
                      DesignTokens.markOpacity(isDim: true, colorScheme: .dark))
        return (fill + ink) / 2
    }

    /// True when the pixel carries dense ink (zone label, digits, or the
    /// indicator ring) rather than background or the faint cell fill.
    func isInk(_ x: Int, _ y: Int) -> Bool {
        let offset = y * bytesPerRow + x * bytesPerPixel
        if let background {
            // White ink at alpha a over gray b has luminance b + a(255 − b).
            let luminance = (Int(data[offset]) + Int(data[offset + 1]) + Int(data[offset + 2])) / 3
            return Double(luminance) > Double(background) + inkAlphaThreshold * Double(255 - background)
        }
        return Double(data[offset + 3]) > inkAlphaThreshold * 255
    }
}
