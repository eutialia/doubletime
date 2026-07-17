//
//  TrailingMinute.swift
//  doubletime
//

import SwiftUI

/// The trailing `:mm`, always the PRIMARY minute. The colon can hide every other
/// second (opt-in blink) at opacity 0 so the glyph width never changes.
struct TrailingMinute: View {
    let minute: String
    var blink: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            colon
            Text(minute)
        }
        .font(DesignTokens.timeFont)
        .tracking(DesignTokens.timeTracking)
        .foregroundStyle(.primary.opacity(DesignTokens.inkOpacity))
    }

    /// When blinking, ONLY the colon runs a per-second timeline (the rest of the
    /// glyph stays on the per-minute tick). It stays laid out at opacity 0 rather
    /// than being removed, so the glyph width never changes.
    @ViewBuilder private var colon: some View {
        if blink {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(":").opacity(ClockModel.colonVisible(at: context.date) ? 1 : 0)
            }
        } else {
            Text(":")
        }
    }
}
