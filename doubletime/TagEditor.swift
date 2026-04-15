//
//  TagEditor.swift
//  doubletime
//

import SwiftUI

struct TagEditor: View {
    @Binding var secondaryLabel: String
    @Binding var primaryLabel: String
    let draftTimezoneId: String?
    let fallbackTimezone: TimeZone

    private var secondaryPlaceholder: String {
        let tz = draftTimezoneId.flatMap(TimeZone.init(identifier:)) ?? fallbackTimezone
        return ClockModel.cityName(from: tz)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Secondary") {
                TextField(secondaryPlaceholder, text: $secondaryLabel)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
            }
            LabeledContent("Primary") {
                TextField(ClockModel.primaryDefaultLabel, text: $primaryLabel)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
            }
        }
    }
}
