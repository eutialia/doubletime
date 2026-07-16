//
//  HourCell.swift
//  doubletime
//

import SwiftUI

/// A fixed-footprint chip showing a two-digit hour, with a zone label riding
/// above as an overlay and an optional clock-face indicator drawn on top.
///
/// THE CORE INVARIANT: the chip's layout size is exactly 17×15 (× the metrics
/// scale). The label overlay does not add to the flow height (the chip centers
/// with neighbouring menu bar items; the label rides up toward the bar's top).
/// The indicator stroke may overflow the box by half its line width —
/// intentional, not clipped.
struct HourCell: View {
    enum Tone {
        case primary
        case secondary

        var isDim: Bool { self == .secondary }
    }

    let label: String
    let hour: String
    /// Fraction of the perimeter to sweep (0 draws no indicator).
    let fraction: Double
    /// Sweep direction; counterclockwise mirrors the clockwise-from-12 path.
    var clockwise: Bool = true
    var variant: GlyphVariant = .arc
    let tone: Tone
    /// AM/PM period in 12-hour mode; nil in 24-hour mode (neutral chip fill).
    var period: ClockModel.Period? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.glyphMetrics) private var metrics

    private var cellRect: CGRect { CGRect(origin: .zero, size: metrics.cellSize) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: metrics.cellCornerRadius)
                .fill(DesignTokens.chipFill(isPrimary: tone == .primary, period: period, colorScheme: colorScheme))

            Text(hour)
                .font(metrics.timeFont)
                .trackedCentered(metrics.timeTracking)
                .foregroundStyle(.primary.opacity(DesignTokens.inkOpacity))
                .fixedSize()
        }
        .frame(width: metrics.cellSize.width, height: metrics.cellSize.height)
        .overlay { indicator }
        .overlay(alignment: .top) {
            // Captured outside the alignment closure (it is Sendable and must
            // not touch the MainActor-isolated environment).
            let gap = metrics.labelCellGap
            ZoneLabel(text: label, dim: tone.isDim)
                // The label's bottom sits labelCellGap above the chip's top.
                .alignmentGuide(.top) { $0[.bottom] + gap }
        }
    }

    @ViewBuilder private var indicator: some View {
        if fraction > 0 {
            let mark = Color.primary.opacity(DesignTokens.markOpacity(isDim: tone.isDim, colorScheme: colorScheme))
            Group {
                switch variant {
                case .arc:
                    CellPerimeter(cornerRadius: metrics.cellCornerRadius)
                        .trim(from: 0, to: fraction)
                        .stroke(mark, style: StrokeStyle(lineWidth: metrics.arcLineWidth, lineCap: .round))
                case .segmented:
                    let quarters = ClockModel.segmentQuarters(fraction: fraction)
                    if quarters > 0 {
                        let quarterLength = CellPerimeter.perimeterLength(in: cellRect,
                                                                          cornerRadius: metrics.cellCornerRadius) / 4
                        CellPerimeter(cornerRadius: metrics.cellCornerRadius)
                            .trim(from: 0, to: Double(quarters) / 4)
                            .stroke(mark, style: StrokeStyle(
                                lineWidth: metrics.arcLineWidth,
                                lineCap: .butt,
                                dash: [quarterLength - metrics.segmentGap, metrics.segmentGap]
                            ))
                    }
                }
            }
            // Counterclockwise = mirror the clockwise-from-12 path about vertical.
            .scaleEffect(x: clockwise ? 1 : -1, y: 1)
        }
    }
}
