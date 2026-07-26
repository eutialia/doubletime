//
//  TimezoneOptionTests.swift
//  doubletimeTests
//

import Foundation
import Testing
@testable import doubletime

struct TimezoneOptionTests {
    @Test func theTableIsPopulated() {
        #expect(!TimezoneOption.all.isEmpty)
        // compactMap drops nothing in practice: every known identifier resolves.
        #expect(TimezoneOption.all.count == TimeZone.knownTimeZoneIdentifiers.count)
    }

    @Test func identifiersAreUnique() {
        #expect(Set(TimezoneOption.all.map(\.id)).count == TimezoneOption.all.count)
    }

    /// The picker relies on the table arriving sorted by city (it renders the
    /// array as-is and has no sort of its own).
    @Test func rowsAreSortedByCity() {
        let outOfOrder = zip(TimezoneOption.all, TimezoneOption.all.dropFirst()).filter {
            $0.city.localizedCaseInsensitiveCompare($1.city) == .orderedDescending
        }
        #expect(outOfOrder.isEmpty, "\(outOfOrder.count) adjacent pairs are out of order")
    }

    /// Row↔zone ALIGNMENT: every row's cached fields must belong to the zone
    /// its own `id` names. This re-derives them with the very expressions the
    /// table used, so it cannot catch a wrong derivation — what it catches is a
    /// mis-zip or a shuffle, a row carrying another zone's city.
    ///
    /// `abbreviation` is deliberately NOT re-checked: the table is built once at
    /// process start while the check would run at `now`, so a DST transition
    /// crossing between the two would fail the test for a correct table.
    @Test func everyRowIsAlignedWithItsOwnTimeZone() throws {
        for option in TimezoneOption.all {
            let tz = try #require(TimeZone(identifier: option.id), "\(option.id) does not resolve")
            #expect(option.timezone == tz)
            #expect(option.city == ClockModel.cityName(from: tz))
        }
    }

    /// Cities are display strings, so the identifier's machine syntax must be
    /// gone from all of them.
    @Test func cityNamesCarryNoIdentifierSyntax() {
        let unformatted = TimezoneOption.all.filter {
            $0.city.contains("_") || $0.city.contains("/") || $0.city.isEmpty
        }
        #expect(unformatted.isEmpty, "\(unformatted.map(\.id).prefix(5)) still read as identifiers")
    }

    /// Spot checks for the city extraction the table depends on: a compound
    /// name, a three-component identifier, and a single-component one.
    @Test(arguments: [
        ("America/New_York", "New York"),
        ("America/Argentina/Buenos_Aires", "Buenos Aires"),
        ("GMT", "GMT"),  // the separator-less row; "UTC" is not a known id (it normalizes to GMT)
    ])
    func knownRowsCarryTheirCityName(identifier: String, city: String) throws {
        let option = try #require(TimezoneOption.all.first { $0.id == identifier })
        #expect(option.city == city)
    }
}
