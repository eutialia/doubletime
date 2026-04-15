//
//  TimezoneSearchList.swift
//  doubletime
//

import SwiftUI

struct TimezoneSearchList: View {
    @Binding var searchText: String
    @Binding var selection: String?
    let referenceTimezone: TimeZone

    private var filteredOptions: [TimezoneOption] {
        guard !searchText.isEmpty else { return TimezoneOption.all }
        return TimezoneOption.all.filter {
            $0.city.localizedStandardContains(searchText) ||
            $0.id.localizedStandardContains(searchText) ||
            $0.abbreviation.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search city, IANA id, or abbreviation", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.5))
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                List(filteredOptions, selection: $selection) { option in
                    TimezoneRow(
                        option: option,
                        now: context.date,
                        referenceTimezone: referenceTimezone
                    )
                    .tag(option.id)
                    .accessibilityElement(children: .combine)
                }
                .frame(minHeight: 260)
            }
        }
    }
}
