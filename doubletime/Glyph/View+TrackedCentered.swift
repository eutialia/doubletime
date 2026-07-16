//
//  View+TrackedCentered.swift
//  doubletime
//

import SwiftUI

extension View {
    /// Optically centers trailing-tracked text over a fixed box. `.tracking` also
    /// trails the last glyph, widening the frame to the RIGHT of the ink and
    /// pushing it left of center; re-pad the LEADING edge by the same amount so
    /// the text truly centers. Used by the hour digits (HourCell) and the zone
    /// label (ZoneLabel), both centered over the 17×15 cell — NOT the trailing
    /// `:mm`, which is left-anchored by design and deliberately has no leading pad.
    func trackedCentered(_ amount: CGFloat) -> some View {
        tracking(amount).padding(.leading, amount)
    }
}
