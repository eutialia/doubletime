//
//  LoginItemModel.swift
//  doubletime
//

import Observation
import ServiceManagement

/// Wraps `SMAppService.mainApp` for the launch-at-login toggle. The system's
/// registration status is the sole source of truth — there is no stored
/// preference. The user can flip the item in System Settings → General →
/// Login Items at any time without the app being told, so callers re-run
/// `refresh()` whenever the pane appears or the app becomes active.
@MainActor
@Observable
final class LoginItemModel {
    private(set) var status: SMAppService.Status = .notRegistered

    /// Debug builds never register: a DerivedData copy that registers itself
    /// becomes the copy macOS launches at login, then goes `.notFound` when
    /// Xcode purges DerivedData.
    #if DEBUG
    static let canRegister = false
    #else
    static let canRegister = true
    #endif

    init() {
        refresh()
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    var isEnabled: Bool {
        get { status == .enabled }
        set {
            #if !DEBUG
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Fall through: refresh() snaps the toggle back to the
                // system's actual state.
            }
            #endif
            refresh()
        }
    }

    /// Deep-links to System Settings → General → Login Items, where the user
    /// re-approves the item after disabling it there (`.requiresApproval`).
    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
