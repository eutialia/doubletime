//
//  StatusItemRaster.swift
//  doubletime
//

import SwiftUI

/// The status item composition (see View.statusItemStrip), photographed and
/// blown up ×scale: the glyph nudged into the fixed 22pt status strip with
/// `.primary` resolved against a dark bar, rasterized and magnified. Parity
/// with the menu bar is by construction — vector-scaling the geometry instead
/// is NOT equivalent (text line boxes don't scale linearly, so a scaled zone
/// label drifts down into the indicator ring).
struct StatusItemRaster<Content: View>: View {
    /// Magnification applied to the rendered strip.
    let scale: CGFloat
    @ViewBuilder let content: Content

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        // Re-rendering per body evaluation is fine: the strip is ~65×22pt and
        // exemplar content is static, so evaluations are rare and cheap.
        if let image = rasterize(pixelScale: displayScale * scale) {
            Image(nsImage: image)
                .resizable()
                .frame(width: image.size.width * scale,
                       height: image.size.height * scale)
        }
    }

    /// Rasterizes the strip at `pixelScale` pixels per point. The body passes
    /// displayScale × scale so one bitmap pixel maps to one device pixel and
    /// the magnified image stays crisp. Internal (not private) so the pixel
    /// tests can exercise this exact production path.
    func rasterize(pixelScale: CGFloat) -> NSImage? {
        let renderer = ImageRenderer(content: content.statusItemStrip())
        renderer.scale = pixelScale
        return renderer.nsImage
    }
}
