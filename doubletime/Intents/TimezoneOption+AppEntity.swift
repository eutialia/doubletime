//
//  TimezoneOption+AppEntity.swift
//  doubletime
//

import AppIntents

/// The picker's zone rows, exposed to Siri, Spotlight and Shortcuts as they
/// are. The id is the IANA identifier, so a zone persisted in a shortcut
/// resolves through `ZoneQuery` like a fresh pick.
nonisolated extension TimezoneOption: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Time Zone"
    static let defaultQuery = ZoneQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(city)", subtitle: "\(id)")
    }
}

/// Resolves zones against the same table and search the Settings picker uses.
nonisolated struct ZoneQuery: EntityStringQuery {
    /// An id the table does not list drops out, and the system asks for the
    /// zone again.
    func entities(for identifiers: [String]) async throws -> [TimezoneOption] {
        identifiers.compactMap(TimezoneOption.option(id:))
    }

    func entities(matching string: String) async throws -> [TimezoneOption] {
        TimezoneSearch.filteredOptions(matching: string)
    }

    func suggestedEntities() async throws -> [TimezoneOption] {
        TimezoneOption.all
    }
}
