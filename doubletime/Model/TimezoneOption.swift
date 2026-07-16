//
//  TimezoneOption.swift
//  doubletime
//

import Foundation

struct TimezoneOption: Identifiable, Hashable {
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
