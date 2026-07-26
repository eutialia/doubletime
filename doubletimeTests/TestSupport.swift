//
//  TestSupport.swift
//  doubletimeTests
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import doubletime

/// Builds a UTC instant from calendar components (gregorian, pinned to the
/// UTC time zone) so every reference date in the suite is constructed the
/// same deterministic way regardless of the host's locale or time zone.
func utcInstant(year: Int = 2026, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

func timezone(_ identifier: String) -> TimeZone {
    TimeZone(identifier: identifier)!
}

/// 2026-04-20 12:00:00 UTC — a DST-stable reference instant (PDT in effect
/// for Los Angeles).
let reference = utcInstant(month: 4, day: 20, hour: 12)

/// A quarter-hour pair (Kathmandu +5:45 over PDT) so BOTH minute digits
/// differ between the zones — the strongest swap exercise.
func hoverGlyph(hovered: Bool, secondaryId: String = "Asia/Kathmandu") -> some View {
    TimeGlyph(
        secondaryLabel: "KAT", secondaryTimezone: timezone(secondaryId),
        primaryLabel: "PDT", primaryTimezone: timezone("America/Los_Angeles"),
        now: reference, variant: .arc, hovered: hovered
    )
}

/// Exemplar glyph shared by the rendering tests below.
var exemplarGlyph: some View {
    TimeGlyph(
        secondaryLabel: "PDT", secondaryTimezone: timezone("America/Los_Angeles"),
        primaryLabel: "IST", primaryTimezone: timezone("Asia/Kolkata"),
        now: reference, variant: .arc
    )
}

/// A throwaway `UserDefaults` suite for the tests that touch persistence or
/// need a `ClockModel`. Swift Testing builds one suite instance per test, so
/// holding this as a stored property gives every test its own private store,
/// and `deinit` erases the domain when the test ends — no run can leave keys
/// behind in real preferences.
///
/// Honest about what cleanup cannot do: `cfprefsd` recreates an empty ~42-byte
/// plist moments after `deinit` deletes the file, so a run still ends with one
/// empty (contentless) plist per scratch suite in the container's Preferences
/// directory. Nothing readable survives — and the next run's first
/// `ScratchDefaults` sweeps those leftovers away before creating its own.
final class ScratchDefaults: @unchecked Sendable {
    /// One prefix for every scratch domain, so the sweep can recognise its own
    /// leftovers and nothing else.
    static let suiteNamePrefix = "com.lhdev.doubletime.tests."

    let suiteName = "\(ScratchDefaults.suiteNamePrefix)\(UUID().uuidString)"
    let store: UserDefaults

    init() {
        // `static let` is lazy and runs exactly once per process, and the first
        // ScratchDefaults is built before this run has written any plist of its
        // own — so the sweep can only ever see PREVIOUS runs' leftovers.
        _ = Self.sweepStalePlists
        // A UUID suite name is always a valid domain. A nil here would mean the
        // store silently became the real one, which must never happen.
        store = UserDefaults(suiteName: suiteName)!
    }

    /// A second handle on the same domain — how a persistence test shows a
    /// value survived the instance that wrote it instead of living in memory.
    func reopened() -> UserDefaults {
        UserDefaults(suiteName: suiteName)!
    }

    /// A `ClockModel` over this scratch suite — the one way the render and menu
    /// tests get a model without writing to the developer's real preferences.
    @MainActor func makeClock() -> ClockModel {
        ClockModel(defaults: store)
    }

    deinit {
        store.removePersistentDomain(forName: suiteName)
        // Emptying the domain leaves an empty plist behind, and one per test
        // adds up fast — delete the file too. Flush first: with writes still
        // pending, cfprefsd recreates the file moments after the delete.
        CFPreferencesAppSynchronize(suiteName as CFString)
        if let url = Self.preferencesDirectory?.appending(path: "\(suiteName).plist") {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static var preferencesDirectory: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?.appending(path: "Preferences")
    }

    /// Deletes the empty plists earlier runs left behind (see the type's note),
    /// bounding the leak at one run's worth instead of letting it accumulate.
    private static let sweepStalePlists: Void = {
        guard let directory = preferencesDirectory,
              let contents = try? FileManager.default.contentsOfDirectory(
                  at: directory, includingPropertiesForKeys: nil
              )
        else { return }
        for url in contents
        where url.pathExtension == "plist" && url.lastPathComponent.hasPrefix(suiteNamePrefix) {
            try? FileManager.default.removeItem(at: url)
        }
    }()
}

/// The byte-level pixel snapshot every render test compares. One helper so the
/// `ImageRenderer` → `nsImage` → `tiffRepresentation` chain — and its two
/// failure points — is expressed once, with `#require` rather than a bare `!`.
/// `scale` matches `ImageRenderer`'s own default of 1 unless a caller needs a
/// denser render.
@MainActor func pixelData(of view: some View, scale: CGFloat = 1) throws -> Data {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    return try pixelData(of: renderer.nsImage)
}

/// The same snapshot for a view already rasterized through a production path
/// (`StatusItemRaster.rasterize`), which hands back an `NSImage?` directly.
@MainActor func pixelData(of image: NSImage?) throws -> Data {
    let image = try #require(image)
    return try #require(image.tiffRepresentation)
}

/// Rasterizes a view once and answers "is this pixel dense ink?" for the
/// pixel-scanning tests. The ink threshold is DERIVED from DesignTokens —
/// midway between the brightest chip-fill alpha and the dimmest ink alpha
/// (secondary label / dim ring mark) — so re-tuned opacities can't silently
/// blind the scans.
@MainActor struct RasterScan {
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
