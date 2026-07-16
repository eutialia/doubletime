//
//  GlyphMetrics.swift
//  doubletime
//

import SwiftUI

/// Scaled glyph geometry/typography. The glyph components read these instead of
/// DesignTokens directly so showcase surfaces (OptionCard examples, the About
/// chip) can render the glyph LARGER as crisp vector text rather than
/// raster-upscaling it with `.scaleEffect`. Base numbers stay in DesignTokens —
/// this struct only multiplies them. Colors/alphas are unscaled and remain on
/// DesignTokens.
struct GlyphMetrics {
    var scale: CGFloat = 1

    // MARK: Geometry

    var cellSize: CGSize {
        CGSize(width: DesignTokens.cellSize.width * scale,
               height: DesignTokens.cellSize.height * scale)
    }
    var cellCornerRadius: CGFloat { DesignTokens.cellCornerRadius * scale }
    var glyphSpacing: CGFloat { DesignTokens.glyphSpacing * scale }
    var labelCellGap: CGFloat { DesignTokens.labelCellGap * scale }
    var labelLeadingInset: CGFloat { DesignTokens.labelLeadingInset * scale }
    var glyphHorizontalPadding: CGFloat { DesignTokens.glyphHorizontalPadding * scale }
    var trailingMinuteLeadingOffset: CGFloat { DesignTokens.trailingMinuteLeadingOffset * scale }
    /// Stroke width scales too — the web reference scales stroke via transform.
    var arcLineWidth: CGFloat { DesignTokens.arcLineWidth * scale }
    var indicatorExtraInset: CGFloat { DesignTokens.indicatorExtraInset * scale }
    /// The indicator path's inset from the cell bounds: half the stroke (a
    /// stroke is centered on its path) plus the extra label-clearance inset, so
    /// the OUTER stroke edge sits indicatorExtraInset inside the cell.
    var indicatorInset: CGFloat { arcLineWidth / 2 + indicatorExtraInset }
    /// Corner radius keeping the inset ring concentric with the cell's corners.
    var indicatorCornerRadius: CGFloat { max(cellCornerRadius - indicatorInset, 0) }
    var segmentGap: CGFloat { DesignTokens.segmentGap * scale }
    var labelHeight: CGFloat { DesignTokens.labelHeight * scale }

    // MARK: Typography

    var timeFont: Font {
        Font.system(size: DesignTokens.timeFontSize * scale, weight: .medium).monospacedDigit()
    }
    var timeTracking: CGFloat { DesignTokens.timeTracking * scale }
    var labelFont: Font {
        Font.system(size: DesignTokens.labelFontSize * scale, weight: .bold, design: .monospaced)
    }
    var labelTracking: CGFloat { DesignTokens.labelTracking * scale }
}

private struct GlyphMetricsKey: EnvironmentKey {
    static let defaultValue = GlyphMetrics()
}

extension EnvironmentValues {
    var glyphMetrics: GlyphMetrics {
        get { self[GlyphMetricsKey.self] }
        set { self[GlyphMetricsKey.self] = newValue }
    }
}
