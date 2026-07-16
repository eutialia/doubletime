//
//  UserDefaults+SetOrRemove.swift
//  doubletime
//

import Foundation

extension UserDefaults {
    /// Persist `value` under `key`, or remove the key entirely when `value` is nil
    /// — the single write path for the optional string settings that back the
    /// primary zone and the two label overrides.
    func setOrRemove(_ value: String?, forKey key: String) {
        if let value {
            set(value, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
}
