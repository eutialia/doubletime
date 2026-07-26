//
//  TimezoneSearch.swift
//  doubletime
//

import Foundation

/// The zone picker's search behaviour, as pure functions over its inputs. It
/// lives in the Model layer rather than inside TimezoneSearchList because none
/// of it is presentation: it is the answer to "given what the user typed, which
/// rows exist and which one do we scroll to" — the part of the picker worth
/// pinning down without rendering a view.
nonisolated enum TimezoneSearch {
    /// Stable scroll/id anchor for the pinned System row. Not an IANA
    /// identifier, so it cannot collide with a real row's id.
    static let systemRowID = "__system__"

    /// What the System row matches on. The row's visible title is
    /// "System (auto)", but the parentheses would make a literal title match
    /// fail for the obvious query "system auto" — so the haystack is the two
    /// words alone, and "sys", "auto" and "system auto" all keep the row.
    private static let systemRowHaystack = "system auto"

    /// Rows matching `query`, searched across the city name, the IANA id and
    /// the abbreviation. `localizedStandardContains` is the Finder-style
    /// comparison: case- AND diacritic-insensitive, so "sao paulo" finds
    /// "São Paulo". An empty query keeps every row.
    static func filteredOptions(
        matching query: String,
        in options: [TimezoneOption] = TimezoneOption.all
    ) -> [TimezoneOption] {
        guard !query.isEmpty else { return options }
        return options.filter {
            $0.city.localizedStandardContains(query) ||
            $0.id.localizedStandardContains(query) ||
            $0.abbreviation.localizedStandardContains(query)
        }
    }

    /// Whether the pinned "System (auto)" row survives the current query. Only
    /// the primary row offers it at all (`includeSystemRow`).
    static func showsSystemRow(includeSystemRow: Bool, matching query: String) -> Bool {
        includeSystemRow &&
        (query.isEmpty || systemRowHaystack.localizedStandardContains(query))
    }

    /// The row id to scroll to on open — the active choice, but only if it
    /// survived the filter; otherwise nothing, and the list stays at the top.
    static func scrollTarget(
        currentIdentifier: String?,
        options: [TimezoneOption],
        showsSystemRow: Bool
    ) -> String? {
        if let currentIdentifier {
            return options.contains { $0.id == currentIdentifier } ? currentIdentifier : nil
        }
        return showsSystemRow ? systemRowID : nil
    }
}
