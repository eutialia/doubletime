//
//  LoginItemModel.swift
//  doubletime
//

import Observation
import ServiceManagement

/// Everything the launch-at-login toggle needs from the system, behind a
/// protocol. `SMAppService.mainApp` is a process-wide singleton whose calls
/// mutate the user's real Login Items and open System Settings, so the model's
/// logic is only exercisable when that dependency can be swapped for a stub.
@MainActor
protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    /// Deep-links to System Settings → General → Login Items, where the user
    /// re-approves the item after disabling it there (`.requiresApproval`).
    func openSystemSettings()
}

/// The production conformance: this app bundle's own login-item registration.
/// `nonisolated` because `SMAppService` needs no actor of its own — and because
/// the model's default argument constructs one, which the compiler evaluates in
/// the caller's (unknown) isolation.
nonisolated struct SystemLoginItemService: LoginItemService {
    var status: SMAppService.Status { SMAppService.mainApp.status }

    /// Debug builds never register: a DerivedData copy that registers itself
    /// becomes the copy macOS launches at login, then goes `.notFound` when
    /// Xcode purges DerivedData. The guard sits here, at the system boundary,
    /// rather than inside the model — so the model's logic is one code path in
    /// every configuration, and nothing but this wrapper can touch Login Items.
    func register() throws {
        #if !DEBUG
        try SMAppService.mainApp.register()
        #endif
    }

    func unregister() throws {
        #if !DEBUG
        try SMAppService.mainApp.unregister()
        #endif
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// Drives the launch-at-login toggle. The system's registration status is the
/// sole source of truth — there is no stored preference. The user can flip the
/// item in System Settings → General → Login Items at any time without the app
/// being told, so callers re-run `refresh()` whenever the pane appears or the
/// app becomes active.
@MainActor
@Observable
final class LoginItemModel {
    private(set) var status: SMAppService.Status = .notRegistered

    /// Debug builds cannot register — see `SystemLoginItemService.register()`.
    /// Compile-time, so the UI disables the toggle outright instead of letting
    /// it be flipped into a no-op.
    #if DEBUG
    static let canRegister = false
    #else
    static let canRegister = true
    #endif

    private let service: any LoginItemService

    init(service: any LoginItemService = SystemLoginItemService()) {
        self.service = service
        refresh()
    }

    func refresh() {
        status = service.status
    }

    var isEnabled: Bool {
        get { status == .enabled }
        set {
            do {
                if newValue {
                    try service.register()
                } else {
                    try service.unregister()
                }
            } catch {
                // Fall through: refresh() snaps the toggle back to the
                // system's actual state.
            }
            refresh()
        }
    }

    func openSystemSettings() {
        service.openSystemSettings()
    }
}
