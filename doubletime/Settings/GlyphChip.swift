//
//  GlyphChip.swift
//  doubletime
//

import SwiftUI

/// A glyph shown on a dark mini menu bar — the "chip" used by the glyph examples
/// inside OptionCards. Renders its content in the dark colorScheme so `.primary`
/// resolves white regardless of the app's (light-scoped) settings appearance.
///
/// The glyph is enlarged by scaling its GEOMETRY (via `\.glyphMetrics`), never
/// by `.scaleEffect` — digits and labels stay crisp vector text at any scale.
struct GlyphChip<Content: View>: View {
    var cornerRadius: CGFloat = 6
    var scale: CGFloat = 1.6
    /// The chip is exactly this tall and fills its width.
    let fixedHeight: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        let metrics = GlyphMetrics(scale: scale)
        content()
            .environment(\.glyphMetrics, metrics)
            // The label overlays ABOVE the glyph's layout box; bias the centered
            // content down by half that extent so the ensemble visually centers
            // and the label never clips the chip top.
            .offset(y: (metrics.labelHeight + metrics.labelCellGap) / 2)
            .frame(maxWidth: .infinity)
            .frame(height: fixedHeight)
            .background(DesignTokens.chipGradient)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .inset(by: 0.5)
                    .stroke(Color.black.opacity(0.40), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .environment(\.colorScheme, .dark)
    }
}
