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
///   && cp "$DIR/menubar.png" docs/
struct GlyphExport {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["GLYPH_EXPORT_DIR"] != nil))
    @MainActor func exportMenubarGlyph() throws {
        let directory = try #require(ProcessInfo.processInfo.environment["GLYPH_EXPORT_DIR"])

        // The app's default pair at a DST-stable instant: 2026-04-20 12:34 UTC
        // puts JST at 21 and PDT at 05:34. The 16-hour offset is whole-hour, so
        // the sub-hour ring intentionally draws nothing here.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let reference = calendar.date(
            from: DateComponents(year: 2026, month: 4, day: 20, hour: 12, minute: 34)
        )!
        let glyph = TimeGlyph(
            secondaryLabel: "JST", secondaryTimezone: TimeZone(identifier: "Asia/Tokyo")!,
            primaryLabel: "PDT", primaryTimezone: TimeZone(identifier: "America/Los_Angeles")!,
            now: reference, variant: .arc
        )

        let card = glyph.statusItemStrip()
            .padding(EdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12))
            .background(.black)
        // 6 px/pt: the README displays the image at 3× point size, so 2×
        // (retina) readers get exact pixels and 1× readers a clean downsample.
        let renderer = ImageRenderer(content: card)
        renderer.scale = 6
        let image = try #require(renderer.cgImage)
        let png = try #require(
            NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        )
        try png.write(to: URL(filePath: directory).appending(path: "menubar.png"))
    }
}
