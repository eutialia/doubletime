# Hover: Secondary-Minute Flip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** While the pointer hovers the menubar status item and the two zones differ by a non-whole-hour offset, the trailing `:mm` flips (flip-clock style, on a chip-fill card) from the primary zone's minute to the secondary zone's minute; it flips back on exit.

**Architecture:** A transient `statusItemHovered` flag on `ClockModel` (observable, never persisted), set by an AppKit `NSTrackingArea` on the status item's button and force-synced around the menu's lifetime. The flag flows into `TimeGlyph` as a new parameter; `TimeGlyph` gates it on the existing sweep predicate (`fraction > 0`) and selects which zone's minute `TrailingMinute` shows. `TrailingMinute` renders the swap as a two-face flip transition with a persistent chip-fill card as the "you're reading the other zone" cue. Settings `OptionCard` exemplars get the same swap via `.onHover` (instant — the raster is a still photograph).

**Tech Stack:** Swift 6, SwiftUI (`@Observable`, transitions, `ImageRenderer`), AppKit (`NSTrackingArea`, `NSMenuDelegate`), Swift Testing.

## Global Constraints

- **Width-neutral, always:** hover must NEVER change the glyph's layout size or `statusItem.length`. The card is drawn as a `.background` (visual outset only).
- All new visual constants live in `DesignTokens` — no hardcoded values inside glyph views.
- The whole-hour case is a complete no-op: gate on `sweep.fraction > 0`, the exact predicate that draws the arc/segments.
- Hover state is session-only: a plain observable property, **no** `didSet → UserDefaults` (pattern: `systemZoneGeneration`, `ClockModel.swift:113`).
- Tracking options are exactly `[.mouseEnteredAndExited, .activeAlways, .inVisibleRect]` — `.activeAlways` is required (hover must fire while another app is frontmost).
- Respect Reduce Motion: crossfade instead of flip.
- Keep the blinking-colon per-second `TimelineView` scoped to the colon only (do not widen it).
- Match existing code style: comment density explains constraints/why, `@MainActor` + Swift 6 isolation patterns as in `ClockModel`/`AppDelegate`.
- Git: work on branch `feat/hover-secondary-minute`, conventional commits, PR to `main` (rebase merge). NEVER commit to `main`.
- Xcode project uses synchronized folder groups — new files on disk join the build automatically; no `project.pbxproj` edits.
- Build check: `xcodebuild build -project doubletime.xcodeproj -scheme doubletime -destination 'platform=macOS,arch=arm64'` (this project's type-check equivalent; no eslint/tsc here).
- Test run: `xcodebuild test -project doubletime.xcodeproj -scheme doubletime -destination 'platform=macOS,arch=arm64'`.

---

### Task 1: Rendering — hovered state through TimeGlyph and the TrailingMinute flip card

**Files:**
- Modify: `doubletime/DesignSystem/DesignTokens.swift` (two new tokens, after `trailingMinuteLeadingOffset` at :57)
- Modify: `doubletime/Glyph/TimeGlyph.swift`
- Modify: `doubletime/Glyph/TrailingMinute.swift`
- Test: `doubletimeTests/doubletimeTests.swift`

**Interfaces:**
- Consumes: `ClockModel.minute(for:at:)`, `ClockModel.anchoredSweep(secondary:primary:at:)`, `DesignTokens.chipFill(isPrimary:period:colorScheme:)` (all existing).
- Produces: `TimeGlyph` gains `var hovered: Bool = false` (memberwise position: after `blinkColon`). `TrailingMinute` gains `var carded: Bool = false` and `var cardPeriod: ClockModel.Period? = nil`. Tokens `DesignTokens.minuteCardOutset: CGFloat` and `DesignTokens.minuteFlipDuration: Double`. Later tasks rely on `TimeGlyph(..., hovered:)` exactly.

- [ ] **Step 1: Create the branch**

```bash
git checkout -b feat/hover-secondary-minute
```

- [ ] **Step 2: Write the failing tests**

Append inside `struct doubletimeTests` (after `offsetMinutesSign`, around line 200):

```swift
    // MARK: Minute digits

    @Test func minuteRendersZoneWallClock() {
        // 12:00 UTC → Kathmandu (UTC+5:45) 17:45, Kolkata (UTC+5:30) 17:30,
        // Los Angeles (PDT) 05:00.
        #expect(ClockModel.minute(for: timezone("Asia/Kathmandu"), at: Self.reference) == "45")
        #expect(ClockModel.minute(for: timezone("Asia/Kolkata"), at: Self.reference) == "30")
        #expect(ClockModel.minute(for: timezone("America/Los_Angeles"), at: Self.reference) == "00")
    }

    // MARK: Hover (secondary-minute swap)

    /// A quarter-hour pair (Kathmandu +5:45 over PDT) so BOTH minute digits
    /// differ between the zones — the strongest swap exercise.
    private func hoverGlyph(hovered: Bool, secondaryId: String = "Asia/Kathmandu") -> some View {
        TimeGlyph(
            secondaryLabel: "KAT", secondaryTimezone: timezone(secondaryId),
            primaryLabel: "PDT", primaryTimezone: timezone("America/Los_Angeles"),
            now: Self.reference, variant: .arc, hovered: hovered
        )
    }

    /// Hover must swap the trailing minute (pixels change) WITHOUT changing
    /// the rendered footprint — the status item length must never move.
    @Test @MainActor func hoverSwapsMinuteWidthNeutrally() throws {
        func render(hovered: Bool) throws -> NSImage {
            let renderer = ImageRenderer(content: hoverGlyph(hovered: hovered).statusItemStrip())
            renderer.scale = 4
            return try #require(renderer.nsImage)
        }
        let plain = try render(hovered: false)
        let hovered = try render(hovered: true)
        #expect(plain.tiffRepresentation != hovered.tiffRepresentation)
        #expect(plain.size == hovered.size)
    }

    /// A whole-hour pair draws no indicator, and hover must be a complete
    /// no-op — pixel-identical output.
    @Test @MainActor func hoverIsNoOpForWholeHourPair() throws {
        func render(hovered: Bool) throws -> Data? {
            let renderer = ImageRenderer(
                content: hoverGlyph(hovered: hovered, secondaryId: "Asia/Tokyo").statusItemStrip()
            )
            renderer.scale = 4
            return try #require(renderer.nsImage).tiffRepresentation
        }
        #expect(try render(hovered: false) == render(hovered: true))
    }

    /// The hovered card obeys the same zero-overflow rule as the rest of the
    /// ensemble inside the fixed 22pt strip (macOS clips status items).
    @Test @MainActor func hoveredEnsembleFitsInsideStatusStrip() throws {
        let scan = try RasterScan(of: hoverGlyph(hovered: true).statusItemStrip())

        func rowHasInk(_ y: Int) -> Bool {
            (0..<scan.width).contains { scan.isInk($0, y) }
        }

        let firstInkRow = try #require((0..<scan.height).first(where: rowHasInk))
        let lastInkRow = try #require((0..<scan.height).reversed().first(where: rowHasInk))
        #expect(firstInkRow > 0, "hovered ink clips at the status button top")
        #expect(lastInkRow < scan.height - 1, "hovered ink clips at the status button bottom")
    }
```

Note: `NSImage` needs no new import (`SwiftUI` is already imported and re-exports what's needed; `Foundation` covers `Data`).

- [ ] **Step 3: Run tests to verify they fail**

Run: `xcodebuild test -project doubletime.xcodeproj -scheme doubletime -destination 'platform=macOS,arch=arm64' -only-testing:doubletimeTests 2>&1 | tail -20`

Expected: **build failure** — `TimeGlyph` has no `hovered` parameter ("extra argument 'hovered' in call"). That is this cycle's red state (`minuteRendersZoneWallClock` alone would pass, but the file must compile as a unit).

- [ ] **Step 4: Add the two design tokens**

In `doubletime/DesignSystem/DesignTokens.swift`, directly after `trailingMinuteLeadingOffset` (line 57):

```swift
    /// Horizontal outset of the hovered minute's card past the `:mm` text box.
    /// The card is drawn as a background (never layout) so the glyph width —
    /// and therefore the status item length — cannot change on hover.
    static let minuteCardOutset: CGFloat = 1.5
    /// Full duration of the trailing-minute flip (the two half-turns overlap,
    /// meeting edge-on at the midpoint).
    static let minuteFlipDuration: Double = 0.3
```

- [ ] **Step 5: Rewrite TrailingMinute with the card + flip transition**

Replace the entire body of `doubletime/Glyph/TrailingMinute.swift` with:

```swift
//
//  TrailingMinute.swift
//  doubletime
//

import SwiftUI

/// The trailing `:mm` — the PRIMARY minute, except while the status item is
/// hovered over a sub-hour pair (`carded`), when it flips, flip-clock style, to
/// the SECONDARY minute riding on a chip-fill card. The card persists for the
/// whole hover: it is the "you're reading the other zone" cue, not just a
/// transition effect. The colon can hide every other second (opt-in blink) at
/// opacity 0 so the glyph width never changes.
struct TrailingMinute: View {
    let minute: String
    var blink: Bool = false
    /// True while showing the secondary minute (draws the card and flips).
    var carded: Bool = false
    /// The secondary zone's period, hue-pairing the card with the secondary
    /// cell in 12-hour mode; nil in 24-hour mode (neutral fill).
    var cardPeriod: ClockModel.Period? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Two identities so the swap runs as a transition: the outgoing
            // face keeps its old minute string while it animates away.
            if carded {
                face.background { card }
                    .transition(reduceMotion ? .opacity : .flip(entering: true))
            } else {
                face
                    .transition(reduceMotion ? .opacity : .flip(entering: false))
            }
        }
        .animation(
            .easeInOut(duration: reduceMotion ? 0.15 : DesignTokens.minuteFlipDuration),
            value: carded
        )
    }

    private var face: some View {
        HStack(spacing: 0) {
            colon
            Text(minute)
        }
        .font(DesignTokens.timeFont)
        .tracking(DesignTokens.timeTracking)
        .foregroundStyle(.primary.opacity(DesignTokens.inkOpacity))
    }

    /// The chip riding under the secondary minute. Drawn as a background so it
    /// never affects layout: it pins to the hour cells' height and outsets past
    /// the text box purely visually. It uses the PRIMARY fill strength (the
    /// secondary tier is too faint to read as a cue) with the SECONDARY
    /// period's hue, visually pairing the card with the cell whose minute it
    /// shows.
    private var card: some View {
        RoundedRectangle(cornerRadius: DesignTokens.cellCornerRadius)
            .fill(DesignTokens.chipFill(isPrimary: true, period: cardPeriod, colorScheme: colorScheme))
            .frame(height: DesignTokens.cellSize.height)
            .padding(.horizontal, -DesignTokens.minuteCardOutset)
    }

    /// When blinking, ONLY the colon runs a per-second timeline (the rest of the
    /// glyph stays on the per-minute tick). It stays laid out at opacity 0 rather
    /// than being removed, so the glyph width never changes.
    @ViewBuilder private var colon: some View {
        if blink {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(":").opacity(ClockModel.colonVisible(at: context.date) ? 1 : 0)
            }
        } else {
            Text(":")
        }
    }
}

/// Rotation about the horizontal axis with slight perspective. Animatable so
/// the transition system can interpolate the angle; the face hides past ~89°
/// so text never renders mirrored mid-flip.
private struct FlipEffect: ViewModifier, Animatable {
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
            .opacity(abs(angle) < 89 ? 1 : 0)
    }
}

extension AnyTransition {
    /// Half of a flip-clock turn. The entering face arrives from −90° → 0
    /// while the exiting face leaves 0 → +90°, meeting edge-on at the
    /// midpoint; reversing the state runs both in reverse, so the flip-back
    /// mirrors the flip-in.
    static func flip(entering: Bool) -> AnyTransition {
        .modifier(
            active: FlipEffect(angle: entering ? -90 : 90),
            identity: FlipEffect(angle: 0)
        )
    }
}
```

- [ ] **Step 6: Thread `hovered` through TimeGlyph**

In `doubletime/Glyph/TimeGlyph.swift`:

Replace the doc comment (lines 8–13) with:

```swift
/// The menu bar glyph: [secondary HourCell][primary HourCell][trailing :mm].
///
/// The trailing `:mm` is the primary minute; while `hovered` over a sub-hour
/// pair it flips to the SECONDARY minute on a chip-fill card (see
/// TrailingMinute) — gated on the same predicate that draws the indicator, so
/// whole-hour pairs make hover a no-op. The primary cell shows no indicator;
/// the secondary cell shows an arc/segmented indicator encoding the signed
/// sub-hour offset between the two zones. In 12-hour mode each cell tints by
/// ITS OWN period (warm amber = AM, cool indigo = PM) and shows hh12 digits.
```

Add the property after `var blinkColon: Bool = false` (line 22):

```swift
    /// Pointer-over state of the status item (or a settings exemplar chip).
    var hovered: Bool = false
```

Replace the `primaryMinute` line (line 28):

```swift
        let primaryMinute = ClockModel.minute(for: primaryTimezone, at: now)
```

with:

```swift
        // Hover swaps the minute to the secondary zone ONLY when the sub-hour
        // indicator is showing — the exact predicate that draws the arc.
        let showsSecondaryMinute = hovered && sweep.fraction > 0
        let minute = ClockModel.minute(
            for: showsSecondaryMinute ? secondaryTimezone : primaryTimezone, at: now
        )
```

Replace the `TrailingMinute` call (line 40):

```swift
            TrailingMinute(minute: minute, blink: blinkColon,
                           carded: showsSecondaryMinute, cardPeriod: secondaryPeriod)
```

Leave the `accessibilityLabel` referencing `primaryMinute` — change that expression to use a dedicated always-primary value. In the same body, the accessibility line (line 47) currently interpolates `primaryMinute`; replace the interpolation with `ClockModel.minute(for: primaryTimezone, at: now)`:

```swift
        .accessibilityLabel(
            "\(secondaryLabel) \(secondaryHour)\(spell(secondaryPeriod)), "
            + "\(primaryLabel) \(primaryHour)\(spell(primaryPeriod)) "
            + ClockModel.minute(for: primaryTimezone, at: now)
        )
```

(Hover is a pointer-only affordance; VoiceOver output stays stable on the primary minute.)

- [ ] **Step 7: Run the tests to verify they pass**

Run: `xcodebuild test -project doubletime.xcodeproj -scheme doubletime -destination 'platform=macOS,arch=arm64' 2>&1 | tail -20`

Expected: **all tests pass**, including the four new ones and every pre-existing test (`statusItemRasterMatchesCanonicalStrip`, `ensembleFitsInsideStatusStrip`, etc. — `hovered` defaults to `false`, so nothing existing changes).

- [ ] **Step 8: Commit**

```bash
git add doubletime/DesignSystem/DesignTokens.swift doubletime/Glyph/TimeGlyph.swift doubletime/Glyph/TrailingMinute.swift doubletimeTests/doubletimeTests.swift
git commit -m "feat(glyph): flip trailing minute to secondary zone while hovered"
```

---

### Task 2: Hover plumbing — model flag, tracking area, menu-lifetime sync

**Files:**
- Create: `doubletime/App/StatusItemHoverTracker.swift`
- Modify: `doubletime/Model/ClockModel.swift` (one property, after `systemZoneGeneration` at :113)
- Modify: `doubletime/App/AppDelegate.swift`
- Modify: `doubletime/App/StatusBarView.swift` (pass the flag)

**Interfaces:**
- Consumes: `TimeGlyph(..., hovered:)` from Task 1.
- Produces: `ClockModel.statusItemHovered: Bool` (observable, not persisted). `StatusItemHoverTracker(view:onChange:)` with `func sync()`. `AppDelegate` conforms to `NSMenuDelegate`.

- [ ] **Step 1: Add the transient model flag**

In `doubletime/Model/ClockModel.swift`, after the `systemZoneGeneration` declaration (line 113), add:

```swift
    /// True while the pointer is over the status item. Transient interaction
    /// state — deliberately NOT persisted (no didSet → UserDefaults): it is
    /// meaningless across launches, like systemZoneGeneration.
    var statusItemHovered = false
```

- [ ] **Step 2: Create the tracker**

Create `doubletime/App/StatusItemHoverTracker.swift`:

```swift
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
///
/// NSResponder (not NSObject) so mouseEntered/mouseExited are real overrides —
/// the tracking area messages its owner through these NSResponder selectors.
@MainActor
final class StatusItemHoverTracker: NSResponder {
    private weak var view: NSView?
    private let onChange: (Bool) -> Void

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
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StatusItemHoverTracker does not support NSCoding")
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
```

- [ ] **Step 3: Wire it in AppDelegate (with temporary instrumentation)**

In `doubletime/App/AppDelegate.swift`:

Add the property after `private var hostingView: NSHostingView<StatusBarView>!` (line 15):

```swift
    private var hoverTracker: StatusItemHoverTracker?
```

In `applicationDidFinishLaunching`, inside the `if let button = statusItem.button` block (after `button.addSubview(hostingView)`, line 37), add:

```swift
            // Hover flips the trailing :mm to the secondary minute (TimeGlyph).
            // Tracked on the button so the whole item, padding included, is the
            // hover surface.
            hoverTracker = StatusItemHoverTracker(view: button) { [weak self] hovering in
                // TEMP-HOVER-DEBUG (remove before PR): ground truth that
                // tracking fires while the app is not frontmost.
                print("hover \(hovering ? "ENTER" : "EXIT") frontmost=\(NSApp.isActive) @ \(Date())")
                self?.clock.statusItemHovered = hovering
            }
```

After `statusItem.menu = menu` (line 48), add:

```swift
        menu.delegate = self
```

At the bottom of the file, add:

```swift
extension AppDelegate: NSMenuDelegate {
    // AppKit guarantees neither a mouseExited when the menu captures the
    // pointer nor a mouseEntered if the pointer is still over the item when
    // the menu closes — force-sync hover around the menu's lifetime.
    func menuWillOpen(_ menu: NSMenu) {
        clock.statusItemHovered = false
    }

    func menuDidClose(_ menu: NSMenu) {
        hoverTracker?.sync()
    }
}
```

- [ ] **Step 4: Pass the flag through StatusBarView**

In `doubletime/App/StatusBarView.swift`, inside `glyph(at:)`, add the argument after `blinkColon: clock.blinkColon` (line 49):

```swift
            blinkColon: clock.blinkColon,
            hovered: clock.statusItemHovered
```

- [ ] **Step 5: Build and run the full test suite**

Run: `xcodebuild test -project doubletime.xcodeproj -scheme doubletime -destination 'platform=macOS,arch=arm64' 2>&1 | tail -10`

Expected: build succeeds, all tests pass (this task adds AppKit plumbing with no renderable-in-test behavior; live behavior is verified at the Task 5 checkpoint with the instrumentation from Step 3).

- [ ] **Step 6: Commit**

```bash
git add doubletime/App/StatusItemHoverTracker.swift doubletime/Model/ClockModel.swift doubletime/App/AppDelegate.swift doubletime/App/StatusBarView.swift
git commit -m "feat(app): track status item hover and feed it to the glyph"
```

---

### Task 3: Settings exemplars — hover-responsive OptionCard chips

**Files:**
- Modify: `doubletime/Settings/OptionCard.swift`

**Interfaces:**
- Consumes: `TimeGlyph(..., hovered:)` from Task 1.
- Produces: no new public interface; `OptionCard`'s two exemplars respond to hover.

- [ ] **Step 1: Replace the `example` helper with a hoverable subview**

In `doubletime/Settings/OptionCard.swift`, replace the two `example(...)` call lines (lines 40–41) with:

```swift
                    GlyphExample(secondary: Self.ist, primary: Self.lax,
                                 caption: "+30 AHEAD · CW", hour12: hour12, variant: variant)
                    GlyphExample(secondary: Self.lax, primary: Self.ist,
                                 caption: "−30 BEHIND · CCW", hour12: hour12, variant: variant)
```

and replace the whole `private func example(secondary:primary:caption:)` (lines 75–94) with:

```swift
    /// One exemplar chip. Hovering swaps the trailing minute to the secondary
    /// zone — the same behavior as the live status item — so the feature is
    /// discoverable from Settings. The chip is a re-rasterized still photograph
    /// per state: the swap is instant here; the flip animation exists only in
    /// the live menu bar.
    private struct GlyphExample: View {
        let secondary: TimeZone
        let primary: TimeZone
        let caption: String
        let hour12: Bool
        let variant: GlyphVariant

        @State private var hovered = false

        var body: some View {
            VStack(spacing: 4) {
                GlyphChip(fixedHeight: 52) {
                    TimeGlyph(
                        secondaryLabel: ClockModel.defaultLabel(for: secondary, at: OptionCard.exemplar),
                        secondaryTimezone: secondary,
                        primaryLabel: ClockModel.defaultLabel(for: primary, at: OptionCard.exemplar),
                        primaryTimezone: primary,
                        now: OptionCard.exemplar,
                        hour12: hour12,
                        variant: variant,
                        hovered: hovered
                    )
                }
                .onHover { hovered = $0 }
                Text(caption)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(DesignTokens.textFaint)
            }
            .frame(maxWidth: .infinity)
        }
    }
```

Also update the `OptionCard` doc comment (lines 8–11) — the examples are no longer "static":

```swift
/// A selectable white card presenting one glyph variant, with a radio dot,
/// title, right-aligned caption, and two glyph examples (a +30 clockwise and a
/// −30 counterclockwise exemplar) that follow the hour-format setting and this
/// card's own variant. Hovering an example swaps its trailing minute to the
/// secondary zone, mirroring the live status item's hover behavior.
```

- [ ] **Step 2: Build + full test suite**

Run: `xcodebuild test -project doubletime.xcodeproj -scheme doubletime -destination 'platform=macOS,arch=arm64' 2>&1 | tail -10`

Expected: build succeeds, all tests pass (exemplar rendering is exercised by `statusItemRasterMatchesCanonicalStrip`).

- [ ] **Step 3: Commit**

```bash
git add doubletime/Settings/OptionCard.swift
git commit -m "feat(settings): hover on glyph exemplars previews the minute swap"
```

---

### Task 4: Gated export — hovered README asset

**Files:**
- Modify: `doubletimeTests/GlyphExport.swift`

**Interfaces:**
- Consumes: `TimeGlyph(..., hovered:)` from Task 1.
- Produces: gated test `exportHoveredMenubarGlyph` writing `menubar-hover.png` alongside the existing `menubar.png`.

- [ ] **Step 1: Refactor the export path and add the hovered asset**

Replace the whole `struct GlyphExport` body in `doubletimeTests/GlyphExport.swift` (keep the header comment block, updating its `cp` line as shown) with:

```swift
///   DIR="$HOME/Library/Containers/com.lhdev.doubletime/Data/tmp"
///   TEST_RUNNER_GLYPH_EXPORT_DIR="$DIR" xcodebuild test \
///     -project doubletime.xcodeproj -scheme doubletime \
///     -destination 'platform=macOS,arch=arm64' \
///     -only-testing:doubletimeTests/GlyphExport \
///   && cp "$DIR/menubar.png" "$DIR/menubar-hover.png" docs/
struct GlyphExport {
    private static let exportDirectory = ProcessInfo.processInfo.environment["GLYPH_EXPORT_DIR"]

    /// The app's default pair at a DST-stable instant: 2026-04-20 12:34 UTC
    /// puts JST at 21 and PDT at 05:34.
    private static let reference: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(
            from: DateComponents(year: 2026, month: 4, day: 20, hour: 12, minute: 34)
        )!
    }()

    /// Composites the canonical strip on black and writes a 6 px/pt PNG (the
    /// README displays at 3× point size: exact pixels for 2× readers, a clean
    /// downsample for 1×).
    @MainActor private func export(_ glyph: some View, as filename: String, to directory: String) throws {
        let card = glyph.statusItemStrip()
            .padding(EdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12))
            .background(.black)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 6
        let image = try #require(renderer.cgImage)
        let png = try #require(
            NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        )
        try png.write(to: URL(filePath: directory).appending(path: filename))
    }

    @Test(.enabled(if: GlyphExport.exportDirectory != nil))
    @MainActor func exportMenubarGlyph() throws {
        let directory = try #require(Self.exportDirectory)
        // The 16-hour JST/PDT offset is whole-hour, so the sub-hour ring
        // intentionally draws nothing here.
        let glyph = TimeGlyph(
            secondaryLabel: "JST", secondaryTimezone: TimeZone(identifier: "Asia/Tokyo")!,
            primaryLabel: "PDT", primaryTimezone: TimeZone(identifier: "America/Los_Angeles")!,
            now: Self.reference, variant: .arc
        )
        try export(glyph, as: "menubar.png", to: directory)
    }

    @Test(.enabled(if: GlyphExport.exportDirectory != nil))
    @MainActor func exportHoveredMenubarGlyph() throws {
        let directory = try #require(Self.exportDirectory)
        // Kathmandu (+5:45) over PDT: a quarter-hour pair, so hover flips
        // :34 → :19 — both digits change, and the card rides under them.
        let glyph = TimeGlyph(
            secondaryLabel: "KAT", secondaryTimezone: TimeZone(identifier: "Asia/Kathmandu")!,
            primaryLabel: "PDT", primaryTimezone: TimeZone(identifier: "America/Los_Angeles")!,
            now: Self.reference, variant: .arc, hovered: true
        )
        try export(glyph, as: "menubar-hover.png", to: directory)
    }
}
```

(The existing header comment above the struct — "Writes the README hero image…" — stays; only the `cp` invocation line changes as shown.)

- [ ] **Step 2: Run the gated export and copy the assets**

```bash
DIR="$HOME/Library/Containers/com.lhdev.doubletime/Data/tmp"
TEST_RUNNER_GLYPH_EXPORT_DIR="$DIR" xcodebuild test \
  -project doubletime.xcodeproj -scheme doubletime \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:doubletimeTests/GlyphExport 2>&1 | tail -5
cp "$DIR/menubar.png" "$DIR/menubar-hover.png" docs/
```

Expected: both tests pass; `docs/menubar-hover.png` exists; `git diff --stat docs/menubar.png` shows **no change** (the unhovered composition is untouched). If `menubar.png` changed, that is a regression — stop and investigate.

- [ ] **Step 3: Visually inspect the hovered asset**

Read `docs/menubar-hover.png` (it is an image) and confirm: the trailing minute reads `:19` (not `:34`), a rounded card sits behind it at hour-cell height, and the ¾ arc is drawn on the secondary cell. If anything is off, fix rendering before proceeding.

- [ ] **Step 4: Commit**

```bash
git add doubletimeTests/GlyphExport.swift docs/menubar-hover.png
git commit -m "test: export hovered status strip as a gated README asset"
```

---

### Task 5: Live verification checkpoint, cleanup, PR

**Files:**
- Modify: `doubletime/App/AppDelegate.swift` (remove instrumentation)

- [ ] **Step 1: Build and launch the instrumented app**

```bash
xcodebuild build -project doubletime.xcodeproj -scheme doubletime -destination 'platform=macOS,arch=arm64' 2>&1 | tail -3
```

Launch the built app from the DerivedData products path (find it via `xcodebuild -showBuildSettings ... | grep BUILT_PRODUCTS_DIR`), running it from a terminal so the TEMP-HOVER-DEBUG prints are visible.

- [ ] **Step 2: USER CHECKPOINT — manual hover script (requires a human mouse)**

Ask the user to run through this script while watching the terminal output:

1. **Sub-hour pair:** Settings → secondary `Asia/Kolkata` (or Kathmandu), primary with a whole-hour difference from it (e.g. System). Hover the menubar item → `:mm` flips to the secondary minute on a card; move off → flips back. Terminal shows `ENTER`/`EXIT` lines.
2. **Not frontmost:** click into another app first, then hover → must still fire (`frontmost=false` in the log).
3. **Whole-hour no-op:** secondary `Asia/Tokyo`, primary `Europe/London`-style whole-hour pair → hover changes nothing.
4. **Menu lifecycle:** hover, then click (menu opens) → card clears; close the menu with the pointer still on the item → card returns (menuDidClose sync).
5. **12-hour mode:** enable it → the card takes the secondary cell's period hue.
6. **Reduce Motion:** System Settings → Accessibility → Display → Reduce motion ON → crossfade, no 3D flip.
7. **Settings exemplars:** hover an OptionCard chip → its minute swaps.
8. **Width:** watch neighboring status items during hover — nothing may shift.

Do not proceed until the user confirms. If hover misbehaves, instrument further before patching (per debugging rules) — the enter/exit log is the ground truth.

- [ ] **Step 3: Remove the instrumentation**

In `doubletime/App/AppDelegate.swift`, delete the `print` line and its TEMP-HOVER-DEBUG comment, leaving:

```swift
            hoverTracker = StatusItemHoverTracker(view: button) { [weak self] hovering in
                self?.clock.statusItemHovered = hovering
            }
```

Verify no stragglers: `grep -rn "TEMP-HOVER-DEBUG" doubletime/` → no matches.

- [ ] **Step 4: Final full verification**

```bash
xcodebuild test -project doubletime.xcodeproj -scheme doubletime -destination 'platform=macOS,arch=arm64' 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Step 5: Commit and open the PR**

```bash
git add doubletime/App/AppDelegate.swift
git commit -m "refactor(app): drop temporary hover instrumentation"
git push -u origin feat/hover-secondary-minute
```

Open a PR to `main` (rebase-merge workflow). PR body: the feature summary, the manual test script from Step 2 with results, and a note that `docs/menubar-hover.png` is generated by the gated `GlyphExport` test.

- [ ] **Step 6: Post-merge follow-up note**

Remind the user: the canonical glyph spec in the Claude Design project should gain the hover state (deliberate deviation record), per the design-system memory.
