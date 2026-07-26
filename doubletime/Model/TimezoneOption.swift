//
//  TimezoneOption.swift
//  doubletime
//

import Foundation

/// One row of the zone picker: an IANA zone with the strings the row is
/// searched and sorted by, precomputed once. `nonisolated` — a pure value type
/// and an immutable table, so the search logic over it can run (and be tested)
/// off the main actor, like ClockModel's pure statics.
nonisolated struct TimezoneOption: Identifiable, Hashable {
    let id: String
    let city: String
    let abbreviation: String
    let timezone: TimeZone

    static let all: [TimezoneOption] = {
        TimeZone.knownTimeZoneIdentifiers.compactMap { id -> TimezoneOption? in
            guard let tz = TimeZone(identifier: id) else { return nil }
            return TimezoneOption(
                id: id,
                city: ClockModel.cityName(from: tz),
                abbreviation: tz.abbreviation() ?? "",
                timezone: tz
            )
        }
        .sorted { $0.city.localizedCaseInsensitiveCompare($1.city) == .orderedAscending }
    }()
}
