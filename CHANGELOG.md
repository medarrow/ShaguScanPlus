# Changelog

## v1.4 (2026-11-26)

- Added a "Clean Import" checkbox to `/scan import all`, which deletes every window that isn't in the pasted code.
- Added `/scan delete all` to delete all windows, with a confirmation popup.
- Added `/scan help` to list all slash commands.

## v1.3.1 (2026-11-19)

- Fixed Lua errors when a unit disappears while its health bar is shown.
- Fixed "Require Shift for Mouse" not reacting reliably to the Shift key, and errors when pressing Shift.
- Fixed Save moving a window back to where it was before it was dragged.
- Fixed reopening a deleted window with `/scan <name>`.
- Renaming a window to an existing or empty name is now refused instead of replacing that window.
- Zero or negative width, height, scale and Max-Row values are now ignored.
- Fixed a window's saved position breaking when dropped at certain screen positions.
- Other windows keep updating while one is being dragged.
- Fixed the `name` filter with characters like `(` or `.`, and without a name.
- Health bars are now reused and units gone for over 10 minutes are forgotten, so memory and CPU use no longer grow during long sessions.
- Spaces around slash commands are now ignored.

## v1.3 (2026-11-11)

- Added the "Hide Label" option, which hides a window's title and settings button.

## v1.2 (2026-11-10)

- ShaguScanPlus is now a drop-in replacement for ShaguScan: it uses the `ShaguScan` folder, saved settings, Lua global and frame names again, so existing windows carry over.
- `/shaguscan` works again.

## v1.1 (2026-11-10)

First release of ShaguScanPlus. Changes compared to ShaguScan:

- Added the `color:COLOR(FILTERS)` modifier to color health bars.
- Added the `hurt`, `unhurt`, `tagged`, `notagged`, `othertagged` and `noothertagged` filters.
- Added the `inlos`, `distance`, `imbehind`, `imnotbehind`, `behindme` and `notbehindme` filters, which require UnitXP SP3.
- Added import and export of window settings, and `/scan import all` and `/scan export all`.
- Added `/scan list` to show all windows.
- Added the "Lock Movement" and "Require Shift for Mouse" options.
- Fixed the settings popup layout.
