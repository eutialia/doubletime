//
//  StatusMenuZone.swift
//  doubletime
//

import Foundation

/// One zone's row content in the status menu, captured at the instant the menu
/// opens.
///
/// A plain value rather than a live read of `ClockModel`: a menu pumps events in
/// its own tracking run loop, where timers scheduled in the default mode never
/// fire, so a self-refreshing row would sit frozen with no error to show for it.
/// Menus are short-lived, so a snapshot is both the honest model and the one
/// that keeps the app timer-free while the menu is closed.
///
/// `nonisolated`: the target builds with `SWIFT_DEFAULT_ACTOR_ISOLATION =
/// MainActor`, which would otherwise bind this pure value type — and its
/// memberwise init — to the main actor, leaving `make` unable to construct it
/// once the target moves to the Swift 6 language mode.
nonisolated struct StatusMenuZone {
    /// The 2–5 char zone code, override or derived — the same string the glyph
    /// puts above the cell.
    let code: String
    let city: String
    /// `HH:mm`, in whichever hour format the glyph is showing.
    let time: String
    /// nil in 24-hour mode. Drives the chip hue ONLY; the AM/PM word lives in
    /// `caption` (see its note).
    let period: ClockModel.Period?
    /// `Mon 20 Apr`, with ` · PM` appended in 12-hour mode.
    ///
    /// Canon forbids spelling out AM/PM anywhere, because in the glyph the hue
    /// is the only channel that fits and the two chips read against each other.
    /// A stacked menu row has neither constraint, and hue is otherwise the one
    /// piece of state with no second channel for a colorblind user — so the word
    /// goes in the caption and the chip itself stays pure hue.
    let caption: String
    /// `+5:30`, or `+5:30  +1d` when the calendar day differs. Secondary rows
    /// only: the primary zone is the anchor everything else is measured from.
    let offset: String?
    let isPrimary: Bool
    let accessibilityLabel: String
}

extension StatusMenuZone {
    /// Builds a row from already-resolved parts. Free of `ClockModel` state so
    /// the whole string layer is testable without a menu or a live clock.
    static func make(
        timezone: TimeZone,
        code: String,
        hour12: Bool,
        isPrimary: Bool,
        offsetMinutes: Int?,
        dayDelta: Int,
        at date: Date
    ) -> StatusMenuZone {
        let period = hour12 ? ClockModel.period(for: timezone, at: date) : nil
        let time = ClockModel.time(for: timezone, at: date, hour12: hour12)
        let city = ClockModel.cityName(from: timezone)
        let dateLabel = ClockModel.dateLabel(for: timezone, at: date)

        let periodWord = period.map { period in
            switch period {
            case .am: "AM"
            case .pm: "PM"
            }
        }
        let caption = periodWord.map { "\(dateLabel) · \($0)" } ?? dateLabel

        let offset = offsetMinutes.map { minutes -> String in
            let signed = ClockModel.offsetCaption(minutes: minutes, style: .exact)
            guard dayDelta != 0 else { return signed }
            let sign = dayDelta > 0 ? "+" : "\u{2212}"
            return "\(signed)  \(sign)\(abs(dayDelta))d"
        }

        // The row is one accessibility element — read as a sentence, not as five
        // fragments the user has to swipe through. The offset is spoken in words
        // because "+5:30" read aloud is noise.
        var spoken = ["\(city), \(code)", time]
        if let periodWord { spoken.append(periodWord) }
        spoken.append(dateLabel)
        if let offsetMinutes { spoken.append(ClockModel.spokenOffset(minutes: offsetMinutes)) }
        if let spokenDay = ClockModel.spokenDayDelta(dayDelta) { spoken.append(spokenDay) }

        return StatusMenuZone(
            code: code,
            city: city,
            time: time,
            period: period,
            caption: caption,
            offset: offset,
            isPrimary: isPrimary,
            accessibilityLabel: spoken.joined(separator: ", ")
        )
    }
}

@MainActor
extension StatusMenuZone {
    /// Both rows for one instant. Primary is listed first — the vertical order is
    /// deliberately the reverse of the glyph's horizontal order, because the
    /// primary is the zone the trailing `:mm` already belongs to.
    static func rows(from clock: ClockModel, at date: Date) -> (primary: Self, secondary: Self) {
        let offsetMinutes = ClockModel.offsetMinutes(
            from: clock.secondaryTimezone, to: clock.primaryTimezone, at: date
        )
        let dayDelta = ClockModel.dayDelta(
            from: clock.secondaryTimezone, to: clock.primaryTimezone, at: date
        )
        return (
            make(
                timezone: clock.primaryTimezone,
                code: clock.primaryLabel(at: date),
                hour12: clock.hour12,
                isPrimary: true,
                offsetMinutes: nil,
                dayDelta: 0,
                at: date
            ),
            make(
                timezone: clock.secondaryTimezone,
                code: clock.secondaryLabel(at: date),
                hour12: clock.hour12,
                isPrimary: false,
                offsetMinutes: offsetMinutes,
                dayDelta: dayDelta,
                at: date
            )
        )
    }
}
