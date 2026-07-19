//
//  GlyphExport.swift
//  doubletimeTests
//

import AppKit
import SwiftUI
import Testing
@testable import doubletime

/// Writes the README hero image: the canonical status strip (the exact
/// composition the menu bar shows, via View.statusItemStrip) composited on
/// black. Lives in the test target to reuse its headless rendering setup, but
/// it is an asset generator, not a behavior test — gated behind
/// GLYPH_EXPORT_DIR so ordinary test runs skip it. The sandboxed host app can
/// only write inside its own container, so export there and copy out:
///
///   DIR="$HOME/Library/Containers/com.lhdev.doubletime/Data/tmp"
///   TEST_RUNNER_GLYPH_EXPORT_DIR="$DIR" xcodebuild test \
///     -project doubletime.xcodeproj -scheme doubletime \
///     -destination 'platform=macOS,arch=arm64' \
///     -only-testing:doubletimeTests/GlyphExport \
///   && cp "$DIR/menubar.png" "$DIR/menubar-hover.png" docs/
struct GlyphExport {
    private static let exportDirectory = ProcessInfo.processInfo.environment["GLYPH_EXPORT_DIR"]

    /// The app's default pair at a DST-stable instant: 2026-04-20 12:34 UTC
    /// puts JST at 21 and PDT at 05:34.
    private static let reference: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(
            from: DateComponents(year: 2026, month: 4, day: 20, hour: 12, minute: 34)
        )!
    }()

    /// Composites the canonical strip on black and writes a 6 px/pt PNG (the
    /// README displays at 3× point size: exact pixels for 2× readers, a clean
    /// downsample for 1×).
    @MainActor private func export(_ glyph: some View, as filename: String, to directory: String) throws {
        let card = glyph.statusItemStrip()
            .padding(EdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12))
            .background(.black)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 6
        let image = try #require(renderer.cgImage)
        let png = try #require(
            NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        )
        try png.write(to: URL(filePath: directory).appending(path: filename))
    }

    @Test(.enabled(if: GlyphExport.exportDirectory != nil))
    @MainActor func exportMenubarGlyph() throws {
        let directory = try #require(Self.exportDirectory)
        // The 16-hour JST/PDT offset is whole-hour, so the sub-hour ring
        // intentionally draws nothing here.
        let glyph = TimeGlyph(
            secondaryLabel: "JST", secondaryTimezone: TimeZone(identifier: "Asia/Tokyo")!,
            primaryLabel: "PDT", primaryTimezone: TimeZone(identifier: "America/Los_Angeles")!,
            now: Self.reference, variant: .arc
        )
        try export(glyph, as: "menubar.png", to: directory)
    }

    @Test(.enabled(if: GlyphExport.exportDirectory != nil))
    @MainActor func exportHoveredMenubarGlyph() throws {
        let directory = try #require(Self.exportDirectory)
        // Kathmandu (+5:45) over PDT: a quarter-hour pair, so hover rolls
        // :34 → :19 — both digits change, and the card rides under them.
        let glyph = TimeGlyph(
            secondaryLabel: "KAT", secondaryTimezone: TimeZone(identifier: "Asia/Kathmandu")!,
            primaryLabel: "PDT", primaryTimezone: TimeZone(identifier: "America/Los_Angeles")!,
            now: Self.reference, variant: .arc, hovered: true
        )
        try export(glyph, as: "menubar-hover.png", to: directory)
    }
}
