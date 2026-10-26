//
//  ClockIntents.swift
//  doubletime
//

import AppIntents

/// Each intent is a single call into the live `ClockModel` that AppDelegate
/// registers with `AppDependencyManager`, so a change made from Siri or
/// Shortcuts repaints the status item and Settings like a change made in the
/// app. Writing UserDefaults directly would not: the model only reads them
/// at launch.

struct SetSecondaryZoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Second Zone"
    static let description = IntentDescription("Shows another time zone in the menu bar clock's second cell.")

    @Parameter(title: "Zone") var zone: TimezoneOption
    @Dependency var clock: ClockModel

    static var parameterSummary: some ParameterSummary {
        Summary("Set the second zone to \(\.$zone)")
    }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        clock.commitZone(identifier: zone.id, isPrimary: false)
        return .result(dialog: "Doubletime's second zone is now \(zone.city).")
    }
}

struct SetPrimaryZoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Primary Zone"
    static let description = IntentDescription("Pins the menu bar clock's primary cell to a time zone instead of the Mac's.")

    @Parameter(title: "Zone") var zone: TimezoneOption
    @Dependency var clock: ClockModel

    static var parameterSummary: some ParameterSummary {
        Summary("Set the primary zone to \(\.$zone)")
    }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        clock.commitZone(identifier: zone.id, isPrimary: true)
        return .result(dialog: "Doubletime's primary zone is now \(zone.city).")
    }
}

/// The primary's "System (auto)" choice. A separate intent rather than an
/// optional zone, because the secondary has no system option to offer.
struct FollowSystemZoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Follow System Time Zone"
    static let description = IntentDescription("Makes the menu bar clock's primary cell follow the Mac's time zone.")

    @Dependency var clock: ClockModel

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        clock.commitZone(identifier: nil, isPrimary: true)
        return .result(dialog: "Doubletime's primary zone follows the Mac again.")
    }
}

nonisolated enum HourFormat: String, AppEnum {
    case twelveHour
    case twentyFourHour

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Hour Format"
    static let caseDisplayRepresentations: [HourFormat: DisplayRepresentation] = [
        .twelveHour: "12-hour",
        .twentyFourHour: "24-hour",
    ]
}

struct SetHourFormatIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Hour Format"
    static let description = IntentDescription("Switches the menu bar clock between 12-hour and 24-hour digits.")

    @Parameter(title: "Format") var format: HourFormat
    @Dependency var clock: ClockModel

    static var parameterSummary: some ParameterSummary {
        Summary("Use \(\.$format) digits")
    }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        clock.hour12 = format == .twelveHour
        return .result(dialog: "Doubletime now shows \(format) digits.")
    }
}

struct DoubletimeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetSecondaryZoneIntent(),
            phrases: [
                "Set the second zone in \(.applicationName)",
                "Change \(.applicationName)'s second zone",
            ],
            shortTitle: "Set Second Zone",
            systemImageName: "clock.badge"
        )
        AppShortcut(
            intent: SetPrimaryZoneIntent(),
            phrases: ["Set the primary zone in \(.applicationName)"],
            shortTitle: "Set Primary Zone",
            systemImageName: "clock"
        )
        AppShortcut(
            intent: FollowSystemZoneIntent(),
            phrases: ["Make \(.applicationName) follow the system time zone"],
            shortTitle: "Follow System Zone",
            systemImageName: "location"
        )
        AppShortcut(
            intent: SetHourFormatIntent(),
            phrases: ["Use \(\.$format) time in \(.applicationName)"],
            shortTitle: "Set Hour Format",
            systemImageName: "12.circle"
        )
    }
}
