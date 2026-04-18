## 1. Scaffold Nautilus shell integration

- [x] 1.1 Create a dedicated Nautilus extension module/layout in the repo (separate from the Vala `src/` sources) for the Python `nautilus-python` implementation
- [x] 1.2 Add Meson wiring for the new shell-integration directory, including a configurable install destination for the Nautilus extension script
- [x] 1.3 Define the overlay mapping constants and decide whether the first version uses existing theme emblems or ships custom emblem assets

## 2. Build the daemon D-Bus client and path/status resolution layer

- [x] 2.1 Implement a GIO D-Bus client for `ru.literallycats.daemon` that can read `MountPoint`, call `GetSyncStatus`, call `ListDirectoryStatuses`, and observe `PropertiesChanged`
- [x] 2.2 Implement URI/local-path normalization and conversion between Nautilus `file://` items under `MountPoint` and daemon paths rooted at `disk:/`
- [x] 2.3 Add directory-scoped status caching so direct children can be populated from one `ListDirectoryStatuses` call with `GetSyncStatus` as a fallback for cache misses or root items

## 3. Implement Nautilus overlay behavior and live refresh

- [x] 3.1 Implement the Nautilus `InfoProvider` that tracks observed `FileInfo` objects and applies or clears emblems for in-scope files and directories
- [x] 3.2 Subscribe to daemon sync property updates, diff the previous and current `SyncItems` path sets, and invalidate affected items and parent directory caches
- [x] 3.3 Handle daemon unavailability, invalid D-Bus payloads, and reconnect paths so the extension stays loaded and returns no overlay instead of blocking or crashing Nautilus

## 4. Install resources and verify the integration

- [x] 4.1 Install the Nautilus extension script through Meson and install any required emblem assets to their runtime location
- [x] 4.2 Manually verify overlay behavior for files inside and outside the mount, including synced, syncing, conflict, error, daemon-unavailable, and state-transition scenarios
- [x] 4.3 Document any developer or tester steps needed to enable the extension locally (for example install path expectations and Nautilus restart/reload steps)
