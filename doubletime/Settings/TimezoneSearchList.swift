//
//  TimezoneSearchList.swift
//  doubletime
//

import SwiftUI

/// The searchable IANA-zone list shown inside a zone-picker popover. Selecting a
/// row commits immediately via `onSelect`. When `includeSystemRow` is set, a
/// pinned "System (auto)" row maps to nil (the system zone). The row matching
/// `currentIdentifier` (or the System row when it is nil) shows a checkmark and
/// the list scrolls to it on open.
struct TimezoneSearchList: View {
    let referenceTimezone: TimeZone
    var includeSystemRow: Bool = false
    /// The active choice: an IANA id, or nil ⇒ the system zone (System row).
    var currentIdentifier: String? = nil
    /// nil ⇒ the system zone.
    let onSelect: (String?) -> Void

    @State private var searchText = ""

    /// Stable scroll/id anchor for the pinned System row.
    private static let systemRowID = "__system__"

    private var filteredOptions: [TimezoneOption] {
        guard !searchText.isEmpty else { return TimezoneOption.all }
        return TimezoneOption.all.filter {
            $0.city.localizedStandardContains(searchText) ||
            $0.id.localizedStandardContains(searchText) ||
            $0.abbreviation.localizedStandardContains(searchText)
        }
    }

    private var showSystemRow: Bool {
        includeSystemRow &&
        (searchText.isEmpty || "system auto".localizedStandardContains(searchText))
    }

    var body: some View {
        // Hoisted ABOVE the TimelineView so the per-minute tick only refreshes row
        // times — the (search-dependent) filtering is not re-evaluated per tick.
        let options = filteredOptions
        let systemRow = showSystemRow

        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(DesignTokens.settingsCaption)
                    .foregroundStyle(DesignTokens.textMuted)
                TextField("Search city, IANA id, or abbreviation", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DesignTokens.settingsBody)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignTokens.searchFieldFill)
            }

            TimelineView(.everyMinute) { context in
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if systemRow {
                                row {
                                    systemRowLabel
                                } action: {
                                    onSelect(nil)
                                }
                                .id(Self.systemRowID)
                                .accessibilityAddTraits(currentIdentifier == nil ? .isSelected : [])
                                Divider().opacity(0.4)
                            }
                            ForEach(options) { option in
                                let isSelected = option.id == currentIdentifier
                                row {
                                    HStack(spacing: 4) {
                                        TimezoneRow(option: option, now: context.date,
                                                    referenceTimezone: referenceTimezone)
                                        if isSelected { selectionMark }
                                    }
                                } action: {
                                    onSelect(option.id)
                                }
                                .id(option.id)
                                .accessibilityAddTraits(isSelected ? .isSelected : [])
                            }
                        }
                    }
                    .onAppear {
                        if let target = scrollTarget(options: options, systemRow: systemRow) {
                            proxy.scrollTo(target, anchor: .center)
                        }
                    }
                }
                .frame(height: 260)
            }
        }
        .padding(10)
        .frame(width: 300)
        .background(DesignTokens.card)
    }

    private var systemRowLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(DesignTokens.settingsFootnote)
                .foregroundStyle(DesignTokens.textMuted)
            Text("System (auto)")
                .font(DesignTokens.settingsBody)
                .foregroundStyle(DesignTokens.textStrong)
            Spacer(minLength: 0)
            if currentIdentifier == nil { selectionMark }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    /// Selection affordance: strong monochrome ink (the design bans accent hues;
    /// selection reads as ink weight, same rule as OptionCard).
    private var selectionMark: some View {
        Image(systemName: "checkmark")
            .font(DesignTokens.settingsFootnote.weight(.semibold))
            .foregroundStyle(DesignTokens.textStrong)
    }

    /// The row id to scroll to on open — only if it exists in the current list.
    private func scrollTarget(options: [TimezoneOption], systemRow: Bool) -> String? {
        if let currentIdentifier {
            return options.contains { $0.id == currentIdentifier } ? currentIdentifier : nil
        }
        return systemRow ? Self.systemRowID : nil
    }

    private func row<Label: View>(@ViewBuilder _ label: () -> Label, action: @escaping () -> Void) -> some View {
        Button(action: action) { label().padding(.horizontal, 4) }
            .buttonStyle(.plain)
    }
}
