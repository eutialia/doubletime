//
//  ZoneRowControl.swift
//  doubletime
//

import SwiftUI

/// The control cluster for a city row: a dropdown-styled button that opens the
/// zone-picker popover, a monospaced code field (the override, or the derived
/// default), and the faint word "label". All edits commit to ClockModel
/// immediately (the real menu bar is the live preview).
struct ZoneRowControl: View {
    @Bindable var clock: ClockModel
    let isPrimary: Bool

    @State private var showPicker = false

    private var timezone: TimeZone { isPrimary ? clock.primaryTimezone : clock.secondaryTimezone }
    private var override: String? { isPrimary ? clock.primaryLabelOverride : clock.secondaryLabelOverride }
    // A settings surface, not the live glyph — `.now` is fine for the derived code.
    private var resolvedCode: String {
        isPrimary ? clock.primaryLabel(at: .now) : clock.secondaryLabel(at: .now)
    }

    private var dropdownTitle: String {
        let code = resolvedCode
        if isPrimary && clock.primaryIsSystem {
            return "System (\(code))"
        }
        return "\(ClockModel.cityName(from: timezone)) (\(code))"
    }

    var body: some View {
        HStack(spacing: 8) {
            dropdownButton
            codeField
            Text("label")
                .font(DesignTokens.settingsCaption)
                .foregroundStyle(DesignTokens.textFaint)
        }
    }

    private var dropdownButton: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 6) {
                Text(dropdownTitle)
                    .font(DesignTokens.settingsBody.weight(.medium))
                    .foregroundStyle(DesignTokens.textStrong)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DesignTokens.textMuted)
            }
            .padding(.horizontal, 10)
            .frame(width: 210, height: 26)
            .background(fieldChrome)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            TimezoneSearchList(
                referenceTimezone: isPrimary ? clock.secondaryTimezone : clock.primaryTimezone,
                includeSystemRow: isPrimary,
                currentIdentifier: isPrimary ? clock.primaryTimezoneIdentifier : clock.secondaryTimezone.identifier
            ) { identifier in
                commitZone(identifier)
                showPicker = false
            }
        }
    }

    private var codeField: some View {
        TextField("", text: codeBinding)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(DesignTokens.settingsMono.weight(.medium))
            .foregroundStyle(DesignTokens.textStrong)
            .frame(width: 58, height: 26)
            .background(fieldChrome)
            .accessibilityLabel(isPrimary ? "Primary zone code" : "Secondary zone code")
    }

    private var fieldChrome: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(DesignTokens.fieldBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DesignTokens.fieldBorder, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    }

    private var codeBinding: Binding<String> {
        Binding(
            get: { resolvedCode.uppercased() },
            set: { setOverride(sanitize($0)) }
        )
    }

    /// Uppercase, strip to A–Z0–9, cap at 5 characters — the shared clamp.
    private func sanitize(_ raw: String) -> String? {
        ClockModel.sanitizedLabel(raw)
    }

    private func setOverride(_ value: String?) {
        if isPrimary { clock.primaryLabelOverride = value }
        else { clock.secondaryLabelOverride = value }
    }

    /// Changing the city clears the label override (the field then shows the new
    /// zone's derived code). nil identifier ⇒ the system zone (primary only).
    private func commitZone(_ identifier: String?) {
        if isPrimary {
            if clock.primaryTimezoneIdentifier != identifier {
                clock.primaryTimezoneIdentifier = identifier
                clock.primaryLabelOverride = nil
            }
        } else if let identifier, let tz = TimeZone(identifier: identifier),
                  tz.identifier != clock.secondaryTimezone.identifier {
            clock.secondaryTimezone = tz
            clock.secondaryLabelOverride = nil
        }
    }
}
