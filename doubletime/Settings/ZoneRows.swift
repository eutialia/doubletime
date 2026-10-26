//
//  ZoneRows.swift
//  doubletime
//

import SwiftUI

/// The primary and secondary city rows, shared by Settings and onboarding.
struct ZoneRows: View {
    @Bindable var clock: ClockModel

    var body: some View {
        SettingsRow(
            label: "Primary city",
            caption: "Your home zone. It gets the brighter cell, and the trailing :mm always shows its minute."
        ) {
            ZoneRowControl(clock: clock, isPrimary: true)
        }

        SettingsRow(
            label: "Secondary city",
            caption: "The foreign zone. It gets the dimmer leading cell."
        ) {
            ZoneRowControl(clock: clock, isPrimary: false)
        }
    }
}
