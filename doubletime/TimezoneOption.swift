//
//  TimezoneOption.swift
//  doubletime
//

import Foundation

struct TimezoneOption: Identifiable, Hashable {
    let id: String
    let city: String
    let abbreviation: String

    static let all: [TimezoneOption] = {
        TimeZone.knownTimeZoneIdentifiers.compactMap { id -> TimezoneOption? in
            guard let tz = TimeZone(identifier: id) else { return nil }
            let lastPart = id.components(separatedBy: "/").last ?? id
            let city = lastPart.replacing("_", with: " ")
            return TimezoneOption(
                id: id,
                city: city,
                abbreviation: tz.abbreviation() ?? ""
            )
        }
        .sorted { $0.city.localizedCaseInsensitiveCompare($1.city) == .orderedAscending }
    }()
}
