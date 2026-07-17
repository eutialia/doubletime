//
//  View+StatusItemStrip.swift
//  doubletime
//

import SwiftUI

extension View {
    /// The canonical status-item composition: the glyph nudged down inside the
    /// fixed 22pt status strip, with `.primary` resolved against a dark bar.
    /// StatusItemRaster and the pixel tests all build the strip through this
    /// one helper so they can never drift apart. StatusBarView is the one
    /// intentional exception: the real menu bar supplies the button height and
    /// its own appearance, so it applies only the nudge (see StatusBarView).
    func statusItemStrip() -> some View {
        offset(y: DesignTokens.statusItemGlyphNudge)
            .frame(height: DesignTokens.statusItemHeight)
            .fixedSize()
            .environment(\.colorScheme, .dark)
    }
}
