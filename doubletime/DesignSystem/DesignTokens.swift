//
//  DesignTokens.swift
//  doubletime
//

import AppKit
import SwiftUI

/// The full token vocabulary for the menu bar TimeGlyph plus the
/// appearance-adaptive settings surface.
///
/// On-dark ink is expressed as `Color.primary` at specific alphas (never opaque
/// grays) so the glyph survives wallpaper-tinted menu bars and adapts to light
/// bars. v2 diverges the chip-fill / mark alphas by appearance, and adds real
/// accent hues for 12-hour mode (the only sanctioned hue exception).
enum DesignTokens {
    // MARK: Geometry (points)

    /// Fixed hour-cell footprint. THE CORE INVARIANT: indicators draw
    /// absolutely on top of the cell and never change its outer size.
    static let cellSize = CGSize(width: 19, height: 16)
    static let cellCornerRadius: CGFloat = 3.5

    /// Gap between cells and between the primary cell and the trailing minute.
    static let glyphSpacing: CGFloat = 3.5
    /// Leading inset of the (left-aligned) zone label's box relative to its
    /// cell's left edge. 1pt tucks the label ink past the corner-radius falloff
    /// so it aligns with the cell's visual left mass rather than the bounding box.
    static let labelLeadingInset: CGFloat = 1
    /// Gap between a zone label's bottom and its cell's top (label is an overlay).
    /// Mirrors the canon token `--dt-label-gap`. At 0 the label's baseline ink
    /// dipped ~0.25pt INTO the cell, reading as attached to the block; 0.75
    /// floats the ink a visible ~0.5pt clear of the cell top (1 device px on
    /// retina) so the label reads as detached. Every added point here costs one
    /// point of statusItemGlyphNudge — the two are re-measured together.
    static let labelCellGap: CGFloat = 0.75

    /// Fixed height of a macOS status bar button. The glyph ensemble must fit
    /// inside it with zero overflow (see statusItemGlyphNudge); GlyphChip
    /// reproduces this exact strip so settings exemplars match the menu bar.
    static let statusItemHeight: CGFloat = 22

    /// Menu-bar vertical nudge for the whole glyph ensemble. A status item is
    /// mirrored to every display and macOS clips anything that overflows the fixed
    /// 22pt status button, so the ensemble (label 2.5 + gap 0.75 + cell 16 = 19.25)
    /// must fit inside 22 with zero overflow. Shifting down 1.75 lands the 5.5pt
    /// label cap ink ≈0.25pt below the container top (no clip) with the cell's
    /// bottom edge still 1.25pt clear; the digits ride 1.75pt below the button center —
    /// the visual ink mass (label top → cell bottom) stays centered. (Pixel-
    /// verified at 16x; re-measure whenever labelCellGap moves — each point of
    /// gap costs a point of nudge.) GlyphChip applies the same nudge — it renders
    /// the status item composition verbatim.
    static let statusItemGlyphNudge: CGFloat = 1.75
    /// Outer horizontal padding around the whole glyph.
    static let glyphHorizontalPadding: CGFloat = 1
    /// Design: the trailing `:mm` carries an extra leading offset (marginLeft -1).
    static let trailingMinuteLeadingOffset: CGFloat = -1

    /// Clock-face arc / segment stroke.
    static let arcLineWidth: CGFloat = 1.2
    /// Extra concentric inset of the indicator ring beyond the flush
    /// half-stroke inset (which alone puts the outer stroke edge on the cell
    /// bounds). Zero = flush ring: the label floats clear of the cell
    /// (labelCellGap), so no label-clearance inset is needed, and flush buys
    /// the digits maximum interior clearance from the ring.
    static let indicatorExtraInset: CGFloat = 0
    /// The indicator path's inset from the cell bounds: half the stroke (a
    /// stroke is centered on its path) plus any extra inset, so the OUTER
    /// stroke edge sits exactly indicatorExtraInset inside the cell.
    static let indicatorInset: CGFloat = arcLineWidth / 2 + indicatorExtraInset
    /// Corner radius keeping the inset ring concentric with the cell's corners.
    static let indicatorCornerRadius: CGFloat = max(cellCornerRadius - indicatorInset, 0)
    /// Gap between segmented ticks (must stay legible at menu-bar scale).
    static let segmentGap: CGFloat = 3

    // MARK: Typography

    /// Time digits (HH and :mm), 10pt regular. monospacedDigit is mandatory so
    /// the glyph never jitters as digits change. 10pt (down from 11) keeps
    /// ~40% more side air inside the fixed 19×16 cell — the chip reads as a
    /// container with padding rather than a box hugging its ink.
    static let timeFont = Font.system(size: 10, weight: .regular).monospacedDigit()
    static let timeTracking: CGFloat = 0.2

    /// Zone label: 5.5pt bold monospaced — a deliberate menu-bar-only exception.
    static let labelFont = Font.system(size: 5.5, weight: .bold, design: .monospaced)
    static let labelTracking: CGFloat = 0.5
    /// Pinned line box for the label overlay — kept well tighter than the 5.5pt
    /// line box so the overlay does not balloon or float the text, and the
    /// ensemble fits the 22pt status button. The sub-cap-height box seats the cap
    /// ink low, minimizing the down-nudge needed to clear the container top —
    /// measured, not guessed (a taller box floats the cap up and forces a larger
    /// nudge → digits sink). The visible detachment from the cell comes from
    /// labelCellGap, not from this box.
    static let labelHeight: CGFloat = 2.5

    // MARK: Ink alphas (applied to Color.primary; identical across appearance)

    /// Text / digit ink — the SAME ink on both cells; hierarchy comes from
    /// chip fill + label dim, never from dimming the digits.
    static let inkOpacity: Double = 0.96

    static let primaryLabelOpacity: Double = 0.96
    static let secondaryLabelOpacity: Double = 0.55

    // MARK: Appearance-dependent glyph alphas / colors

    /// 24-hour chip fill alpha on `Color.primary`. The primary/secondary gap is
    /// deliberately wide (≈4.5×) — fill contrast is the ONLY hierarchy channel
    /// (digit ink is identical on both cells), so it must read at a glance.
    static func chipFillAlpha(isPrimary: Bool, colorScheme: ColorScheme) -> Double {
        switch (isPrimary, colorScheme == .light) {
        case (true, false): 0.32
        case (true, true): 0.22
        case (false, false): 0.07
        case (false, true): 0.05
        }
    }

    /// Arc / segment mark alpha on `Color.primary`. Bright on the primary tone,
    /// dim on the secondary tone.
    static func markOpacity(isDim: Bool, colorScheme: ColorScheme) -> Double {
        switch (isDim, colorScheme == .light) {
        case (false, false): 0.92
        case (false, true): 0.88
        case (true, false): 0.55
        case (true, true): 0.50
        }
    }

    /// The chip fill for a cell. In 24-hour mode (period nil) this is
    /// `Color.primary` at the appearance alpha; in 12-hour mode it is a real
    /// literal hue (warm amber = AM, cool indigo = PM) resolved by appearance.
    static func chipFill(isPrimary: Bool, period: ClockModel.Period?, colorScheme: ColorScheme) -> Color {
        guard let period else {
            return Color.primary.opacity(chipFillAlpha(isPrimary: isPrimary, colorScheme: colorScheme))
        }
        return hueChipFill(isPrimary: isPrimary, period: period, colorScheme: colorScheme)
    }

    private static func hueChipFill(isPrimary: Bool, period: ClockModel.Period, colorScheme: ColorScheme) -> Color {
        let light = colorScheme == .light
        let rgb: (Double, Double, Double)
        switch period {
        case .am: rgb = light ? (228, 148, 12) : (255, 209, 128)
        case .pm: rgb = light ? (72, 96, 224) : (138, 160, 255)
        }
        let alpha: Double
        switch (isPrimary, period, light) {
        case (true, .am, false): alpha = 0.40
        case (true, .am, true): alpha = 0.34
        case (true, .pm, false): alpha = 0.36
        case (true, .pm, true): alpha = 0.30
        case (false, .am, false): alpha = 0.16
        case (false, .am, true): alpha = 0.14
        case (false, .pm, false): alpha = 0.14
        case (false, .pm, true): alpha = 0.12
        }
        return Color(red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255, opacity: alpha)
    }

    // MARK: Settings layout

    /// The settings window / pane width, and the shared control-column width used
    /// by captions and the glyph-style cards.
    static let settingsWidth: CGFloat = 560
    static let settingsControlWidth: CGFloat = 330

    // MARK: Settings type ramp

    static let settingsTitle = Font.system(size: 21, weight: .semibold)
    static let settingsHeading = Font.system(size: 13, weight: .semibold)
    static let settingsLabel = Font.system(size: 13)
    static let settingsBody = Font.system(size: 12)
    static let settingsCaption = Font.system(size: 11)
    static let settingsFootnote = Font.system(size: 10)
    static let settingsMono = Font.system(size: 12, design: .monospaced)
    static let settingsMonoCaption = Font.system(size: 10, design: .monospaced)

    // MARK: Settings surface tokens (dynamic — follow the system appearance)

    static let canvas = dynamic(light: NSColor(hex: 0xF0EE_E9), dark: NSColor(hex: 0x2626_24))
    static let card = dynamic(light: NSColor(hex: 0xFFFF_FF), dark: NSColor(hex: 0x3030_2E))
    static let fieldBackground = dynamic(light: NSColor(hex: 0xFFFF_FF), dark: NSColor(hex: 0x3A3A_38))
    static let textStrong = dynamic(light: NSColor(hex: 0x1A1A_1A), dark: NSColor(white: 1, alpha: 0.96))
    static let textBody = dynamic(light: NSColor(hex: 0x4444_44), dark: NSColor(white: 1, alpha: 0.78))
    static let textMuted = dynamic(light: NSColor(hex: 0x7777_77), dark: NSColor(white: 1, alpha: 0.55))
    static let textFaint = dynamic(light: NSColor(hex: 0x8A8A_8A), dark: NSColor(white: 1, alpha: 0.40))
    static let hairline = dynamic(light: NSColor(white: 0, alpha: 0.08), dark: NSColor(white: 1, alpha: 0.10))
    static let cardBorder = dynamic(light: NSColor(white: 0, alpha: 0.12), dark: NSColor(white: 1, alpha: 0.16))
    static let fieldBorder = dynamic(light: NSColor(white: 0, alpha: 0.15), dark: NSColor(white: 1, alpha: 0.18))
    static let radioRing = dynamic(light: NSColor(white: 0, alpha: 0.30), dark: NSColor(white: 1, alpha: 0.35))
    static let searchFieldFill = dynamic(light: NSColor(white: 0, alpha: 0.05), dark: NSColor(white: 1, alpha: 0.08))
    /// Window-root control tint. Dark uses graphite (#98989d) — a near-white
    /// track would swallow the native Toggle's white knob.
    static let controlTint = dynamic(light: NSColor(hex: 0x1A1A_1A), dark: NSColor(hex: 0x9898_9D))

    /// A Color that resolves per-appearance via an NSColor dynamic provider.
    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }

    /// Dark mini-menu-bar chip gradient (#2d2d2d → #252525) used by GlyphChip.
    static let chipGradient = LinearGradient(
        colors: [Color(hex: 0x2D2D_2D), Color(hex: 0x2525_25)],
        startPoint: .top, endPoint: .bottom
    )
}

extension Color {
    /// Build an opaque color from a 24-bit `0xRRGGBB` literal.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension NSColor {
    /// Build an opaque sRGB color from a 24-bit `0xRRGGBB` literal.
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
