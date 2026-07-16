//
//  ZoneLabel.swift
//  doubletime
//

import SwiftUI

/// Micro uppercase zone label riding above an hour cell (attached as an overlay,
/// so it does not add to the cell's flow height).
struct ZoneLabel: View {
    let text: String
    let dim: Bool

    @Environment(\.glyphMetrics) private var metrics

    var body: some View {
        Text(text)
            .font(metrics.labelFont)
            .textCase(.uppercase)
            .trackedCentered(metrics.labelTracking)
            // Pin the line box tight so the 5pt line box does not balloon the
            // overlay and float or clip the text on short bars.
            .frame(height: metrics.labelHeight)
            .foregroundStyle(.primary.opacity(dim ? DesignTokens.secondaryLabelOpacity
                                                   : DesignTokens.primaryLabelOpacity))
            .fixedSize()
    }
}
