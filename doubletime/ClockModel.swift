//
//  ClockModel.swift
//  doubletime
//

import SwiftUI

@Observable @MainActor
final class ClockModel {
    static let leftTimezoneKey = "secondaryTimezoneIdentifier"
    static let leftLabelKey = "secondaryLabelOverride"
    static let rightLabelKey = "primaryLabelOverride"
    static let primaryDefaultLabel = "Local"

    var leftTimezone: TimeZone {
        didSet {
            UserDefaults.standard.set(leftTimezone.identifier, forKey: Self.leftTimezoneKey)
        }
    }

    var rightTimezone: TimeZone { .current }

    var leftLabelOverride: String? {
        didSet {
            if let v = leftLabelOverride {
                UserDefaults.standard.set(v, forKey: Self.leftLabelKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.leftLabelKey)
            }
        }
    }

    var rightLabelOverride: String? {
        didSet {
            if let v = rightLabelOverride {
                UserDefaults.standard.set(v, forKey: Self.rightLabelKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.rightLabelKey)
            }
        }
    }

    var leftLabel: String { leftLabelOverride ?? "" }

    var rightLabel: String { rightLabelOverride ?? Self.primaryDefaultLabel }

    init() {
        let savedId = UserDefaults.standard.string(forKey: Self.leftTimezoneKey)
        leftTimezone = savedId.flatMap(TimeZone.init(identifier:))
            ?? TimeZone(identifier: "Asia/Tokyo")
            ?? TimeZone.current
        leftLabelOverride = UserDefaults.standard.string(forKey: Self.leftLabelKey)
        rightLabelOverride = UserDefaults.standard.string(forKey: Self.rightLabelKey)
    }

    static func cityName(from tz: TimeZone) -> String {
        let last = tz.identifier.components(separatedBy: "/").last ?? tz.identifier
        return last.replacing("_", with: " ")
    }

    nonisolated static func hour(for tz: TimeZone, at date: Date) -> String {
        date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))",
                timeZone: tz,
                calendar: Calendar(identifier: .gregorian)
            )
        )
    }

    nonisolated static func minute(for tz: TimeZone, at date: Date) -> String {
        date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(minute: .twoDigits)",
                timeZone: tz,
                calendar: Calendar(identifier: .gregorian)
            )
        )
    }
}
