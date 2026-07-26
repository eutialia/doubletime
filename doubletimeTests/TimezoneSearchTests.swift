//
//  TimezoneSearchTests.swift
//  doubletimeTests
//

import Foundation
import Testing
@testable import doubletime

/// A four-row stand-in for the real table, so the matching rules are pinned to
/// fixed strings instead of to whatever cities and abbreviations the host's
/// tzdata happens to carry. São Paulo supplies the diacritic, Kathmandu the
/// offset-shaped abbreviation.
private let sampleOptions: [TimezoneOption] = [
    TimezoneOption(id: "America/Sao_Paulo", city: "São Paulo", abbreviation: "BRT",
                   timezone: timezone("America/Sao_Paulo")),
    TimezoneOption(id: "Asia/Tokyo", city: "Tokyo", abbreviation: "GMT+9",
                   timezone: timezone("Asia/Tokyo")),
    TimezoneOption(id: "Asia/Kathmandu", city: "Kathmandu", abbreviation: "GMT+5:45",
                   timezone: timezone("Asia/Kathmandu")),
    TimezoneOption(id: "Europe/Zurich", city: "Zurich", abbreviation: "CET",
                   timezone: timezone("Europe/Zurich")),
]

struct TimezoneSearchTests {
    // MARK: filteredOptions

    @Test func emptyQueryKeepsEveryRow() {
        #expect(TimezoneSearch.filteredOptions(matching: "", in: sampleOptions) == sampleOptions)
        // …including over the real table, which is what the picker opens with.
        #expect(TimezoneSearch.filteredOptions(matching: "") == TimezoneOption.all)
    }

    @Test(arguments: [
        ("Kathmandu", ["Asia/Kathmandu"]),                       // city
        ("kathmandu", ["Asia/Kathmandu"]),                       // …case-insensitively
        ("TOKYO", ["Asia/Tokyo"]),
        ("Asia/", ["Asia/Tokyo", "Asia/Kathmandu"]),             // IANA identifier fragment
        ("america", ["America/Sao_Paulo"]),                      // …case-insensitively
        ("BRT", ["America/Sao_Paulo"]),                          // abbreviation
        ("cet", ["Europe/Zurich"]),                              // …case-insensitively
        ("+5:45", ["Asia/Kathmandu"]),                           // offset-shaped abbreviation
        ("São", ["America/Sao_Paulo"]),                          // diacritic in the query
        ("sao paulo", ["America/Sao_Paulo"]),                    // diacritic-insensitive both ways
        ("SAO PAULO", ["America/Sao_Paulo"]),
        ("zur", ["Europe/Zurich"]),                              // prefix
        ("urich", ["Europe/Zurich"]),                            // …and infix: contains, not hasPrefix
        ("Nowhere", []),
    ])
    func queryMatchesCityIdentifierAndAbbreviation(query: String, expected: [String]) {
        #expect(TimezoneSearch.filteredOptions(matching: query, in: sampleOptions).map(\.id) == expected)
    }

    /// Filtering must not reorder: the table arrives sorted by city and the
    /// list renders it as-is.
    @Test func filteringPreservesTheTableOrder() {
        let filtered = TimezoneSearch.filteredOptions(matching: "a", in: sampleOptions)
        let survivors = sampleOptions.filter { filtered.contains($0) }
        #expect(filtered == survivors)
        #expect(filtered.count > 1, "the probe query has to keep more than one row for order to mean anything")
    }

    // MARK: showsSystemRow

    @Test(arguments: [
        (true, "", true),               // no query ⇒ the pinned row stays
        (true, "sys", true),
        (true, "auto", true),           // matches the second word, not just a prefix
        (true, "system auto", true),    // the whole haystack, which the visible title would fail
        (true, "SYSTEM", true),         // case-insensitive
        (true, "system (auto)", false), // the parenthesized title is NOT the haystack
        (true, "tokyo", false),
        (false, "", false),             // the secondary row never offers System
        (false, "system", false),
    ])
    func systemRowSurvivesOnlyMatchingQueries(includeSystemRow: Bool, query: String, expected: Bool) {
        #expect(TimezoneSearch.showsSystemRow(includeSystemRow: includeSystemRow, matching: query) == expected)
    }

    // MARK: scrollTarget

    @Test func scrollTargetPrefersTheCurrentSelection() {
        #expect(TimezoneSearch.scrollTarget(
            currentIdentifier: "Asia/Tokyo", options: sampleOptions, showsSystemRow: true
        ) == "Asia/Tokyo")
    }

    /// A selection the query filtered away must not be scrolled to — the list
    /// stays at the top instead.
    @Test func scrollTargetIsNilWhenTheSelectionWasFilteredOut() {
        let filtered = TimezoneSearch.filteredOptions(matching: "zurich", in: sampleOptions)
        #expect(TimezoneSearch.scrollTarget(
            currentIdentifier: "Asia/Tokyo", options: filtered, showsSystemRow: true
        ) == nil)
    }

    @Test func scrollTargetFallsBackToTheSystemRow() {
        #expect(TimezoneSearch.scrollTarget(
            currentIdentifier: nil, options: sampleOptions, showsSystemRow: true
        ) == TimezoneSearch.systemRowID)
        #expect(TimezoneSearch.scrollTarget(
            currentIdentifier: nil, options: sampleOptions, showsSystemRow: false
        ) == nil)
    }

    /// The System row's anchor must be unable to collide with a real row's id.
    @Test func systemRowIdentifierIsNotAZone() {
        #expect(TimeZone(identifier: TimezoneSearch.systemRowID) == nil)
        let collisions = TimezoneOption.all.filter { $0.id == TimezoneSearch.systemRowID }
        #expect(collisions.isEmpty)
    }
}
