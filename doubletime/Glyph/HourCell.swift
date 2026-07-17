//
//  HourCell.swift
//  doubletime
//

import SwiftUI

/// A fixed-footprint chip showing a two-digit hour, with a zone label riding
/// above as an overlay and an optional clock-face indicator drawn on top.
///
/// THE CORE INVARIANT: the chip's layout size is exactly 19×16. The label
/// overlay does not add to the flow height (the chip centers
/// with neighbouring menu bar items; the label rides up toward the bar's top,
/// floated labelCellGap clear of the cell so it reads as detached). The
/// indicator stroke draws fully INSIDE the cell bounds (outer stroke edge
/// indicatorExtraInset inside the cell edge), concentric with its corners.
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

    private var cellRect: CGRect { CGRect(origin: .zero, size: DesignTokens.cellSize) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.cellCornerRadius)
                .fill(DesignTokens.chipFill(isPrimary: tone == .primary, period: period, colorScheme: colorScheme))

            Text(hour)
                .font(DesignTokens.timeFont)
                .trackedCentered(DesignTokens.timeTracking)
                .foregroundStyle(.primary.opacity(DesignTokens.inkOpacity))
                .fixedSize()
        }
        .frame(width: DesignTokens.cellSize.width, height: DesignTokens.cellSize.height)
        .overlay { indicator }
        .overlay(alignment: .topLeading) {
            ZoneLabel(text: label, dim: tone.isDim)
                // The label's bottom sits labelCellGap above the chip's top.
                .alignmentGuide(.top) { $0[.bottom] + DesignTokens.labelCellGap }
                // Left-aligned: the label's leading sits labelLeadingInset
                // inside the chip's left edge (past the corner-radius falloff).
                .alignmentGuide(.leading) { $0[.leading] - DesignTokens.labelLeadingInset }
        }
    }

    @ViewBuilder private var indicator: some View {
        if fraction > 0 {
            let mark = Color.primary.opacity(DesignTokens.markOpacity(isDim: tone.isDim, colorScheme: colorScheme))
            // Trace an inset path (see DesignTokens.indicatorInset): the ring
            // draws fully INSIDE the cell, concentric with its corners.
            let strokeInset = DesignTokens.indicatorInset
            let strokeRadius = DesignTokens.indicatorCornerRadius
            Group {
                switch variant {
                case .arc:
                    CellPerimeter(cornerRadius: strokeRadius)
                        .trim(from: 0, to: fraction)
                        .stroke(mark, style: StrokeStyle(lineWidth: DesignTokens.arcLineWidth, lineCap: .round))
                case .segmented:
                    let quarters = ClockModel.segmentQuarters(fraction: fraction)
                    if quarters > 0 {
                        let strokeRect = cellRect.insetBy(dx: strokeInset, dy: strokeInset)
                        let quarterLength = CellPerimeter.perimeterLength(in: strokeRect,
                                                                          cornerRadius: strokeRadius) / 4
                        CellPerimeter(cornerRadius: strokeRadius)
                            .trim(from: 0, to: Double(quarters) / 4)
                            .stroke(mark, style: StrokeStyle(
                                lineWidth: DesignTokens.arcLineWidth,
                                lineCap: .butt,
                                dash: [quarterLength - DesignTokens.segmentGap, DesignTokens.segmentGap]
                            ))
                    }
                }
            }
            .padding(strokeInset)
            // Counterclockwise = mirror the clockwise-from-12 path about vertical.
            // (The inset is symmetric, so the mirror is unaffected.)
            .scaleEffect(x: clockwise ? 1 : -1, y: 1)
        }
    }
}
