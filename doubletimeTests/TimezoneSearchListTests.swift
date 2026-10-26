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

struct TimezoneSearchListTests {
    private static let size = NSSize(width: 300, height: 320)

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
