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

    var body: some View {
        Text(text)
            .font(DesignTokens.labelFont)
            .textCase(.uppercase)
            // Left-anchored: no leading-pad compensation (that exists only to
            // optically center); the trailing tracking unit hangs invisibly off
            // the right end.
            .tracking(DesignTokens.labelTracking)
            // Pin the line box tight so the 5.5pt line box does not balloon the
            // overlay and float or clip the text on short bars.
            .frame(height: DesignTokens.labelHeight)
            .foregroundStyle(.primary.opacity(dim ? DesignTokens.secondaryLabelOpacity
                                                   : DesignTokens.primaryLabelOpacity))
            .fixedSize()
    }
}
