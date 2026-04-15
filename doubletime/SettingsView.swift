//
//  SettingsView.swift
//  doubletime
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var clock: ClockModel
    @State private var searchText: String = ""
    @State private var draftTimezoneId: String?
    @State private var draftSecondaryLabel: String = ""
    @State private var draftPrimaryLabel: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsHeader(
                previewSecondaryTimezone: previewSecondaryTimezone,
                secondaryLabel: draftSecondaryLabel,
                primaryTimezone: clock.rightTimezone,
                primaryLabel: previewPrimaryLabel
            )

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Secondary zone")
                TimezoneSearchList(
                    searchText: $searchText,
                    selection: $draftTimezoneId,
                    referenceTimezone: clock.rightTimezone
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Display tags")
                TagEditor(
                    secondaryLabel: $draftSecondaryLabel,
                    primaryLabel: $draftPrimaryLabel,
                    draftTimezoneId: draftTimezoneId,
                    fallbackTimezone: clock.leftTimezone
                )
            }

            Spacer(minLength: 0)

            ConfirmButtonRow(
                applyAction: applyAndClose,
                cancelAction: closeWindow,
                isApplyEnabled: hasChanges
            )
        }
        .padding(24)
        .frame(width: 520, height: 680)
        .onAppear(perform: resetState)
        .onChange(of: draftTimezoneId) { oldValue, newValue in
            if oldValue != nil, let newValue, oldValue != newValue {
                draftSecondaryLabel = ""
            }
        }
    }

    private var previewSecondaryTimezone: TimeZone {
        draftTimezoneId.flatMap(TimeZone.init(identifier:)) ?? clock.leftTimezone
    }

    private var previewPrimaryLabel: String {
        let trimmed = draftPrimaryLabel.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? ClockModel.primaryDefaultLabel : trimmed
    }

    private var hasChanges: Bool {
        (draftTimezoneId ?? clock.leftTimezone.identifier) != clock.leftTimezone.identifier ||
        draftSecondaryLabel != (clock.leftLabelOverride ?? "") ||
        draftPrimaryLabel != (clock.rightLabelOverride ?? "")
    }

    private func resetState() {
        searchText = ""
        loadDraft()
    }

    private func loadDraft() {
        draftTimezoneId = clock.leftTimezone.identifier
        draftSecondaryLabel = clock.leftLabelOverride ?? ""
        draftPrimaryLabel = clock.rightLabelOverride ?? ""
    }

    private func applyDraft() {
        if let id = draftTimezoneId, let tz = TimeZone(identifier: id), tz.identifier != clock.leftTimezone.identifier {
            clock.leftTimezone = tz
        }
        let trimmedSecondary = draftSecondaryLabel.trimmingCharacters(in: .whitespaces)
        let newSecondary: String? = trimmedSecondary.isEmpty ? nil : trimmedSecondary
        if newSecondary != clock.leftLabelOverride {
            clock.leftLabelOverride = newSecondary
        }
        let trimmedPrimary = draftPrimaryLabel.trimmingCharacters(in: .whitespaces)
        let newPrimary: String? = trimmedPrimary.isEmpty ? nil : trimmedPrimary
        if newPrimary != clock.rightLabelOverride {
            clock.rightLabelOverride = newPrimary
        }
    }

    private func applyAndClose() {
        applyDraft()
        closeWindow()
    }

    private func closeWindow() {
        clearState()
        NSApp.keyWindow?.close()
    }

    private func clearState() {
        searchText = ""
        draftTimezoneId = nil
        draftSecondaryLabel = ""
        draftPrimaryLabel = ""
    }
}

#Preview {
    SettingsView(clock: ClockModel())
}
