//
//  GlyphChip.swift
//  doubletime
//

import SwiftUI

/// A glyph shown on a dark mini menu bar — the "chip" used by the glyph examples
/// inside OptionCards. It shows EXACTLY what the status item renders, magnified:
/// the content is rasterized through StatusItemRaster, never re-laid-out at a
/// larger geometry, so settings exemplars are pixel-true to the menu bar.
struct GlyphChip<Content: View>: View {
    private static var cornerRadius: CGFloat { 6 }
    /// Magnification of the menu bar raster inside the chip.
    private static var scale: CGFloat { 1.6 }

    /// The chip is exactly this tall and fills its width.
    let fixedHeight: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        StatusItemRaster(scale: Self.scale) { content }
            .frame(maxWidth: .infinity)
            .frame(height: fixedHeight)
            .background(DesignTokens.chipGradient)
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .inset(by: 0.5)
                    .stroke(Color.black.opacity(0.40), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
    }
}
