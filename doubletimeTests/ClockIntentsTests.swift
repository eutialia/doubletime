//
//  ClockIntentsTests.swift
//  doubletimeTests
//

import Foundation
import Testing
@testable import doubletime

/// Runs each intent the way the system does: a default-initialized intent with
/// its parameters and dependency filled in before `perform()`. The system
/// resolves `@Dependency` from AppDelegate's registration; here the scratch
/// clock goes in through the same wrapper, so the app's real clock and
/// preferences are never touched.
@MainActor
struct ClockIntentsTests {
    private let scratch = ScratchDefaults()
    private let clock: ClockModel

    init() {
        clock = scratch.makeClock()
    }

    private func zone(_ id: String) throws -> TimezoneOption {
        try #require(TimezoneOption.option(id: id))
    }

    @Test func setSecondaryZoneChangesOnlyTheSecondary() async throws {
        let intent = SetSecondaryZoneIntent()
        intent.clock = clock
        intent.zone = try zone("Asia/Calcutta")
        _ = try await intent.perform()

        #expect(clock.secondaryTimezone.identifier == "Asia/Calcutta")
        #expect(clock.primaryIsSystem)
    }

    @Test func setPrimaryZoneChangesOnlyThePrimary() async throws {
        let intent = SetPrimaryZoneIntent()
        intent.clock = clock
        intent.zone = try zone("Europe/Zurich")
        _ = try await intent.perform()

        #expect(clock.primaryTimezoneIdentifier == "Europe/Zurich")
        #expect(clock.secondaryTimezone.identifier == "Asia/Tokyo")
    }

    @Test func followSystemZoneUnpinsThePrimary() async throws {
        clock.primaryTimezoneIdentifier = "Europe/Zurich"
        let intent = FollowSystemZoneIntent()
        intent.clock = clock
        _ = try await intent.perform()

        #expect(clock.primaryIsSystem)
    }

    @Test(arguments: [(HourFormat.twelveHour, true), (.twentyFourHour, false)])
    func setHourFormatSetsTheDigits(format: HourFormat, hour12: Bool) async throws {
        clock.hour12 = !hour12
        let intent = SetHourFormatIntent()
        intent.clock = clock
        intent.format = format
        _ = try await intent.perform()

        #expect(clock.hour12 == hour12)
    }
}
