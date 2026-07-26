//
//  LoginItemModelTests.swift
//  doubletimeTests
//

import ServiceManagement
import Testing
@testable import doubletime

/// A stand-in for `SMAppService.mainApp`: records every call and lets a test
/// set the status the model will read back. Explicitly `@MainActor` because
/// `LoginItemService` is main-actor isolated and this target does not default
/// to MainActor isolation.
@MainActor
final class MockLoginItemService: LoginItemService {
    /// The system's answer, settable so a test can simulate the user flipping
    /// the item in System Settings behind the app's back.
    var status: SMAppService.Status = .notRegistered
    /// When set, register()/unregister() throw it instead of changing status —
    /// the "System Settings refused" case.
    var failure: (any Error)?

    private(set) var registerCount = 0
    private(set) var unregisterCount = 0
    private(set) var openSystemSettingsCount = 0

    func register() throws {
        registerCount += 1
        if let failure { throw failure }
        status = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        if let failure { throw failure }
        status = .notRegistered
    }

    func openSystemSettings() {
        openSystemSettingsCount += 1
    }
}

private struct RegistrationRefused: Error {}

@MainActor
struct LoginItemModelTests {
    // MARK: Reading the system's state

    /// The model has no stored preference — it must adopt whatever the service
    /// reports at construction time.
    @Test(arguments: [
        SMAppService.Status.enabled,
        .notRegistered,
        .requiresApproval,
        .notFound,
    ])
    func initAdoptsTheServiceStatus(status: SMAppService.Status) {
        let service = MockLoginItemService()
        service.status = status
        let model = LoginItemModel(service: service)
        #expect(model.status == service.status)
        #expect(model.isEnabled == (service.status == .enabled))
    }

    /// Login Items can be flipped in System Settings without the app being
    /// told, so refresh() — not any cached value — is what re-syncs the toggle.
    @Test func refreshPicksUpAnOutOfBandChange() {
        let service = MockLoginItemService()
        let model = LoginItemModel(service: service)
        #expect(!model.isEnabled)

        service.status = .enabled
        #expect(model.status != service.status, "the model must not observe the service; only refresh() re-reads it")

        model.refresh()
        #expect(model.status == service.status)
        #expect(model.isEnabled)
    }

    // MARK: Toggling

    @Test func enablingRegistersAndReSyncs() {
        let service = MockLoginItemService()
        let model = LoginItemModel(service: service)

        model.isEnabled = true

        #expect(service.registerCount == 1)
        #expect(service.unregisterCount == 0)
        #expect(model.status == service.status)
        #expect(model.isEnabled == (service.status == .enabled))
        #expect(model.isEnabled)
    }

    @Test func disablingUnregistersAndReSyncs() {
        let service = MockLoginItemService()
        service.status = .enabled
        let model = LoginItemModel(service: service)

        model.isEnabled = false

        #expect(service.unregisterCount == 1)
        #expect(service.registerCount == 0)
        #expect(model.status == service.status)
        #expect(!model.isEnabled)
    }

    /// Setting the toggle to the value it already has still goes through the
    /// service: SwiftUI writes the binding on every flip, and the round-trip
    /// through refresh() is what keeps the UI honest.
    @Test func settingTheCurrentValueStillCallsTheService() {
        let service = MockLoginItemService()
        service.status = .enabled
        let model = LoginItemModel(service: service)

        model.isEnabled = true

        #expect(service.registerCount == 1)
        #expect(model.isEnabled)
    }

    // MARK: Failures

    /// A throwing service must not propagate or crash — the toggle snaps back
    /// to the system's actual state instead.
    @Test(arguments: [
        (true, SMAppService.Status.requiresApproval),  // register() refused ⇒ stays off
        (false, SMAppService.Status.enabled),          // unregister() refused ⇒ stays on
    ])
    func aThrowingServiceLeavesTheModelInSyncWithTheSystem(newValue: Bool, status: SMAppService.Status) {
        let service = MockLoginItemService()
        service.status = status
        let model = LoginItemModel(service: service)
        service.failure = RegistrationRefused()

        model.isEnabled = newValue

        #expect(service.registerCount + service.unregisterCount == 1, "the attempt still reaches the service")
        // The failed call left the status untouched, and refresh() re-read it.
        #expect(model.status == service.status)
        #expect(model.isEnabled == (service.status == .enabled))
        #expect(model.isEnabled != newValue, "the toggle must not stick at a value the system rejected")
    }

    // MARK: Escape hatch

    @Test func openSystemSettingsForwardsToTheService() {
        let service = MockLoginItemService()
        let model = LoginItemModel(service: service)
        #expect(service.openSystemSettingsCount == 0)

        model.openSystemSettings()

        #expect(service.openSystemSettingsCount == 1)
        // Purely a deep link: it must not disturb the registration state.
        #expect(service.registerCount == 0)
        #expect(service.unregisterCount == 0)
    }

    /// Debug builds cannot register (a DerivedData copy would become the copy
    /// macOS launches), so the UI disables the toggle outright. The flag is a
    /// compile-time constant, so the expectation has to flip with the
    /// configuration — pinning `false` unconditionally would fail a Release
    /// test run for a perfectly correct build.
    @Test func canRegisterFollowsTheBuildConfiguration() {
        #if DEBUG
        #expect(LoginItemModel.canRegister == false)
        #else
        #expect(LoginItemModel.canRegister == true)
        #endif
    }
}
