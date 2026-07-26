//
//  SettingsRenderTests.swift
//  doubletimeTests
//

import AppKit
import SwiftUI
import Testing
@testable import doubletime

struct SettingsRenderTests {
    private let scratch = ScratchDefaults()

    /// A `LoginItemModel` over a stubbed service: the real one reads
    /// `SMAppService.mainApp`, whose status on the developer's machine decides
    /// whether the pane grows an extra `.requiresApproval` row — which would
    /// make these geometry and pixel comparisons depend on the host.
    @MainActor private func stubbedLoginItem() -> LoginItemModel {
        LoginItemModel(service: MockLoginItemService())
    }

    // MARK: SettingsPane

    /// Pins the surface's documented fixed width to the token that governs
    /// it, rather than a copied literal — a regression that decouples the
    /// `.frame(width:)` modifier from `DesignTokens.settingsWidth` fails this.
    @Test @MainActor func settingsPaneRendersAtTheDocumentedWidth() throws {
        let clock = scratch.makeClock()
        let renderer = ImageRenderer(content: SettingsPane(clock: clock, loginItem: stubbedLoginItem()))
        let image = try #require(renderer.nsImage)
        #expect(image.size.width == DesignTokens.settingsWidth)
        #expect(image.size.height > 0)
    }

    /// SettingsPane embeds two LIVE TimeGlyph exemplars inside its OptionCard
    /// rows, tied to `clock.hour12` — toggling it must change what's actually
    /// on screen, not just an internal flag.
    @Test @MainActor func settingsPaneExemplarChipsChangePixelsWithHour12() throws {
        let clock = scratch.makeClock()
        let loginItem = stubbedLoginItem()
        func render() throws -> Data {
            try pixelData(of: SettingsPane(clock: clock, loginItem: loginItem), scale: 2)
        }
        clock.hour12 = false
        let before = try render()
        clock.hour12 = true
        let after = try render()
        #expect(before != after)
    }

    /// Toggling the glyph-style variant changes which OptionCard is
    /// `selected` (radio dot fill + border width/opacity) even though each
    /// row's own exemplar variant is fixed — a real, visible pixel change.
    @Test @MainActor func settingsPaneSelectionChangesPixelsWithVariant() throws {
        let clock = scratch.makeClock()
        let loginItem = stubbedLoginItem()
        func render() throws -> Data {
            try pixelData(of: SettingsPane(clock: clock, loginItem: loginItem), scale: 2)
        }
        clock.variant = .arc
        let before = try render()
        clock.variant = .segmented
        let after = try render()
        #expect(before != after)
    }

    // MARK: SettingsView

    /// SettingsView wraps SettingsPane in a TabView — this confirms the
    /// TabView chrome itself still renders headlessly (no window/scene) at
    /// the documented width, exercising SettingsView's otherwise-uncovered
    /// body.
    @Test @MainActor func settingsViewRendersAtTheDocumentedWidth() throws {
        let clock = scratch.makeClock()
        let renderer = ImageRenderer(content: SettingsView(clock: clock, loginItem: stubbedLoginItem()))
        let image = try #require(renderer.nsImage)
        #expect(image.size.width == DesignTokens.settingsWidth)
        #expect(image.size.height > 0)
    }

    // MARK: AboutPane

    /// In the test bundle `Bundle.main` carries no CFBundleShortVersionString
    /// / CFBundleVersion, so `versionString` takes its "1.0"/"1" fallback.
    /// ImageRenderer exposes no text tree to assert the literal string
    /// against, so what's honestly assertable here is: the render is
    /// non-vacuous (real ink), and deterministic (no hidden dependency on
    /// wall-clock time or view identity) across repeated renders.
    @Test @MainActor func aboutPaneRendersDeterministicNonVacuousInk() throws {
        func render() throws -> Data {
            try pixelData(of: AboutPane())
        }
        #expect(try render() == render())

        let scan = try RasterScan(of: AboutPane())
        let hasInk = (0..<scan.height).contains { y in (0..<scan.width).contains { x in scan.isInk(x, y) } }
        #expect(hasInk)
    }

    // MARK: GlyphChip (fixedHeight)

    /// GlyphChip's one non-trivial parameter is `fixedHeight` — this pins
    /// that it actually controls the rendered output height in points
    /// (SettingsRow and SettingsDivider are exercised for free above, inside
    /// SettingsPane, and carry no parameter worth a direct test).
    @Test(arguments: [40.0, 52.0, 80.0] as [CGFloat])
    @MainActor func glyphChipFixedHeightControlsRenderedHeight(height: CGFloat) throws {
        let chip = GlyphChip(fixedHeight: height) {
            TimeGlyph(
                secondaryLabel: "IST", secondaryTimezone: timezone("Asia/Kolkata"),
                primaryLabel: "PDT", primaryTimezone: timezone("America/Los_Angeles"),
                now: reference, variant: .arc
            )
        }
        let renderer = ImageRenderer(content: chip.frame(width: 200))
        let image = try #require(renderer.nsImage)
        #expect(abs(image.size.height - height) < 0.5)
    }
}
