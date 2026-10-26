# Doubletime

A macOS menu bar clock that shows two time zones side by side.

<p align="center">
  <img src="docs/menubar.png" width="261" alt="The menu bar glyph: a JST cell reading 21, a PDT cell reading 05, and the minute 34 after a colon">
</p>

One cell per zone, plus the primary minute. A thin ring on the secondary cell encodes the sub-hour offset, so half-hour zones like Kolkata read correctly.

<p align="center">
  <img src="docs/menubar-hover.png" width="261" alt="Hovering rolls the minute to the secondary zone (tinted ink marks the swap)">
</p>

The name and the itch both come from [One Clock](https://elaworkshop.github.io/oneclock).

## Features

- Any IANA time zone in either slot; the primary can follow the system zone.
- Labels up to five characters, derived from the zone or typed yourself.
- 12-hour or 24-hour digits; 12-hour mode tints each cell by its own AM or PM.
- Arc or segmented indicator.
- Optional blinking colon.
- Hover the clock to roll the trailing minute to the secondary zone's local time — only when the zones sit at a sub-hour offset (the arc/segment pairs).
- Settings previews rendered from the same raster as the real status item.

## Building

Open `doubletime.xcodeproj`, set your signing team, and run. Targets macOS 26.0; SwiftUI, no dependencies.

## License

Copyright © 2026 eutialia. Licensed under the [GNU General Public License v3.0 or later](LICENSE).

As an additional permission under section 7 of the GPL, you may distribute this program, or a work based on it, through an app store under that store's terms of service, even where those terms add restrictions the GPL would otherwise forbid, provided the Corresponding Source remains available under the GPL.

The Doubletime name and app icon are not covered by this license. Forks that ship must use their own.
