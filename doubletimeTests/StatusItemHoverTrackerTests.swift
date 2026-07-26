//
//  StatusItemHoverTrackerTests.swift
//  doubletimeTests
//

import AppKit
import Testing
@testable import doubletime

/// Records every hover report the tracker makes, in order — the tracker's only
/// output is that callback, so the sequence is the behaviour under test.
private final class HoverLog {
    private(set) var states: [Bool] = []
    var last: Bool? { states.last }

    func append(_ state: Bool) {
        states.append(state)
    }
}

/// A settable stand-in for `NSEvent.mouseLocation`: a test can neither place
/// nor read the real cursor, so sync()'s hit-test is driven through this seam.
private final class PointerStub {
    var location: NSPoint = .zero
}

/// `.serialized` because two of these tests post PROCESS-GLOBAL notifications
/// (`didChangeScreenParameters`, `activeSpaceDidChange`) that every live
/// tracker observes. They are async, so without it they can interleave at their
/// `Task.sleep` points and each one's post drives the other's tracker — the
/// assertions would still hold, but for the wrong reason.
@MainActor
@Suite(.serialized)
struct StatusItemHoverTrackerTests {
    /// A borderless window is constructible headlessly and never ordered in,
    /// so its content coordinates are stable: with no title bar the content
    /// rect IS the frame, and screen point == window origin + view point.
    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 120, height: 40),
            styleMask: .borderless, backing: .buffered, defer: true
        )
    }

    private func makeEvent(_ type: NSEvent.EventType) throws -> NSEvent {
        try #require(NSEvent.enterExitEvent(
            with: type, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil
        ))
    }

    // MARK: Tracking-area events

    /// The tracking area messages the tracker through the NSResponder
    /// selectors; each one must surface as a hover report.
    @Test func enterAndExitEventsReportHover() throws {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 24, height: 22))
        let log = HoverLog()
        let tracker = StatusItemHoverTracker(view: view, pointerLocation: { .zero }) { log.append($0) }
        // init syncs immediately, and a view in no window cannot be hovered.
        #expect(log.states == [false])

        tracker.mouseEntered(with: try makeEvent(.mouseEntered))
        #expect(log.last == true)

        tracker.mouseExited(with: try makeEvent(.mouseExited))
        #expect(log.states == [false, true, false])
    }

    @Test func theTrackingAreaIsInstalledOnTheView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 24, height: 22))
        let tracker = StatusItemHoverTracker(view: view, pointerLocation: { .zero }) { _ in }
        let area = view.trackingAreas.first

        #expect(view.trackingAreas.count == 1)
        #expect(area?.owner as? StatusItemHoverTracker === tracker)
        // .activeAlways: hover has to fire while another app is frontmost, the
        // normal state for a menu bar app. .inVisibleRect: the area follows the
        // button's frame, so width changes need no re-registration.
        #expect(area?.options.contains(.activeAlways) == true)
        #expect(area?.options.contains(.inVisibleRect) == true)
        #expect(area?.options.contains(.mouseEnteredAndExited) == true)
    }

    // MARK: sync()

    /// No window ⇒ nothing to hit-test against, so hover is off — never left
    /// stuck at its previous value.
    @Test func syncReportsNoHoverWhenTheViewHasNoWindow() throws {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 24, height: 22))
        let log = HoverLog()
        let tracker = StatusItemHoverTracker(view: view, pointerLocation: { NSPoint(x: 10, y: 10) }) {
            log.append($0)
        }
        tracker.mouseEntered(with: try makeEvent(.mouseEntered))

        tracker.sync()

        #expect(log.last == false)
        #expect(log.states == [false, true, false])
    }

    /// The whole point of sync(): recompute hover from the pointer's actual
    /// position when AppKit skipped an enter/exit event.
    @Test func syncHitTestsTheLivePointerAgainstTheView() {
        let window = makeWindow()
        let view = NSView(frame: NSRect(x: 10, y: 8, width: 24, height: 22))
        window.contentView?.addSubview(view)
        let pointer = PointerStub()
        let log = HoverLog()
        // The view's center in screen coordinates: (200 + 10 + 12, 200 + 8 + 11).
        pointer.location = NSPoint(x: 222, y: 219)

        let tracker = StatusItemHoverTracker(view: view, pointerLocation: { pointer.location }) {
            log.append($0)
        }
        #expect(log.last == true, "the pointer already sits on the item at construction")

        // Inside the window but outside the view's own frame.
        pointer.location = NSPoint(x: 205, y: 205)
        tracker.sync()
        #expect(log.last == false)

        // Off the window entirely.
        pointer.location = NSPoint(x: 4000, y: 4000)
        tracker.sync()
        #expect(log.last == false)

        pointer.location = NSPoint(x: 222, y: 219)
        tracker.sync()
        #expect(log.last == true)
    }

    // MARK: Notification-driven re-sync

    /// Display reconfiguration can reparent the status window without any
    /// geometric exit, so the tracker re-syncs on the screen-parameters
    /// notification — otherwise hover sticks on.
    @Test func screenParameterChangesForceAReSync() async throws {
        let window = makeWindow()
        let view = NSView(frame: NSRect(x: 10, y: 8, width: 24, height: 22))
        window.contentView?.addSubview(view)
        let pointer = PointerStub()
        let log = HoverLog()
        pointer.location = NSPoint(x: 222, y: 219)
        let tracker = StatusItemHoverTracker(view: view, pointerLocation: { pointer.location }) {
            log.append($0)
        }
        #expect(log.last == true)

        pointer.location = NSPoint(x: 4000, y: 4000)
        NotificationCenter.default.post(
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )

        try await waitForReports(log, atLeast: 2)
        #expect(log.last == false)
        withExtendedLifetime(tracker) {}
    }

    /// Same contract for a Space switch, which can also strand the flag on.
    @Test func spaceChangesForceAReSync() async throws {
        let window = makeWindow()
        let view = NSView(frame: NSRect(x: 10, y: 8, width: 24, height: 22))
        window.contentView?.addSubview(view)
        let pointer = PointerStub()
        let log = HoverLog()
        pointer.location = NSPoint(x: 222, y: 219)
        let tracker = StatusItemHoverTracker(view: view, pointerLocation: { pointer.location }) {
            log.append($0)
        }
        #expect(log.last == true)

        pointer.location = NSPoint(x: 4000, y: 4000)
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil
        )

        try await waitForReports(log, atLeast: 2)
        #expect(log.last == false)
        withExtendedLifetime(tracker) {}
    }

    /// The observers are registered with `queue: .main`, which may deliver
    /// after the post returns — poll rather than assume, and let the caller's
    /// #expect report the miss if it never lands.
    private func waitForReports(_ log: HoverLog, atLeast count: Int) async throws {
        for _ in 0..<200 where log.states.count < count {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(log.states.count >= count, "the notification never triggered a re-sync")
    }

    /// The tracking area does not retain its owner, so a freed tracker must
    /// take the area with it — a stale area would message a dangling owner on
    /// the next enter/exit.
    @Test func deinitRemovesTheTrackingArea() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 24, height: 22))
        do {
            let tracker = StatusItemHoverTracker(view: view, pointerLocation: { .zero }) { _ in }
            #expect(view.trackingAreas.count == 1)
            withExtendedLifetime(tracker) {}
        }
        #expect(view.trackingAreas.isEmpty)
    }
}
