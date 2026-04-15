//
//  DesignTokens.swift
//  doubletime
//

import SwiftUI

enum DesignTokens {
    static let hourFont = Font.system(size: 11, weight: .medium, design: .rounded)
    static let labelFont = Font.system(size: 6, weight: .semibold)
    static let chipCornerRadius: CGFloat = 2.5
    static let digitAnimation = Animation.easeOut(duration: 0.2)
    static let secondaryHourOpacity: Double = 0.75
    static let secondaryChipFillOpacity: Double = 0.12
}
