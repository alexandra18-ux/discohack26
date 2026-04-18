# Nautilus sync status extension

This directory contains the `nautilus-python` extension that shows Yandex Disk sync state overlays in GNOME Files/Nautilus.

## What it uses

- D-Bus service: `ru.literallycats.daemon`
- D-Bus object path: `/ru/literallycats/daemon`
- D-Bus interface: `ru.literallycats.daemon`
- Properties: `MountPoint`, `SyncItems`
- Methods: `GetSyncStatus(path)`, `ListDirectoryStatuses(path)`

The first version intentionally uses standard system emblems instead of custom icon assets:

- `synced` → `emblem-default`
- `queued` / `uploading` / `downloading` → `emblem-synchronizing`
- `conflict` → `emblem-important`
- `error` → `emblem-unreadable`

## Install

By default Meson installs the extension to:

`<datadir>/nautilus-python/extensions`

For local development you can override it:

```bash
meson setup builddir --reconfigure -Dnautilus_extension_dir="$HOME/.local/share/nautilus-python/extensions"
meson install -C builddir
```

If you keep the default install path, a normal install also works:

```bash
meson setup builddir --reconfigure
meson install -C builddir
```

## Local sanity checks

These checks do not require Nautilus itself:

```bash
python3 -m py_compile nautilus/syncstatus.py
python3 nautilus/syncstatus.py --self-test
```

## Manual verification checklist

1. Start the daemon from `../discohack-daemon` and make sure it owns `ru.literallycats.daemon` on the session bus.
2. Confirm the daemon exposes a valid mount point and sync data:
   ```bash
   gdbus introspect --session \
     --dest ru.literallycats.daemon \
     --object-path /ru/literallycats/daemon
   ```
3. Install the extension with Meson.
4. Restart Nautilus so it reloads Python extensions:
   ```bash
   nautilus -q
   nautilus &
   ```
5. Open the mounted Yandex Disk directory in Nautilus.
6. Verify these scenarios:
   - file outside the mount has no overlay;
   - synced item shows the success emblem;
   - queued/uploading/downloading item shows the synchronizing emblem;
   - conflict item shows the warning emblem;
   - error item shows the error emblem;
   - when daemon goes away, overlays disappear instead of crashing Nautilus;
   - when `SyncItems` changes, visible items refresh without restarting Nautilus.

## Debugging

Enable debug prints before launching Nautilus:

```bash
DISCOHACK_NAUTILUS_DEBUG=1 nautilus
```
