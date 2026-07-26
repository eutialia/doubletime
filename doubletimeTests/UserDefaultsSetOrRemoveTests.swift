//
//  UserDefaultsSetOrRemoveTests.swift
//  doubletimeTests
//

import Foundation
import Testing
@testable import doubletime

struct UserDefaultsSetOrRemoveTests {
    private let scratch = ScratchDefaults()
    private let key = "setOrRemoveProbe"

    @Test func setsANonNilValue() {
        scratch.store.setOrRemove("PDT", forKey: key)
        #expect(scratch.store.string(forKey: key) == "PDT")
    }

    /// nil must delete the key, not store an empty string: ClockModel reads
    /// these back with `string(forKey:)` and treats "no value" as "no
    /// override", so a leftover "" would resolve as a present-but-blank label.
    @Test func nilRemovesTheKeyEntirely() {
        scratch.store.setOrRemove("PDT", forKey: key)
        scratch.store.setOrRemove(nil, forKey: key)
        #expect(scratch.store.object(forKey: key) == nil)
        #expect(scratch.store.string(forKey: key) == nil)
        #expect(scratch.store.dictionaryRepresentation()[key] == nil)
    }

    @Test func removingAnAbsentKeyIsHarmless() {
        scratch.store.setOrRemove(nil, forKey: key)
        #expect(scratch.store.object(forKey: key) == nil)
    }

    /// The write path is per-key: removing one override must not disturb the
    /// other settings sharing the domain.
    @Test func writesAreScopedToTheirKey() {
        scratch.store.setOrRemove("IST", forKey: key)
        scratch.store.setOrRemove("JST", forKey: "\(key)Other")
        scratch.store.setOrRemove(nil, forKey: key)
        #expect(scratch.store.string(forKey: "\(key)Other") == "JST")
    }
}
