# nautilus-sync-status-extension Specification

## Purpose
TBD - created by archiving change add-nautilus-sync-status-extension. Update Purpose after archive.
## Requirements
### Requirement: Nautilus SHALL show sync status overlays for items inside the Yandex Disk mount
The system SHALL show a Nautilus overlay emblem for files and directories whose local path is inside the daemon-reported `MountPoint`, using daemon sync status as the source of truth.

#### Scenario: File inside mount shows mapped overlay
- **WHEN** Nautilus requests extension info for a file inside the daemon `MountPoint` and the daemon reports a known status for that path
- **THEN** the extension applies the configured overlay mapping for that status
- **AND** `synced` maps to an OK/success overlay
- **AND** `queued`, `uploading`, and `downloading` map to a syncing overlay
- **AND** `conflict` maps to a conflict/warning overlay
- **AND** `error` maps to an error overlay

#### Scenario: Item outside mount has no overlay
- **WHEN** Nautilus requests extension info for a file or directory outside the daemon `MountPoint`
- **THEN** the extension does not query per-path sync state for that item
- **AND** it does not apply a Yandex Disk sync overlay

### Requirement: The extension SHALL resolve statuses through the daemon D-Bus API with directory-aware lookups
The system SHALL use the daemon D-Bus contract to map local Nautilus items to daemon paths and SHALL prefer directory-level status loading before falling back to single-path queries.

#### Scenario: Directory listing is served from direct-child status query
- **WHEN** Nautilus requests info for items that are direct children of the same in-scope directory
- **THEN** the extension loads statuses for that directory through `ListDirectoryStatuses(path)`
- **AND** it uses the returned child entries to populate overlays for matching files and folders
- **AND** it does not require a separate `GetSyncStatus(path)` call for every child when the directory batch already contains the needed data

#### Scenario: Single item falls back to direct status query
- **WHEN** Nautilus requests info for an in-scope item whose status is not available from the current directory cache
- **THEN** the extension queries `GetSyncStatus(path)` for that specific daemon path
- **AND** it uses the returned known or unknown result to decide whether an overlay should be shown

### Requirement: Nautilus overlays SHALL refresh when daemon sync properties change
The system SHALL react to daemon `org.freedesktop.DBus.Properties.PropertiesChanged` updates so already observed items can be invalidated and redisplayed without restarting Nautilus.

#### Scenario: Active item changes state while visible in Nautilus
- **WHEN** the daemon emits a sync property update that changes the state of a path currently tracked by the extension
- **THEN** the extension invalidates the corresponding Nautilus item so its overlay is recomputed
- **AND** the refreshed overlay reflects the latest daemon status

#### Scenario: Path leaves active sync set and becomes settled
- **WHEN** a previously active path disappears from the daemon `SyncItems` property because it has reached a settled state such as `synced`
- **THEN** the extension invalidates the affected item or its parent directory cache
- **AND** a subsequent status read shows the settled overlay or no overlay according to the latest `GetSyncStatus(path)` result

### Requirement: The extension SHALL degrade safely when the daemon is unavailable or returns errors
The system MUST avoid crashing, hanging, or showing misleading success overlays when the D-Bus service is unavailable or individual status calls fail.

#### Scenario: Daemon is not available on session D-Bus
- **WHEN** Nautilus loads the extension and `ru.literallycats.daemon` has no owner on the session bus
- **THEN** the extension remains loaded without crashing Nautilus
- **AND** it shows no Yandex Disk sync overlays until the daemon becomes available

#### Scenario: Status query fails for an in-scope item
- **WHEN** a D-Bus status read for an in-scope path fails or returns invalid data
- **THEN** the extension clears or skips the overlay for that item
- **AND** it keeps Nautilus responsive for subsequent items instead of aborting the provider

### Requirement: Project installation SHALL include the Nautilus extension assets needed for status overlays
The project SHALL install the Nautilus extension code, and any custom overlay assets it depends on, so the integration can be enabled through the normal project install flow.

#### Scenario: Install places Nautilus extension in extension search path
- **WHEN** the project is installed through its supported Meson install flow
- **THEN** the Nautilus extension script is installed into the configured `nautilus-python` extensions directory
- **AND** any custom emblem resources required by the chosen overlay mapping are installed to their expected runtime location

