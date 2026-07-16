//
//  CellPerimeter.swift
//  doubletime
//

import SwiftUI

/// The full rounded-rect perimeter of an hour cell, treated as a tiny analog
/// clock face: the path starts at top-center (12 o'clock) and proceeds
/// clockwise around the perimeter. Consumers draw partial arcs via
/// `.trim(from: 0, to: fraction)` — SwiftUI trim is proportional to path
/// length, which exactly matches the design's arc-length parameterization
/// (:15 → right edge, :30 → bottom-center, :45 → left edge).
struct CellPerimeter: Shape {
    /// Corner radius of the traced cell — pass the (possibly scaled) metrics
    /// radius so the arc hugs a scaled chip's corners exactly.
    var cornerRadius: CGFloat = DesignTokens.cellCornerRadius

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var path = Path()

        // Tangent-based corner arcs keep the traversal unambiguously clockwise
        // in SwiftUI's y-down space and avoid start/end angle confusion.
        path.move(to: CGPoint(x: rect.midX, y: rect.minY)) // 12 o'clock
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: r) // top-right
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: r) // bottom-right
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: r) // bottom-left
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.midX, y: rect.minY), radius: r) // top-left
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY)) // back to 12 o'clock (no closeSubpath)

        return path
    }

    /// Total path length of the perimeter for a given cell rect:
    /// `2(w + h) − 8r + 2πr` (four straight runs minus the corners the arcs
    /// replace, plus the four quarter-circle arcs). Used to size segmented-tick
    /// dash patterns so each quarter-hour segment lands on an exact quarter.
    static func perimeterLength(in rect: CGRect,
                                cornerRadius: CGFloat = DesignTokens.cellCornerRadius) -> CGFloat {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        return 2 * (rect.width + rect.height) - 8 * r + 2 * .pi * r
    }
}
