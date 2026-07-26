//
//  StatusItemRasterTests.swift
//  doubletimeTests
//

import AppKit
import SwiftUI
import Testing
@testable import doubletime

struct StatusItemRasterTests {
    // MARK: StatusItemRaster's own body (lines 21–30)

    /// Every other test in the suite exercises `rasterize(pixelScale:)`
    /// directly; this instead renders the `StatusItemRaster` VIEW so its
    /// `body` (the `Image(nsImage:).resizable().frame(...)` wrapper) actually
    /// executes.
    @Test @MainActor func bodyRendersNonVacuousInk() throws {
        let scan = try RasterScan(
            of: StatusItemRaster(scale: 1) { exemplarGlyph }.environment(\.colorScheme, .dark),
            compositedOn: 0x2D
        )
        let hasInk = (0..<scan.height).contains { y in (0..<scan.width).contains { x in scan.isInk(x, y) } }
        #expect(hasInk)
    }

    /// `body` computes `image.size * scale` where `image` comes from
    /// `rasterize(pixelScale: displayScale * scale)` — NOT a fixed pixelScale
    /// — so the correct baseline to compare against is `rasterize`'s own
    /// output at that SAME effective pixelScale, not a value pinned at
    /// pixelScale 1. (Confirmed empirically: `rasterize`'s point-size width
    /// isn't perfectly scale-invariant — it drifts by up to ~1pt as
    /// pixelScale changes, matching StatusItemRaster's own doc comment that
    /// "text line boxes don't scale linearly" — so comparing against a
    /// pixelScale-1 baseline multiplied by `scale` is the wrong invariant and
    /// was previously found to fail by exactly that drift.) `displayScale` is
    /// PINNED to 1 on the rendered view rather than assumed, so the effective
    /// pixelScale `body` computes is exactly `scale` and the same-pixelScale
    /// baseline is `rasterize(pixelScale: scale)`.
    @Test(arguments: [1.0, 1.6, 2.0] as [CGFloat])
    @MainActor func scaleParameterScalesRenderedPointSizeProportionally(scale: CGFloat) throws {
        let naturalSizeAtThisPixelScale = try #require(
            StatusItemRaster(scale: 1) { exemplarGlyph }.rasterize(pixelScale: scale)
        ).size

        let renderer = ImageRenderer(
            content: StatusItemRaster(scale: scale) { exemplarGlyph }
                .environment(\.displayScale, 1)
        )
        let image = try #require(renderer.nsImage)

        #expect(abs(image.size.width - naturalSizeAtThisPixelScale.width * scale) < 0.01)
        #expect(abs(image.size.height - naturalSizeAtThisPixelScale.height * scale) < 0.01)
    }
}

struct StatusBarViewTests {
    private let scratch = ScratchDefaults()

    /// StatusBarView reports its ideal glyph width via `onWidthChange` from
    /// an `onGeometryChange` modifier, which only fires once AppKit actually
    /// lays the hosting view out. `@Environment(\.openSettings)` resolves to
    /// SwiftUI's benign default action when hosted outside of any Scene (it
    /// is never invoked in this test), so no Settings scene is needed to host
    /// the view headlessly.
    @Test @MainActor func onWidthChangeFiresWithANonzeroWidthAfterLayout() throws {
        let clock = scratch.makeClock()

        final class WidthBox {
            var width: CGFloat = 0
        }
        let box = WidthBox()

        let hostingView = NSHostingView(rootView: StatusBarView(clock: clock) { width in
            box.width = width
        })
        hostingView.frame = NSRect(x: 0, y: 0, width: 200, height: DesignTokens.statusItemHeight)
        hostingView.layoutSubtreeIfNeeded()

        #expect(box.width > 0)
    }
}
