//
//  TimezoneSearchListTests.swift
//  doubletimeTests
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import doubletime

/// `ImageRenderer` does not rasterize `LazyVStack` content nested inside a
/// `ScrollView` — confirmed empirically (a control `ScrollView { LazyVStack {
/// ... } }` renders zero ink via `ImageRenderer`, but the identical view
/// renders correctly once given a REAL (if offscreen/borderless) `NSWindow`,
/// which is what a lazy stack needs to resolve its visible bounds). Since
/// TimezoneSearchList's rows live inside exactly that `ScrollView` +
/// `LazyVStack`, its row content needs this windowed path — `RasterScan` /
/// plain `ImageRenderer` (used everywhere else in this suite) would silently
/// see only the search field chrome and never the rows.
@MainActor
private func windowedBitmap(_ view: some View, size: NSSize) throws -> NSBitmapImageRep {
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = NSRect(origin: .zero, size: size)
    let window = NSWindow(
        contentRect: hostingView.frame, styleMask: [.borderless], backing: .buffered, defer: false
    )
    window.contentView = hostingView
    hostingView.layoutSubtreeIfNeeded()
    window.displayIfNeeded()

    let rep = try #require(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
    hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
    return rep
}

/// The dark `card` background is itself well above a naive low threshold, which
/// would count the WHOLE canvas as "ink" and mask any real content difference
/// (empirically: a threshold of 40 made a total-ink-count comparison measure
/// the exact same count with and without the extra row).
///
/// Derived from DesignTokens on the same rationale as `RasterScan`'s
/// `inkAlphaThreshold`: midway between the bare backdrop (the `card` token, ink
/// alpha 0) and the dimmest real ink element on this surface (the `hairline`
/// divider), composited over that backdrop the way `RasterScan.isInk` does it.
/// Currently ≈57, between the card's ≈47 and the hairline's ≈68 — a re-tuned
/// card or hairline moves it instead of silently blinding the scan.
@MainActor private let windowedInkLuminanceThreshold: Int = {
    let card = NSColor(DesignTokens.card)
    let hairline = NSColor(DesignTokens.hairline)
    var backdrop = 0.0
    var dimmestInkAlpha = 0.0
    // Fail fast rather than degrade: a nil appearance would leave the threshold
    // at 0, and a zero threshold counts every pixel as ink — vacuously green.
    guard let darkAqua = NSAppearance(named: .darkAqua) else {
        preconditionFailure("darkAqua appearance unavailable — threshold underivable")
    }
    darkAqua.performAsCurrentDrawingAppearance {
        let resolvedCard = card.usingColorSpace(.sRGB) ?? card
        backdrop = Double(resolvedCard.redComponent + resolvedCard.greenComponent
            + resolvedCard.blueComponent) / 3 * 255
        dimmestInkAlpha = Double((hairline.usingColorSpace(.sRGB) ?? hairline).alphaComponent)
    }
    // White ink at alpha a over the backdrop has luminance b + a(255 − b).
    return Int(backdrop + dimmestInkAlpha / 2 * (255 - backdrop))
}()

private struct WindowedPixels {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let bytesPerPixel: Int
    let data: Data

    func luminance(_ x: Int, _ y: Int) -> Int {
        let offset = y * bytesPerRow + x * bytesPerPixel
        return (Int(data[offset]) + Int(data[offset + 1]) + Int(data[offset + 2])) / 3
    }
}

@MainActor
private func windowedPixels(_ view: some View, size: NSSize) throws -> WindowedPixels {
    let rep = try windowedBitmap(view, size: size)
    let cgImage = try #require(rep.cgImage)
    let data = try #require(cgImage.dataProvider?.data as Data?)
    return WindowedPixels(
        width: cgImage.width, height: cgImage.height,
        bytesPerRow: cgImage.bytesPerRow, bytesPerPixel: cgImage.bitsPerPixel / 8, data: data
    )
}

@MainActor
private func windowedInkCount(_ view: some View, size: NSSize) throws -> Int {
    let pixels = try windowedPixels(view, size: size)
    var count = 0
    for y in 0..<pixels.height {
        for x in 0..<pixels.width where pixels.luminance(x, y) > windowedInkLuminanceThreshold {
            count += 1
        }
    }
    return count
}

struct TimezoneSearchListTests {
    private static let size = NSSize(width: 300, height: 320)

    /// The default (empty search) state renders the full unfiltered row list.
    /// Dark appearance + a dark composited card background, matching the rest
    /// of the suite's ink-detection convention (RasterScan's luminance check
    /// assumes ink is BRIGHTER than the backdrop, which only holds in dark
    /// mode here). The filtering logic itself (TimezoneSearch) already has
    /// its own pure-function tests elsewhere — this only pins that the list
    /// actually draws rows, not just its search field chrome.
    @Test @MainActor func rendersRowInkInTheDefaultUnfilteredState() throws {
        let view = TimezoneSearchList(referenceTimezone: timezone("America/Los_Angeles")) { _ in }
            .environment(\.colorScheme, .dark)
        let count = try windowedInkCount(view, size: Self.size)
        #expect(count > 0)
    }

    /// `includeSystemRow` adds a pinned "System (auto)" row (plus a divider)
    /// above the searched list, pushing every row below it down by one row's
    /// height — so the TOTAL ink count is a weak, noisy signal (adding a row
    /// at the top mostly just shifts existing ink rather than growing it, and
    /// two independent windowed renders differ by a few stray pixels of pure
    /// antialiasing jitter even for unrelated content). Comparing the region
    /// that visibly differs is the robust signal: inserting a whole extra row
    /// must change a LARGE swath of pixels (every row below it now shows
    /// different text), not just a handful.
    @Test @MainActor func includeSystemRowChangesALargeRegionOfPixels() throws {
        func render(includeSystemRow: Bool) throws -> WindowedPixels {
            let view = TimezoneSearchList(
                referenceTimezone: timezone("America/Los_Angeles"),
                includeSystemRow: includeSystemRow
            ) { _ in }
                .environment(\.colorScheme, .dark)
            return try windowedPixels(view, size: Self.size)
        }
        let without = try render(includeSystemRow: false)
        let with = try render(includeSystemRow: true)
        #expect(without.width == with.width && without.height == with.height)

        var differingPixels = 0
        for y in 0..<without.height {
            for x in 0..<without.width where abs(without.luminance(x, y) - with.luminance(x, y)) > 20 {
                differingPixels += 1
            }
        }
        // At least 1% of the canvas must differ — comfortably above stray
        // antialiasing noise (observed at a handful of pixels out of ~50,000)
        // and comfortably below what a genuine extra row + divider shifts.
        #expect(differingPixels > (without.width * without.height) / 100)
    }
}

struct TimezoneRowTests {
    private func tokyoOption() throws -> TimezoneOption {
        try #require(TimezoneOption.all.first { $0.id == "Asia/Tokyo" })
    }

    /// A fixed `now` and a fixed `option` must render byte-identically on
    /// repeat — nothing in the row should depend on ambient state.
    @Test @MainActor func rendersDeterministicallyForAFixedInstant() throws {
        let option = try tokyoOption()
        func render() throws -> Data {
            try pixelData(of: TimezoneRow(
                option: option, now: reference, referenceTimezone: timezone("America/Los_Angeles")
            ).frame(width: 260))
        }
        #expect(try render() == render())
    }

    /// The row's time text is derived from `now`; advancing it by a whole
    /// minute must change the rendered digits.
    @Test @MainActor func changesRenderedPixelsWhenNowAdvancesByAMinute() throws {
        let option = try tokyoOption()
        func render(at date: Date) throws -> Data {
            try pixelData(of: TimezoneRow(
                option: option, now: date, referenceTimezone: timezone("America/Los_Angeles")
            ).frame(width: 260))
        }
        #expect(try render(at: reference) != render(at: reference.addingTimeInterval(60)))
    }
}
