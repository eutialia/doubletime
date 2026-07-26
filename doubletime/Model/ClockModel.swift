//
//  ClockModel.swift
//  doubletime
//

import SwiftUI

@Observable @MainActor
final class ClockModel {
    /// AM/PM period of a wall-clock hour, used to tint 12-hour cells.
    /// nonisolated: a pure value type — inheriting the class's MainActor
    /// isolation would bind the synthesized Equatable to the main actor
    /// (a Swift 6 error when compared from nonisolated contexts like tests).
    nonisolated enum Period {
        case am
        case pm
    }

    static let secondaryTimezoneKey = "secondaryTimezoneIdentifier"
    static let primaryTimezoneKey = "primaryTimezoneIdentifier"
    static let secondaryLabelKey = "secondaryLabelOverride"
    static let primaryLabelKey = "primaryLabelOverride"
    static let hour12Key = "hour12"
    static let variantKey = "glyphVariant"
    static let blinkColonKey = "blinkColon"

    /// One shared Gregorian calendar for every digit computation — copying it
    /// per call (to set `timeZone`) triggers a CoW allocation on the hot path.
    private nonisolated static let gregorian = Calendar(identifier: .gregorian)

    /// A UTC-anchored calendar used to difference two zones' calendar days
    /// without their offsets interfering. Shared for the same CoW reason.
    private nonisolated static let utcGregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Pinned locale for the verbatim styles. Weekday and month names are the
    /// only formatted output that is not pure digits, and a nil locale renders
    /// them as raw field codes ("M02" instead of "Feb").
    private nonisolated static let fixedLocale = Locale(identifier: "en_US_POSIX")

    // MARK: Zones

    var secondaryTimezone: TimeZone {
        didSet {
            UserDefaults.standard.set(secondaryTimezone.identifier, forKey: Self.secondaryTimezoneKey)
        }
    }

    /// nil ⇒ the system zone (`.autoupdatingCurrent`). The primary zone is
    /// user-selectable in v2 (v1 hardcoded it).
    var primaryTimezoneIdentifier: String? {
        didSet {
            primaryTimezone = Self.resolve(primaryTimezoneIdentifier)
            UserDefaults.standard.setOrRemove(primaryTimezoneIdentifier, forKey: Self.primaryTimezoneKey)
        }
    }

    /// The resolved primary zone, kept in sync with `primaryTimezoneIdentifier`.
    /// The nil case stores `.autoupdatingCurrent` itself (a live zone that tracks
    /// the system), never a resolved snapshot.
    private(set) var primaryTimezone: TimeZone

    private nonisolated static func resolve(_ id: String?) -> TimeZone {
        id.flatMap(TimeZone.init(identifier:)) ?? .autoupdatingCurrent
    }

    /// True when the primary zone follows the system rather than a pinned id.
    var primaryIsSystem: Bool { primaryTimezoneIdentifier == nil }

    // MARK: Labels

    var secondaryLabelOverride: String? {
        didSet { UserDefaults.standard.setOrRemove(secondaryLabelOverride, forKey: Self.secondaryLabelKey) }
    }

    var primaryLabelOverride: String? {
        didSet { UserDefaults.standard.setOrRemove(primaryLabelOverride, forKey: Self.primaryLabelKey) }
    }

    /// Derived-default label cache, keyed by zone identifier and validated against
    /// the zone's current UTC offset so DST transitions recompute. Excluded from
    /// observation: it is a pure memo of the pure derivation, mutated on the hot
    /// path (during view body) where triggering observation would be unsafe.
    @ObservationIgnored private var labelCache: [String: (offset: Int, label: String)] = [:]

    private func cachedDefaultLabel(for tz: TimeZone, at date: Date) -> String {
        let offset = tz.secondsFromGMT(for: date)
        if let cached = labelCache[tz.identifier], cached.offset == offset {
            return cached.label
        }
        let label = Self.defaultLabel(for: tz, at: date)
        labelCache[tz.identifier] = (offset, label)
        return label
    }

    func secondaryLabel(at date: Date) -> String {
        Self.sanitizedLabel(secondaryLabelOverride) ?? cachedDefaultLabel(for: secondaryTimezone, at: date)
    }

    func primaryLabel(at date: Date) -> String {
        Self.sanitizedLabel(primaryLabelOverride) ?? cachedDefaultLabel(for: primaryTimezone, at: date)
    }

    // MARK: Display settings

    var hour12: Bool {
        didSet { UserDefaults.standard.set(hour12, forKey: Self.hour12Key) }
    }

    var variant: GlyphVariant {
        didSet { UserDefaults.standard.set(variant.rawValue, forKey: Self.variantKey) }
    }

    var blinkColon: Bool {
        didSet { UserDefaults.standard.set(blinkColon, forKey: Self.blinkColonKey) }
    }

    // MARK: System zone tracking

    /// Bumped whenever the Mac's timezone changes. StatusBarView reads this in its
    /// body so a "System (auto)" primary repaints at once instead of at the next
    /// minute tick.
    private(set) var systemZoneGeneration = 0

    /// True while the pointer is over the status item. Transient interaction
    /// state — deliberately NOT persisted (no didSet → UserDefaults): it is
    /// meaningless across launches, like systemZoneGeneration.
    var statusItemHovered = false

    @ObservationIgnored private var systemZoneObserver: (any NSObjectProtocol)?

    init() {
        let savedId = UserDefaults.standard.string(forKey: Self.secondaryTimezoneKey)
        secondaryTimezone = savedId.flatMap(TimeZone.init(identifier:))
            ?? TimeZone(identifier: "Asia/Tokyo")
            ?? TimeZone.current
        let primaryId = UserDefaults.standard.string(forKey: Self.primaryTimezoneKey)
        primaryTimezoneIdentifier = primaryId
        // didSet does not fire during init — resolve the stored zone explicitly.
        primaryTimezone = Self.resolve(primaryId)
        secondaryLabelOverride = UserDefaults.standard.string(forKey: Self.secondaryLabelKey)
        primaryLabelOverride = UserDefaults.standard.string(forKey: Self.primaryLabelKey)
        hour12 = UserDefaults.standard.bool(forKey: Self.hour12Key)
        variant = UserDefaults.standard.string(forKey: Self.variantKey)
            .flatMap(GlyphVariant.init(rawValue:)) ?? .arc
        blinkColon = UserDefaults.standard.bool(forKey: Self.blinkColonKey)

        systemZoneObserver = NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            // `.main` guarantees this runs on the main thread ⇒ MainActor.
            MainActor.assumeIsolated { self?.systemZoneDidChange() }
        }
    }

    deinit {
        if let systemZoneObserver {
            NotificationCenter.default.removeObserver(systemZoneObserver)
        }
    }

    private func systemZoneDidChange() {
        // Offsets may have changed; drop the cache so labels re-derive.
        labelCache.removeAll()
        systemZoneGeneration &+= 1
    }

    // MARK: Label helpers

    nonisolated static func cityName(from tz: TimeZone) -> String {
        let last = tz.identifier.components(separatedBy: "/").last ?? tz.identifier
        return last.replacing("_", with: " ")
    }

    /// Uppercase → keep only A–Z0–9 → clamp to 5 chars → nil if empty. The single
    /// clamp for label overrides, applied to live keystrokes (ZoneRowControl) AND
    /// to persisted values at resolve time (repairs stale pre-v2 strings that were
    /// stored before the clamp existed, with zero migration code).
    nonisolated static func sanitizedLabel(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let allowed = raw.uppercased().unicodeScalars.filter {
            ("A"..."Z").contains(Character($0)) || ("0"..."9").contains(Character($0))
        }
        let clamped = String(String.UnicodeScalarView(allowed.prefix(5)))
        return clamped.isEmpty ? nil : clamped
    }

    /// The default 2–5 char code for a zone at a given instant when the user has
    /// set no override. Date-aware so it honors DST (America/New_York → EST in
    /// winter, EDT in summer; Europe/London → GMT/BST):
    /// 1. the zone's own abbreviation for that instant, if purely alphabetic
    ///    (accepts EST/EDT/GMT/BST; rejects offset strings like "GMT+5:30");
    /// 2. else a purely-alphabetic abbreviationDictionary entry mapping to the id
    ///    (covers Asia/Kolkata → IST, Asia/Tokyo → JST, whose abbreviation(for:)
    ///    returns an offset string);
    /// 3. else the first 3 letters of the city name (Asia/Kathmandu → KAT).
    nonisolated static func defaultLabel(for tz: TimeZone, at date: Date) -> String {
        if let abbreviation = tz.abbreviation(for: date),
           !abbreviation.isEmpty, abbreviation.allSatisfy(\.isLetter) {
            return abbreviation
        }
        let alphaAbbreviations = TimeZone.abbreviationDictionary
            .filter { $0.value == tz.identifier && $0.key.allSatisfy(\.isLetter) }
            .keys
            .sorted()
        if let abbreviation = alphaAbbreviations.first {
            return abbreviation
        }
        return String(cityName(from: tz).prefix(3)).uppercased()
    }

    /// Single source of truth for "override or derived default" label resolution,
    /// shared by the live glyph and every settings preview. The override is
    /// sanitized (never rendered verbatim over the fixed cell).
    nonisolated static func resolvedLabel(override: String?, for tz: TimeZone, at date: Date) -> String {
        sanitizedLabel(override) ?? defaultLabel(for: tz, at: date)
    }

    // MARK: Zone offsets

    /// Minutes `from` is ahead of `to` at `date` (negative ⇒ `from` is behind).
    nonisolated static func offsetMinutes(from: TimeZone, to: TimeZone, at date: Date) -> Int {
        (from.secondsFromGMT(for: date) - to.secondsFromGMT(for: date)) / 60
    }

    /// How a signed zone offset renders. Both shapes share one implementation so
    /// the sign glyph and the zero-padded minutes cannot drift apart.
    nonisolated enum OffsetStyle {
        /// Collapses the common cases — `same`, `+5h`, `+5:30`. The zone picker
        /// scans hundreds of rows, where the shorter string reads faster.
        case terse
        /// Always `+5:30` / `−2:00`, including `+0:00`. A fixed-shape caption, so
        /// the status menu's row never reflows as zones or DST change.
        case exact
    }

    /// The signed offset caption. U+2212 MINUS, not a hyphen, so the sign shares
    /// the width and weight of the tabular digits it sits beside.
    nonisolated static func offsetCaption(minutes: Int, style: OffsetStyle) -> String {
        if style == .terse, minutes == 0 { return "same" }
        let sign = minutes < 0 ? "\u{2212}" : "+"
        let magnitude = abs(minutes)
        let hours = magnitude / 60
        let remainder = magnitude % 60
        if style == .terse, remainder == 0 { return "\(sign)\(hours)h" }
        // Pinned locale: the hours are interpolated verbatim, so leaving the
        // minutes on Locale.current would render "+5:٣٠" under a region whose
        // numbering system is not Latin.
        let padded = remainder.formatted(
            .number.precision(.integerLength(2)).locale(fixedLocale)
        )
        return "\(sign)\(hours):\(padded)"
    }

    /// The offset as VoiceOver should say it — "5 hours, 30 minutes ahead". The
    /// visible `+5:30` is a glyph, not a phrase; read aloud it means nothing.
    /// Locale-pinned for the same reason `dateLabel` is: the app is English-only,
    /// and a localized magnitude next to the hardcoded "ahead" would read as half
    /// a translation.
    nonisolated static func spokenOffset(minutes: Int) -> String {
        guard minutes != 0 else { return "same time" }
        let magnitude = Duration.seconds(abs(minutes) * 60).formatted(
            .units(allowed: [.hours, .minutes], width: .wide, zeroValueUnits: .hide)
                .locale(fixedLocale)
        )
        return "\(magnitude) \(minutes > 0 ? "ahead" : "behind")"
    }

    /// How a day difference reads aloud. The visible `+1d` badge is a glyph, and
    /// the magnitude is not always 1 — see `dayDelta`.
    nonisolated static func spokenDayDelta(_ delta: Int) -> String? {
        switch delta {
        case 0: nil
        case 1: "next day"
        case -1: "previous day"
        default: "\(abs(delta)) days \(delta > 0 ? "later" : "earlier")"
        }
    }

    // MARK: Dates

    /// `Mon 20 Apr` in a zone — day before month, matching the reading order of
    /// the 24-hour digits. Deliberately fixed rather than localized: a localized
    /// style reorders to `Mon, Apr 20` in en_US and loses the canon shape (the
    /// app carries no localizations, so nothing else is given up).
    nonisolated static func dateLabel(for tz: TimeZone, at date: Date) -> String {
        date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(weekday: .abbreviated) \(day: .twoDigits) \(month: .abbreviated)",
                locale: fixedLocale,
                timeZone: tz,
                calendar: gregorian
            )
        )
    }

    /// Whole calendar days `from`'s local date is ahead of `to`'s at the same
    /// instant. Usually −1, 0 or +1, but the zone span is 26 hours, not 24, so ±2
    /// is reachable: at 10:00 UTC, Pacific/Kiritimati (UTC+14) is already 00:00 on
    /// the next day while Pacific/Midway (UTC−11) is still 23:00 on the previous
    /// one. Derived from each zone's date components rather than from the offset
    /// in minutes, which gets DST-transition days and 45-minute zones wrong.
    nonisolated static func dayDelta(from: TimeZone, to: TimeZone, at date: Date) -> Int {
        let anchor = utcAnchoredDay(for: to, at: date)
        let subject = utcAnchoredDay(for: from, at: date)
        return utcGregorian.dateComponents([.day], from: anchor, to: subject).day ?? 0
    }

    /// The zone's calendar day at `date`, re-anchored to UTC midnight so two
    /// zones' days can be differenced with their offsets factored out.
    private nonisolated static func utcAnchoredDay(for tz: TimeZone, at date: Date) -> Date {
        let components = gregorian.dateComponents(in: tz, from: date)
        return utcGregorian.date(
            from: DateComponents(year: components.year, month: components.month, day: components.day)
        ) ?? date
    }

    // MARK: Anchored sweep

    /// The signed sub-hour offset between the two zones, encoded as a fraction of
    /// an hour plus a direction. `clockwise` = secondary is ahead of primary;
    /// counterclockwise = behind (drawn by mirroring the clockwise path).
    nonisolated static func anchoredSweep(
        secondary: TimeZone,
        primary: TimeZone,
        at date: Date
    ) -> (fraction: Double, clockwise: Bool) {
        let deltaMinutes = offsetMinutes(from: secondary, to: primary, at: date)
        let fraction = Double(abs(deltaMinutes) % 60) / 60.0
        return (fraction, deltaMinutes >= 0)
    }

    /// Quarter-hour tick count for the segmented variant: `round(fraction * 4)`
    /// so :30 always snaps to exactly 2 segments. 0 ⇒ draw nothing.
    nonisolated static func segmentQuarters(fraction: Double) -> Int {
        Int((fraction * 4).rounded())
    }

    // MARK: Colon blink

    /// Deterministic even/odd-second parity: even epoch second ⇒ colon visible.
    nonisolated static func colonVisible(at date: Date) -> Bool {
        Int(date.timeIntervalSince1970.rounded(.down)) % 2 == 0
    }

    // MARK: Digits

    private nonisolated static func hourValue(for tz: TimeZone, at date: Date) -> Int {
        gregorian.dateComponents(in: tz, from: date).hour ?? 0
    }

    nonisolated static func hour(for tz: TimeZone, at date: Date) -> String {
        date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))",
                timeZone: tz,
                calendar: gregorian
            )
        )
    }

    /// Zero-padded 12-hour hour via the same verbatim pipeline as `hour`. The
    /// one-based twelve-hour clock maps 00→"12", 12→"12", 13→"01".
    nonisolated static func hour12(for tz: TimeZone, at date: Date) -> String {
        date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(hour: .twoDigits(clock: .twelveHour, hourCycle: .oneBased))",
                timeZone: tz,
                calendar: gregorian
            )
        )
    }

    /// AM before noon, PM from noon — the encoding that replaces AM/PM text.
    nonisolated static func period(for tz: TimeZone, at date: Date) -> Period {
        hourValue(for: tz, at: date) < 12 ? .am : .pm
    }

    nonisolated static func minute(for tz: TimeZone, at date: Date) -> String {
        date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(minute: .twoDigits)",
                timeZone: tz,
                calendar: gregorian
            )
        )
    }

    /// The hour in whichever format the surface is showing — the one place the
    /// 12/24 choice is made, so the glyph and the status menu cannot drift apart.
    nonisolated static func hour(for tz: TimeZone, at date: Date, hour12 twelveHour: Bool) -> String {
        twelveHour ? hour12(for: tz, at: date) : hour(for: tz, at: date)
    }

    /// Zone-local `HH:mm`. One join for every surface that spells the time out in
    /// full (the zone picker, the status menu); the glyph splits the two halves
    /// across cells and composes them itself.
    nonisolated static func time(for tz: TimeZone, at date: Date, hour12 twelveHour: Bool) -> String {
        "\(hour(for: tz, at: date, hour12: twelveHour)):\(minute(for: tz, at: date))"
    }
}
