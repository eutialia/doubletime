//
//  GlyphVariant.swift
//  doubletime
//

import Foundation

/// The user-selectable clock-face indicator style drawn on the secondary cell.
///
/// - `arc`: a single thin sweep from 12 o'clock (round caps).
/// - `segmented`: quarter-hour tick segments with legible gaps (butt caps).
///
/// The raw value is persisted in UserDefaults.
enum GlyphVariant: String, CaseIterable, Hashable {
    case arc
    case segmented
}
