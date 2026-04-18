#!/usr/bin/env python3
import os
import sys
import urllib.parse
from typing import Any, Callable, Dict, Iterable, List, Optional, Sequence, Set, Tuple

import gi

gi.require_version("Gio", "2.0")
gi.require_version("GLib", "2.0")

for nautilus_version in ("4.1", "4.0", "3.0"):
    try:
        gi.require_version("Nautilus", nautilus_version)
        break
    except ValueError:
        continue

from gi.repository import Gio, GLib, GObject

try:
    from gi.repository import Nautilus
    HAS_NAUTILUS = True
except (ImportError, ValueError):
    Nautilus = None
    HAS_NAUTILUS = False


BUS_NAME = "ru.literallycats.daemon"
OBJECT_PATH = "/ru/literallycats/daemon"
INTERFACE_NAME = "ru.literallycats.daemon"
ROOT_DAEMON_PATH = "disk:/"

# First version intentionally uses standard theme emblems instead of shipping
# custom assets. That keeps installation small and avoids icon theme plumbing.
STATE_TO_EMBLEMS: Dict[str, Tuple[str, ...]] = {
    "synced": ("emblem-default",),
    "queued": ("emblem-synchronizing",),
    "uploading": ("emblem-synchronizing",),
    "downloading": ("emblem-synchronizing",),
    "conflict": ("emblem-important",),
    "error": ("emblem-unreadable",),
}


def debug(message: str) -> None:
    if not os.environ.get("DISCOHACK_NAUTILUS_DEBUG"):
        return

    line = f"[discohack-nautilus] {message}"
    print(line)

    debug_log_path = os.environ.get("DISCOHACK_NAUTILUS_DEBUG_LOG")
    if debug_log_path:
        try:
            with open(debug_log_path, "a", encoding="utf-8") as debug_log:
                debug_log.write(line + "\n")
        except Exception:
            pass


def deep_unpack(value: Any) -> Any:
    if isinstance(value, GLib.Variant):
        return deep_unpack(value.unpack())
    if isinstance(value, dict):
        return {key: deep_unpack(item) for key, item in value.items()}
    if isinstance(value, list):
        return [deep_unpack(item) for item in value]
    if isinstance(value, tuple):
        return tuple(deep_unpack(item) for item in value)
    return value


def unwrap_single_result(value: Any) -> Any:
    unpacked = deep_unpack(value)
    if isinstance(unpacked, tuple) and len(unpacked) == 1:
        return unpacked[0]
    return unpacked


def normalize_mount_point(path: Optional[str]) -> Optional[str]:
    if not path:
        return None
    return os.path.realpath(path)


def uri_to_local_path(uri: str) -> Optional[str]:
    parsed = urllib.parse.urlparse(uri)
    if parsed.scheme not in ("", "file"):
        return None

    path = urllib.parse.unquote(parsed.path or uri)
    if not path:
        return None

    return os.path.realpath(path)


def is_same_or_under(path: str, root: str) -> bool:
    try:
        common = os.path.commonpath([path, root])
    except ValueError:
        return False
    return common == root


def local_path_to_daemon_path(local_path: str, mount_point: str) -> Optional[str]:
    if not is_same_or_under(local_path, mount_point):
        return None

    if local_path == mount_point:
        return ROOT_DAEMON_PATH

    relative = os.path.relpath(local_path, mount_point)
    if relative in (".", ""):
        return ROOT_DAEMON_PATH

    return ROOT_DAEMON_PATH + relative.replace(os.sep, "/")


def daemon_path_to_local_path(daemon_path: str, mount_point: str) -> Optional[str]:
    if daemon_path == ROOT_DAEMON_PATH:
        return mount_point

    if not daemon_path.startswith(ROOT_DAEMON_PATH):
        return None

    relative = daemon_path[len(ROOT_DAEMON_PATH):]
    if relative.startswith("/"):
        relative = relative[1:]
    if not relative:
        return mount_point

    parts = relative.split("/")
    if any(part in ("", ".", "..") for part in parts):
        return None

    return os.path.normpath(os.path.join(mount_point, *parts))


def parent_local_path(path: str, mount_point: str) -> Optional[str]:
    if path == mount_point:
        return None
    parent = os.path.dirname(path)
    if parent == "":
        return None
    if not is_same_or_under(parent, mount_point):
        return None
    return parent


def canonical_sync_item(item: Dict[str, Any]) -> Tuple[Any, ...]:
    return (
        item.get("state"),
        item.get("direction"),
        item.get("progress"),
        item.get("bytes_done"),
        item.get("bytes_total"),
        item.get("updated_at"),
    )


class DaemonClient:
    def __init__(self) -> None:
        self._proxy: Optional[Gio.DBusProxy] = None
        self._proxy_signal_id: Optional[int] = None
        self._mount_point: Optional[str] = None
        self._sync_item_index: Dict[str, Tuple[Any, ...]] = {}
        self._listeners: List[Callable[[Set[str], Set[str], Optional[str], Optional[str]], None]] = []
        self._watch_id = Gio.bus_watch_name(
            Gio.BusType.SESSION,
            BUS_NAME,
            Gio.BusNameWatcherFlags.NONE,
            self._on_name_appeared,
            self._on_name_vanished,
        )

    def add_listener(
        self,
        listener: Callable[[Set[str], Set[str], Optional[str], Optional[str]], None],
    ) -> None:
        self._listeners.append(listener)

    @property
    def mount_point(self) -> Optional[str]:
        self._ensure_proxy()
        return self._mount_point

    @property
    def available(self) -> bool:
        return self._proxy is not None and self._mount_point is not None

    def get_sync_status(self, daemon_path: str) -> Optional[Dict[str, Any]]:
        proxy = self._ensure_proxy()
        if proxy is None:
            return None

        try:
            result = proxy.call_sync(
                "GetSyncStatus",
                GLib.Variant("(s)", (daemon_path,)),
                Gio.DBusCallFlags.NONE,
                -1,
                None,
            )
        except GLib.Error as error:
            debug(f"GetSyncStatus failed for {daemon_path}: {error.message}")
            self._handle_runtime_failure()
            return None

        payload = unwrap_single_result(result)
        return payload if isinstance(payload, dict) else None

    def list_directory_statuses(self, daemon_path: str) -> Optional[List[Dict[str, Any]]]:
        proxy = self._ensure_proxy()
        if proxy is None:
            return None

        try:
            result = proxy.call_sync(
                "ListDirectoryStatuses",
                GLib.Variant("(s)", (daemon_path,)),
                Gio.DBusCallFlags.NONE,
                -1,
                None,
            )
        except GLib.Error as error:
            debug(f"ListDirectoryStatuses failed for {daemon_path}: {error.message}")
            self._handle_runtime_failure()
            return None

        payload = unwrap_single_result(result)
        if not isinstance(payload, list):
            return None
        return [item for item in payload if isinstance(item, dict)]

    def _ensure_proxy(self) -> Optional[Gio.DBusProxy]:
        if self._proxy is not None:
            return self._proxy

        try:
            self._connect_proxy()
        except GLib.Error as error:
            debug(f"Failed to connect D-Bus proxy: {error.message}")
            self._handle_runtime_failure()
            return None

        return self._proxy

    def _on_name_appeared(self, connection: Gio.DBusConnection, name: str, owner: str) -> None:
        debug(f"D-Bus name appeared: {name} owner={owner}")
        previous_mount = self._mount_point
        previous_index = dict(self._sync_item_index)

        try:
            self._connect_proxy()
        except GLib.Error as error:
            debug(f"Failed to initialize proxy on appear: {error.message}")
            self._handle_runtime_failure()
            return

        current_index = dict(self._sync_item_index)
        changed_paths = {
            path
            for path in set(previous_index.keys()) | set(current_index.keys())
            if previous_index.get(path) != current_index.get(path)
        }
        removed_paths = set(previous_index.keys()) - set(current_index.keys())
        self._emit_change(changed_paths, removed_paths, previous_mount, self._mount_point)

    def _on_name_vanished(self, connection: Gio.DBusConnection, name: str) -> None:
        debug(f"D-Bus name vanished: {name}")
        previous_mount = self._mount_point
        previous_items = set(self._sync_item_index.keys())
        self._reset_proxy_runtime_state()
        self._emit_change(set(), previous_items, previous_mount, None)

    def _connect_proxy(self) -> None:
        if self._proxy is not None:
            return

        proxy = Gio.DBusProxy.new_for_bus_sync(
            Gio.BusType.SESSION,
            Gio.DBusProxyFlags.NONE,
            None,
            BUS_NAME,
            OBJECT_PATH,
            INTERFACE_NAME,
            None,
        )
        self._proxy = proxy
        if self._proxy_signal_id is not None:
            self._proxy.disconnect(self._proxy_signal_id)
        self._proxy_signal_id = self._proxy.connect(
            "g-properties-changed",
            self._on_proxy_properties_changed,
        )
        self._reload_cached_properties(None)

    def _reset_proxy_runtime_state(self) -> None:
        if self._proxy is not None and self._proxy_signal_id is not None:
            try:
                self._proxy.disconnect(self._proxy_signal_id)
            except Exception:
                pass
        self._proxy = None
        self._proxy_signal_id = None
        self._mount_point = None
        self._sync_item_index = {}

    def _handle_runtime_failure(self) -> None:
        previous_mount = self._mount_point
        previous_items = set(self._sync_item_index.keys())
        self._reset_proxy_runtime_state()
        self._emit_change(set(), previous_items, previous_mount, None)

    def _on_proxy_properties_changed(
        self,
        proxy: Gio.DBusProxy,
        changed_properties: GLib.Variant,
        invalidated_properties: Sequence[str],
    ) -> None:
        changed_map = deep_unpack(changed_properties)
        changed_names = set(changed_map.keys()) if isinstance(changed_map, dict) else set()
        changed_names.update(invalidated_properties or [])
        if "MountPoint" not in changed_names and "SyncItems" not in changed_names:
            return

        previous_mount = self._mount_point
        previous_index = dict(self._sync_item_index)
        self._reload_cached_properties(changed_map if isinstance(changed_map, dict) else None)

        current_index = self._sync_item_index
        changed_paths = {
            path
            for path in set(previous_index.keys()) | set(current_index.keys())
            if previous_index.get(path) != current_index.get(path)
        }
        removed_paths = set(previous_index.keys()) - set(current_index.keys())
        self._emit_change(changed_paths, removed_paths, previous_mount, self._mount_point)

    def _reload_cached_properties(self, changed_map: Optional[Dict[str, Any]]) -> None:
        mount_value = None
        sync_items_value = None
        if changed_map is not None:
            mount_value = changed_map.get("MountPoint")
            sync_items_value = changed_map.get("SyncItems")

        if mount_value is None and self._proxy is not None:
            cached = self._proxy.get_cached_property("MountPoint")
            if cached is not None:
                mount_value = deep_unpack(cached)

        if sync_items_value is None and self._proxy is not None:
            cached = self._proxy.get_cached_property("SyncItems")
            if cached is not None:
                sync_items_value = deep_unpack(cached)

        self._mount_point = normalize_mount_point(mount_value if isinstance(mount_value, str) else None)
        self._sync_item_index = self._index_sync_items(sync_items_value)

    def _index_sync_items(self, payload: Any) -> Dict[str, Tuple[Any, ...]]:
        items = payload if isinstance(payload, list) else []
        index: Dict[str, Tuple[Any, ...]] = {}
        for item in items:
            if not isinstance(item, dict):
                continue
            path = item.get("path")
            if not isinstance(path, str):
                continue
            index[path] = canonical_sync_item(item)
        return index

    def _emit_change(
        self,
        changed_paths: Iterable[str],
        removed_paths: Iterable[str],
        previous_mount: Optional[str],
        current_mount: Optional[str],
    ) -> None:
        changed = set(changed_paths)
        removed = set(removed_paths)
        for listener in list(self._listeners):
            try:
                listener(changed, removed, previous_mount, current_mount)
            except Exception as error:
                debug(f"Listener failed: {error}")


class StatusCache:
    def __init__(self) -> None:
        self.path_statuses: Dict[str, Dict[str, Any]] = {}
        self.directory_children: Dict[str, Dict[str, Dict[str, Any]]] = {}

    def clear(self) -> None:
        self.path_statuses.clear()
        self.directory_children.clear()

    def store_path_status(self, local_path: str, status: Dict[str, Any]) -> None:
        self.path_statuses[local_path] = status

    def get_path_status(self, local_path: str) -> Optional[Dict[str, Any]]:
        return self.path_statuses.get(local_path)

    def store_directory_statuses(
        self,
        directory_path: str,
        children: Dict[str, Dict[str, Any]],
    ) -> None:
        self.directory_children[directory_path] = children
        for child_path, status in children.items():
            self.path_statuses[child_path] = status

    def get_directory_child_status(
        self,
        directory_path: str,
        child_path: str,
    ) -> Optional[Dict[str, Any]]:
        children = self.directory_children.get(directory_path)
        if children is None:
            return None
        return children.get(child_path)

    def invalidate_path(self, local_path: str, mount_point: Optional[str]) -> None:
        self.path_statuses.pop(local_path, None)
        if mount_point is None:
            return

        parent = parent_local_path(local_path, mount_point)
        if parent is not None:
            self.directory_children.pop(parent, None)

    def invalidate_directory(self, directory_path: str) -> None:
        self.directory_children.pop(directory_path, None)


debug(f"module imported; has_nautilus={HAS_NAUTILUS}")

if HAS_NAUTILUS:
    class SyncStateExtension(GObject.GObject, Nautilus.InfoProvider):
        def __init__(self) -> None:
            super().__init__()
            self._client = DaemonClient()
            self._client.add_listener(self._on_daemon_state_changed)
            self._cache = StatusCache()
            self._observed_items: Dict[str, Any] = {}
            debug("SyncStateExtension initialized")

        def update_file_info(self, item: Any) -> None:
            try:
                local_path = self._path_from_item(item)
                if local_path is None:
                    return

                self._observed_items[local_path] = item
                mount_point = self._client.mount_point
                if mount_point is None or not is_same_or_under(local_path, mount_point):
                    return

                status = self._resolve_status(local_path, mount_point)
                if status is None:
                    debug(f"No status resolved for {local_path}")
                    return

                self._apply_emblems(item, local_path, status)
            except Exception as error:
                debug(f"update_file_info failed: {error}")

        def _resolve_status(
            self,
            local_path: str,
            mount_point: str,
        ) -> Optional[Dict[str, Any]]:
            cached = self._cache.get_path_status(local_path)
            if cached is not None:
                return cached

            parent = parent_local_path(local_path, mount_point)
            if parent is not None:
                cached = self._cache.get_directory_child_status(parent, local_path)
                if cached is not None:
                    return cached
                self._populate_directory_cache(parent, mount_point)
                cached = self._cache.get_directory_child_status(parent, local_path)
                if cached is not None:
                    return cached

            daemon_path = local_path_to_daemon_path(local_path, mount_point)
            if daemon_path is None:
                return None

            status = self._client.get_sync_status(daemon_path)
            if not isinstance(status, dict):
                return None
            self._cache.store_path_status(local_path, status)
            return status

        def _populate_directory_cache(self, directory_path: str, mount_point: str) -> None:
            daemon_path = local_path_to_daemon_path(directory_path, mount_point)
            if daemon_path is None:
                return

            statuses = self._client.list_directory_statuses(daemon_path)
            if statuses is None:
                return

            mapped: Dict[str, Dict[str, Any]] = {}
            for status in statuses:
                daemon_child_path = status.get("path")
                if not isinstance(daemon_child_path, str):
                    continue
                local_child_path = daemon_path_to_local_path(daemon_child_path, mount_point)
                if local_child_path is None:
                    continue
                mapped[local_child_path] = status

            self._cache.store_directory_statuses(directory_path, mapped)

        def _apply_emblems(self, item: Any, local_path: str, status: Dict[str, Any]) -> None:
            state = status.get("state")
            if not isinstance(state, str):
                debug(f"Skipping invalid status payload for {local_path}: {status!r}")
                return

            emblems = STATE_TO_EMBLEMS.get(state, ())
            if not emblems:
                debug(f"No emblem for state={state} path={local_path}")
                return

            debug(f"Applying emblems {emblems} for state={state} path={local_path}")
            for emblem in emblems:
                item.add_emblem(emblem)

        def _path_from_item(self, item: Any) -> Optional[str]:
            if item.get_uri_scheme() != "file":
                return None
            return uri_to_local_path(item.get_uri())

        def _invalidate_item(self, local_path: str) -> None:
            item = self._observed_items.get(local_path)
            if item is None:
                return
            try:
                item.invalidate_extension_info()
            except Exception as error:
                debug(f"Failed to invalidate {local_path}: {error}")

        def _invalidate_all(self) -> None:
            for path in list(self._observed_items.keys()):
                self._invalidate_item(path)

        def _on_daemon_state_changed(
            self,
            changed_paths: Set[str],
            removed_paths: Set[str],
            previous_mount: Optional[str],
            current_mount: Optional[str],
        ) -> None:
            mount_changed = previous_mount != current_mount
            debug(
                "Daemon state changed: "
                f"changed={sorted(changed_paths)} removed={sorted(removed_paths)} "
                f"previous_mount={previous_mount} current_mount={current_mount}"
            )
            if mount_changed:
                self._cache.clear()
                self._invalidate_all()
                return

            mount_point = current_mount
            if mount_point is None:
                self._cache.clear()
                self._invalidate_all()
                return

            affected_paths = set(changed_paths) | set(removed_paths)
            for daemon_path in affected_paths:
                local_path = daemon_path_to_local_path(daemon_path, mount_point)
                if local_path is None:
                    continue
                self._cache.invalidate_path(local_path, mount_point)
                parent = parent_local_path(local_path, mount_point)
                if parent is not None:
                    self._cache.invalidate_directory(parent)
                    self._invalidate_item(parent)
                self._invalidate_item(local_path)


def _assert_equal(left: Any, right: Any) -> None:
    if left != right:
        raise AssertionError(f"Expected {right!r}, got {left!r}")


def run_self_tests() -> None:
    mount_point = "/tmp/discohack-mount"
    _assert_equal(local_path_to_daemon_path(mount_point, mount_point), ROOT_DAEMON_PATH)
    _assert_equal(
        local_path_to_daemon_path(os.path.join(mount_point, "foo", "bar.txt"), mount_point),
        "disk:/foo/bar.txt",
    )
    _assert_equal(daemon_path_to_local_path(ROOT_DAEMON_PATH, mount_point), mount_point)
    _assert_equal(
        daemon_path_to_local_path("disk:/foo/bar.txt", mount_point),
        os.path.join(mount_point, "foo", "bar.txt"),
    )
    _assert_equal(daemon_path_to_local_path("disk:/../oops", mount_point), None)
    _assert_equal(parent_local_path(mount_point, mount_point), None)
    _assert_equal(parent_local_path(os.path.join(mount_point, "foo"), mount_point), mount_point)
    print("self-tests passed")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        run_self_tests()
    else:
        print("This module is meant to be loaded by Nautilus.")
