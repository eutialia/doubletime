//
//  ZoneQueryTests.swift
//  doubletimeTests
//

import Testing
@testable import doubletime

struct ZoneQueryTests {
    /// A shortcut can hand back an id this Mac's table does not list. It must
    /// drop out rather than resolve.
    @Test func resolvesKnownIdentifiersAndDropsUnknownOnes() async throws {
        let entities = try await ZoneQuery().entities(
            for: ["Asia/Tokyo", "Mars/Olympus_Mons", "Europe/Zurich"]
        )
        #expect(entities.map(\.id) == ["Asia/Tokyo", "Europe/Zurich"])
    }
}
