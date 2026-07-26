//
//  ZoneRowControlTests.swift
//  doubletimeTests
//

import Foundation
import SwiftUI
import Testing
@testable import doubletime

struct ZoneRowControlTests {
    private let scratch = ScratchDefaults()

    /// The dropdown button's title is `"\(cityName) (\(resolvedCode))"` (or
    /// `"System (\(code))"` for the system-following primary) — committing a
    /// different zone through the model must change what the control renders.
    @Test @MainActor func dropdownTitleChangesPixelsWhenPrimaryZoneChanges() throws {
        let clock = scratch.makeClock()
        func render() throws -> Data {
            try pixelData(of: ZoneRowControl(clock: clock, isPrimary: true))
        }
        clock.commitZone(identifier: "Asia/Tokyo", isPrimary: true)
        let tokyo = try render()
        clock.commitZone(identifier: "America/Los_Angeles", isPrimary: true)
        let losAngeles = try render()
        #expect(tokyo != losAngeles)
    }

    @Test @MainActor func dropdownTitleChangesPixelsWhenSecondaryZoneChanges() throws {
        let clock = scratch.makeClock()
        func render() throws -> Data {
            try pixelData(of: ZoneRowControl(clock: clock, isPrimary: false))
        }
        clock.commitZone(identifier: "Asia/Tokyo", isPrimary: false)
        let tokyo = try render()
        clock.commitZone(identifier: "Asia/Kolkata", isPrimary: false)
        let kolkata = try render()
        #expect(tokyo != kolkata)
    }
}
