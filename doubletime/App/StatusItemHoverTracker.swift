//
//  StatusItemHoverTracker.swift
//  doubletime
//

import AppKit

/// Owns an NSTrackingArea on the status item's button and reports pointer
/// enter/exit. The AppKit quirks this class absorbs:
/// - .activeAlways: hover must fire while some OTHER app is frontmost (the
///   normal state for a menu bar app); .activeInActiveApp would go silent.
/// - .inVisibleRect: the area follows the button's own frame, so the width
///   changes pushed from Settings edits need no manual re-registration.
/// - AppKit guarantees neither enter/exit ordering nor a mouseExited when the
///   item's menu captures the pointer, so the owner can force a re-sync from
///   the live pointer position via sync() (see AppDelegate's NSMenuDelegate).
/// - Space switches and display reconfiguration can reparent the status
///   window without a geometric mouse exit, so activeSpaceDidChange and
///   didChangeScreenParameters also force a sync() — otherwise hover can get
///   stuck on after either event.
///
/// NSResponder (not NSObject) so mouseEntered/mouseExited are real overrides —
/// the tracking area messages its owner through these NSResponder selectors.
@MainActor
final class StatusItemHoverTracker: NSResponder {
    private weak var view: NSView?
    private let onChange: (Bool) -> Void
    private var spaceObserver: (any NSObjectProtocol)?
    private var screenParametersObserver: (any NSObjectProtocol)?

    init(view: NSView, onChange: @escaping (Bool) -> Void) {
        self.view = view
        self.onChange = onChange
        super.init()
        view.addTrackingArea(NSTrackingArea(
            rect: .zero, // ignored with .inVisibleRect
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))

        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // `.main` guarantees this runs on the main thread ⇒ MainActor.
            MainActor.assumeIsolated { self?.sync() }
        }
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        }

        // Covers the pointer already sitting on the item at launch — no enter
        // event ever fires for that case.
        sync()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StatusItemHoverTracker does not support NSCoding")
    }

    deinit {
        if let spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver)
        }
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
        }
    }

    /// Recompute hover from the live pointer position — the defensive path for
    /// the cases where AppKit skips an enter/exit event entirely.
    func sync() {
        guard let view, let window = view.window else {
            onChange(false)
            return
        }
        let point = view.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        onChange(view.bounds.contains(point))
    }

    override func mouseEntered(with event: NSEvent) {
        onChange(true)
    }

    override func mouseExited(with event: NSEvent) {
        onChange(false)
    }
}
