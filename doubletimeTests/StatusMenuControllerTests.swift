//
//  StatusMenuControllerTests.swift
//  doubletimeTests
//

import AppKit
import Testing
@testable import doubletime

/// Records which of StatusMenuController's four callbacks fired, so each test
/// can assert exactly the one it triggered.
@MainActor
private final class MenuCallbackFlags {
    var opened = false
    var closed = false
    var settingsSelected = false
    var quitSelected = false
}

@MainActor
private func makeController(clock: ClockModel, flags: MenuCallbackFlags) -> StatusMenuController {
    StatusMenuController(
        clock: clock,
        onOpen: { flags.opened = true },
        onClose: { flags.closed = true },
        onSettings: { flags.settingsSelected = true },
        onQuit: { flags.quitSelected = true }
    )
}

struct StatusMenuControllerTests {
    private let scratch = ScratchDefaults()

    /// Pins the menu's item structure against what `init` actually builds:
    /// two disabled custom-view rows, a separator, then the standard
    /// Settings/Quit items with their key equivalents.
    @Test @MainActor func menuStructureMatchesTheSourceLayout() throws {
        let clock = scratch.makeClock()
        let controller = makeController(clock: clock, flags: MenuCallbackFlags())

        #expect(controller.menu.items.count == 5)

        #expect(controller.menu.items[0].view != nil)
        #expect(controller.menu.items[0].isEnabled == false)
        #expect(controller.menu.items[1].view != nil)
        #expect(controller.menu.items[1].isEnabled == false)

        #expect(controller.menu.items[2].isSeparatorItem)

        #expect(controller.menu.items[3].title == "Settings…")
        #expect(controller.menu.items[3].keyEquivalent == ",")
        #expect(controller.menu.items[4].title == "Quit Doubletime")
        #expect(controller.menu.items[4].keyEquivalent == "q")
    }

    /// `menuWillOpen` re-reads the clock into both rows and calls
    /// `sizeRows()`, which measures + pins both row hosting views to the
    /// wider of the two `fittingSize`s (lines 105–121). Headless
    /// `layoutSubtreeIfNeeded()` still resolves AppKit auto layout, so the
    /// resulting frames should be nonzero and equal-width.
    @Test @MainActor func menuWillOpenFiresOnOpenAndSizesRowsToEqualNonzeroWidth() throws {
        let clock = scratch.makeClock()
        let flags = MenuCallbackFlags()
        let controller = makeController(clock: clock, flags: flags)

        controller.menuWillOpen(controller.menu)
        #expect(flags.opened)

        let rowViews = controller.menu.items.prefix(2).compactMap(\.view)
        #expect(rowViews.count == 2)
        for view in rowViews {
            #expect(view.frame.width > 0)
            #expect(view.frame.height > 0)
        }
        #expect(rowViews[0].frame.width == rowViews[1].frame.width)
    }

    @Test @MainActor func menuDidCloseFiresOnClose() throws {
        let clock = scratch.makeClock()
        let flags = MenuCallbackFlags()
        let controller = makeController(clock: clock, flags: flags)

        controller.menuDidClose(controller.menu)
        #expect(flags.closed)
    }

    /// Drives the Settings item's real target/action through AppKit's own
    /// dispatch (`NSObject.perform(_:with:)`), the same mechanism a real
    /// click uses, rather than calling a private method directly.
    @Test @MainActor func settingsMenuItemInvokesOnSettings() throws {
        let clock = scratch.makeClock()
        let flags = MenuCallbackFlags()
        let controller = makeController(clock: clock, flags: flags)

        let item = controller.menu.items[3]
        let target = try #require(item.target as? NSObject)
        let action = try #require(item.action)
        _ = target.perform(action, with: item)

        #expect(flags.settingsSelected)
        #expect(!flags.quitSelected)
    }

    @Test @MainActor func quitMenuItemInvokesOnQuit() throws {
        let clock = scratch.makeClock()
        let flags = MenuCallbackFlags()
        let controller = makeController(clock: clock, flags: flags)

        let item = controller.menu.items[4]
        let target = try #require(item.target as? NSObject)
        let action = try #require(item.action)
        _ = target.perform(action, with: item)

        #expect(flags.quitSelected)
        #expect(!flags.settingsSelected)
    }
}
