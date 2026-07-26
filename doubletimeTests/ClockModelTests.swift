//
//  ClockModelTests.swift
//  doubletimeTests
//

import Foundation
import Testing
@testable import doubletime

/// One persisted setting as a write plus a stringly-typed read, so the seven
/// heterogeneous properties can share a single round-trip test.
struct PersistedSetting: Sendable, CustomTestStringConvertible {
    let name: String
    let write: @MainActor @Sendable (ClockModel) -> Void
    let read: @MainActor @Sendable (ClockModel) -> String

    var testDescription: String { name }

    static let all: [PersistedSetting] = [
        PersistedSetting(
            name: "secondaryTimezone",
            write: { $0.secondaryTimezone = timezone("Europe/Zurich") },
            read: { $0.secondaryTimezone.identifier }
        ),
        PersistedSetting(
            name: "primaryTimezoneIdentifier",
            write: { $0.primaryTimezoneIdentifier = "Asia/Kolkata" },
            read: { $0.primaryTimezoneIdentifier ?? "system" }
        ),
        PersistedSetting(
            name: "secondaryLabelOverride",
            write: { $0.secondaryLabelOverride = "ZRH" },
            read: { $0.secondaryLabelOverride ?? "none" }
        ),
        PersistedSetting(
            name: "primaryLabelOverride",
            write: { $0.primaryLabelOverride = "HOME" },
            read: { $0.primaryLabelOverride ?? "none" }
        ),
        PersistedSetting(
            name: "hour12",
            write: { $0.hour12 = true },
            read: { String($0.hour12) }
        ),
        PersistedSetting(
            name: "variant",
            write: { $0.variant = .segmented },
            read: { $0.variant.rawValue }
        ),
        PersistedSetting(
            name: "blinkColon",
            write: { $0.blinkColon = true },
            read: { String($0.blinkColon) }
        ),
    ]
}

@MainActor
struct ClockModelTests {
    private let scratch = ScratchDefaults()

    // MARK: Persistence

    /// Every setting the pane writes must survive relaunch: write on one
    /// model, read on a second one opened over the same domain.
    @Test(arguments: PersistedSetting.all)
    func persistedSettingRoundTrips(setting: PersistedSetting) {
        let written = ClockModel(defaults: scratch.store)
        setting.write(written)

        let reloaded = ClockModel(defaults: scratch.reopened())
        #expect(setting.read(reloaded) == setting.read(written))

        // Guards the round-trip against vacuity: the write has to have moved
        // the value off what a pristine store yields, or "it round-trips"
        // would hold even if nothing were persisted at all.
        let pristine = ScratchDefaults()
        #expect(setting.read(reloaded) != setting.read(ClockModel(defaults: pristine.store)))
    }

    /// Settings are independent keys — writing one must not disturb the rest.
    @Test func writingOneSettingLeavesTheOthersAtTheirDefaults() {
        let written = ClockModel(defaults: scratch.store)
        written.variant = .segmented

        let reloaded = ClockModel(defaults: scratch.reopened())
        #expect(reloaded.variant == .segmented)
        #expect(reloaded.hour12 == false)
        #expect(reloaded.blinkColon == false)
        #expect(reloaded.secondaryTimezone.identifier == "Asia/Tokyo")
        #expect(reloaded.primaryTimezoneIdentifier == nil)
    }

    @Test func emptyStoreYieldsTheDocumentedDefaults() {
        let model = ClockModel(defaults: scratch.store)
        #expect(model.secondaryTimezone.identifier == "Asia/Tokyo")
        #expect(model.primaryTimezoneIdentifier == nil)
        #expect(model.primaryIsSystem)
        #expect(model.secondaryLabelOverride == nil)
        #expect(model.primaryLabelOverride == nil)
        #expect(model.hour12 == false)
        #expect(model.variant == .arc)
        #expect(model.blinkColon == false)
        // Transient interaction state is deliberately not persisted.
        #expect(!model.statusItemHovered)
        #expect(model.systemZoneGeneration == 0)
    }

    /// A persisted identifier no `TimeZone` recognizes (a renamed IANA zone,
    /// say) must not leave the clock without a zone — and the primary must
    /// self-heal COMPLETELY: an unresolvable pin would follow the system
    /// anyway, so the model becomes "System" deliberately (`primaryIsSystem`
    /// tells the truth, the picker shows a real selection) and the dangling id
    /// is purged from the store rather than resurfacing on the next launch.
    @Test func unresolvableStoredZonesFallBack() {
        scratch.store.set("Not/AZone", forKey: ClockModel.secondaryTimezoneKey)
        scratch.store.set("Not/AZone", forKey: ClockModel.primaryTimezoneKey)

        let store = scratch.reopened()
        let model = ClockModel(defaults: store)
        #expect(model.secondaryTimezone.identifier == "Asia/Tokyo")
        #expect(model.primaryTimezone.identifier == TimeZone.autoupdatingCurrent.identifier)
        #expect(model.primaryTimezoneIdentifier == nil)
        #expect(model.primaryIsSystem)
        // Read back through the same instance the model healed — two handles to
        // one suite are not guaranteed immediately consistent.
        #expect(store.string(forKey: ClockModel.primaryTimezoneKey) == nil)

        // The healed state must survive a relaunch as a deliberate "System".
        let relaunched = ClockModel(defaults: scratch.reopened())
        #expect(relaunched.primaryIsSystem)
    }

    // MARK: Primary zone resolution

    @Test func primaryZoneTracksItsIdentifierBothWays() {
        let model = ClockModel(defaults: scratch.store)
        #expect(model.primaryIsSystem)
        #expect(model.primaryTimezone.identifier == TimeZone.autoupdatingCurrent.identifier)

        model.primaryTimezoneIdentifier = "Asia/Kolkata"
        #expect(!model.primaryIsSystem)
        #expect(model.primaryTimezone.identifier == "Asia/Kolkata")

        // Back to system: the pinned snapshot must be dropped, not kept.
        model.primaryTimezoneIdentifier = nil
        #expect(model.primaryIsSystem)
        #expect(model.primaryTimezone.identifier == TimeZone.autoupdatingCurrent.identifier)
    }

    // MARK: Labels

    @Test func labelsFallBackToTheDerivedDefault() {
        let model = ClockModel(defaults: scratch.store)
        model.secondaryTimezone = timezone("Asia/Kolkata")
        model.primaryTimezoneIdentifier = "America/New_York"

        #expect(model.secondaryLabel(at: reference)
                == ClockModel.defaultLabel(for: model.secondaryTimezone, at: reference))
        #expect(model.primaryLabel(at: reference)
                == ClockModel.defaultLabel(for: model.primaryTimezone, at: reference))
    }

    @Test func labelOverridesWinAndAreSanitized() {
        let model = ClockModel(defaults: scratch.store)
        model.secondaryLabelOverride = "home base"
        model.primaryLabelOverride = "n.y.c!"

        #expect(model.secondaryLabel(at: reference) == ClockModel.sanitizedLabel("home base"))
        #expect(model.primaryLabel(at: reference) == ClockModel.sanitizedLabel("n.y.c!"))
    }

    /// A blank override is not a label — it must fall through to the derived
    /// code rather than render an empty cell.
    @Test func blankOverridesFallThrough() {
        let model = ClockModel(defaults: scratch.store)
        model.secondaryLabelOverride = "   "
        #expect(model.secondaryLabel(at: reference)
                == ClockModel.defaultLabel(for: model.secondaryTimezone, at: reference))
    }

    /// The derived-label cache is keyed by zone AND its UTC offset, so the same
    /// zone must re-derive across a DST transition instead of serving a stale
    /// winter code all summer.
    @Test func derivedLabelCacheRevalidatesAcrossDaylightSaving() {
        let model = ClockModel(defaults: scratch.store)
        model.secondaryTimezone = timezone("America/New_York")
        let winter = utcInstant(month: 1, day: 15, hour: 12)
        let summer = utcInstant(month: 7, day: 15, hour: 12)

        #expect(model.secondaryLabel(at: winter) == ClockModel.defaultLabel(for: timezone("America/New_York"), at: winter))
        #expect(model.secondaryLabel(at: summer) == ClockModel.defaultLabel(for: timezone("America/New_York"), at: summer))
        // …and the two seasons genuinely differ, so the second read can't have
        // been a cache hit that happened to look right.
        #expect(model.secondaryLabel(at: winter) != model.secondaryLabel(at: summer))
    }

    // MARK: commitZone — primary row

    @Test func commitZonePrimarySetsTheZoneAndClearsTheOverride() {
        let model = ClockModel(defaults: scratch.store)
        model.primaryLabelOverride = "HOME"

        model.commitZone(identifier: "Europe/Paris", isPrimary: true)

        #expect(model.primaryTimezoneIdentifier == "Europe/Paris")
        #expect(model.primaryTimezone.identifier == "Europe/Paris")
        #expect(model.primaryLabelOverride == nil)
        #expect(model.primaryLabel(at: reference)
                == ClockModel.defaultLabel(for: model.primaryTimezone, at: reference))
    }

    /// Re-picking the row that is already selected must not throw away a code
    /// the user typed.
    @Test func commitZonePrimaryWithTheSameIdentifierKeepsTheOverride() {
        let model = ClockModel(defaults: scratch.store)
        model.primaryTimezoneIdentifier = "Europe/Paris"
        model.primaryLabelOverride = "HOME"

        model.commitZone(identifier: "Europe/Paris", isPrimary: true)

        #expect(model.primaryTimezoneIdentifier == "Europe/Paris")
        #expect(model.primaryLabelOverride == "HOME")
        #expect(model.primaryLabel(at: reference) == "HOME")
    }

    @Test func commitZonePrimaryWithNilRevertsToTheSystemZone() {
        let model = ClockModel(defaults: scratch.store)
        model.primaryTimezoneIdentifier = "Europe/Paris"
        model.primaryLabelOverride = "HOME"

        model.commitZone(identifier: nil, isPrimary: true)

        #expect(model.primaryIsSystem)
        #expect(model.primaryTimezoneIdentifier == nil)
        #expect(model.primaryTimezone.identifier == TimeZone.autoupdatingCurrent.identifier)
        #expect(model.primaryLabelOverride == nil)
    }

    /// Already on System (auto): the nil pick is the current selection, so the
    /// typed code survives.
    @Test func commitZonePrimaryWithNilWhileAlreadySystemIsANoOp() {
        let model = ClockModel(defaults: scratch.store)
        model.primaryLabelOverride = "HOME"

        model.commitZone(identifier: nil, isPrimary: true)

        #expect(model.primaryIsSystem)
        #expect(model.primaryLabelOverride == "HOME")
    }

    // MARK: commitZone — secondary row

    @Test func commitZoneSecondarySetsTheZoneAndClearsTheOverride() {
        let model = ClockModel(defaults: scratch.store)
        model.secondaryLabelOverride = "ZZZ"

        model.commitZone(identifier: "Europe/Paris", isPrimary: false)

        #expect(model.secondaryTimezone.identifier == "Europe/Paris")
        #expect(model.secondaryLabelOverride == nil)
    }

    @Test(arguments: [
        "Asia/Tokyo",   // already the secondary zone — re-picking must not clear the code
        "Not/AZone",    // no TimeZone recognizes it
    ])
    func commitZoneSecondaryIgnoresSameAndUnresolvableIdentifiers(identifier: String) {
        let model = ClockModel(defaults: scratch.store)
        #expect(model.secondaryTimezone.identifier == "Asia/Tokyo")
        model.secondaryLabelOverride = "ZZZ"

        model.commitZone(identifier: identifier, isPrimary: false)

        #expect(model.secondaryTimezone.identifier == "Asia/Tokyo")
        #expect(model.secondaryLabelOverride == "ZZZ")
    }

    /// The secondary row has no System option, so a nil pick there is ignored
    /// rather than resolving to the system zone.
    @Test func commitZoneSecondaryIgnoresNil() {
        let model = ClockModel(defaults: scratch.store)
        model.secondaryTimezone = timezone("Europe/Paris")
        model.secondaryLabelOverride = "ZZZ"

        model.commitZone(identifier: nil, isPrimary: false)

        #expect(model.secondaryTimezone.identifier == "Europe/Paris")
        #expect(model.secondaryLabelOverride == "ZZZ")
    }

    /// A commit is a real setting change, so it has to reach the store too —
    /// not just the in-memory model.
    @Test func commitZonePersists() {
        let model = ClockModel(defaults: scratch.store)
        model.commitZone(identifier: "Europe/Paris", isPrimary: false)
        model.commitZone(identifier: "America/New_York", isPrimary: true)

        let reloaded = ClockModel(defaults: scratch.reopened())
        #expect(reloaded.secondaryTimezone.identifier == "Europe/Paris")
        #expect(reloaded.primaryTimezoneIdentifier == "America/New_York")
    }

    // MARK: City names

    @Test(arguments: [
        ("America/New_York", "New York"),                  // underscores become spaces
        ("Asia/Kathmandu", "Kathmandu"),
        ("America/Argentina/Buenos_Aires", "Buenos Aires"), // three-component id ⇒ last wins
        ("GMT", "GMT"),                                     // no separator at all
    ])
    func cityNameIsTheLastIdentifierComponent(identifier: String, expected: String) {
        #expect(ClockModel.cityName(from: timezone(identifier)) == expected)
    }

    // MARK: Format-aware hour and time

    /// The 12/24 choice is made in exactly one place, so the switch must hand
    /// back the very strings the two dedicated formatters produce.
    @Test(arguments: ["Asia/Kathmandu", "America/Los_Angeles", "Pacific/Wallis", "UTC"])
    func hourWithFormatFlagDelegatesToTheMatchingFormatter(identifier: String) {
        let tz = timezone(identifier)
        #expect(ClockModel.hour(for: tz, at: reference, hour12: true) == ClockModel.hour12(for: tz, at: reference))
        #expect(ClockModel.hour(for: tz, at: reference, hour12: false) == ClockModel.hour(for: tz, at: reference))
    }

    /// The joined `HH:mm` used by the picker rows and the status menu.
    @Test(arguments: [
        ("America/Los_Angeles", false, "05:00"),  // PDT at the reference instant
        ("America/Los_Angeles", true, "05:00"),   // …the same in 12-hour form
        ("Asia/Kathmandu", false, "17:45"),       // +5:45 — a quarter-hour zone
        ("Asia/Kathmandu", true, "05:45"),        // …which reads 05:45 PM
        ("Pacific/Wallis", false, "00:00"),       // midnight renders 00, never 24
        ("Pacific/Wallis", true, "12:00"),        // …and 12 in the one-based clock
    ])
    func timeJoinsTheZoneWallClock(identifier: String, hour12: Bool, expected: String) {
        #expect(ClockModel.time(for: timezone(identifier), at: reference, hour12: hour12) == expected)
    }
}
