"""
Tray helper for Flet apps with a user-extension bridge.

Highlights:
 - Pystray-backed tray icon helper (`TrayApp`) for Python.
 - Flet extension bridge so tray actions/events are exposed via
   ``page.import_extension("tray")`` when available.
 - Menu JSON normalisation (accepts ``items`` or ``children``) and a helper
   to emit ``items`` for nested menus.
"""

from __future__ import annotations

import json
import threading
import traceback
from dataclasses import dataclass, field
from typing import Callable, Dict, Iterable, List, Optional, Sequence

import pystray  # type: ignore
from PIL import Image  # type: ignore

EXTENSION_NAME = "tray"

TrayCallback = Callable[[pystray.Icon], None]
ActionCallback = Callable[[object | None], None]

# In-memory registry so actions can be called by name (e.g. from extension events).
_ACTIONS: Dict[str, ActionCallback] = {}


def register_action(name: str, fn: ActionCallback) -> None:
    """Register an action callback by name."""
    if not name or not callable(fn):
        return
    _ACTIONS[name] = fn


def registered_actions() -> Dict[str, ActionCallback]:
    """Return a copy of the registered actions."""
    return dict(_ACTIONS)


@dataclass
class MenuNode:
    """Represents a menu item that can be converted to a pystray MenuItem."""

    text: str
    action: Optional[str] = None
    disabled: bool = False
    checked: bool = False
    children: List["MenuNode"] = field(default_factory=list)
    icon: Optional[str] = None  # reserved for future use


def _normalise_menu(items: Iterable[dict]) -> List[MenuNode]:
    """Parse menu JSON accepting either ``items`` or ``children`` keys."""
    nodes: List[MenuNode] = []
    for item in items or []:
        label = (
            item.get("text")
            or item.get("label")
            or item.get("title")
            or "Menu item"
        )
        child_data = item.get("items") if isinstance(item, dict) else None
        if not child_data and isinstance(item, dict):
            child_data = item.get("children")
        node = MenuNode(
            text=label,
            action=item.get("action"),
            disabled=bool(item.get("disabled", False)),
            checked=bool(item.get("checked", False)),
            icon=item.get("icon"),
            children=_normalise_menu(child_data or []),
        )
        nodes.append(node)
    return nodes


def menu_to_dict(items: Sequence[MenuNode]) -> List[dict]:
    """Emit menu JSON using the ``items`` key for nested structures."""
    out: List[dict] = []
    for node in items:
        data = {
            "text": node.text,
            "action": node.action,
            "disabled": node.disabled,
            "checked": node.checked,
        }
        if node.children:
            data["items"] = menu_to_dict(node.children)
        out.append(data)
    return out


def _build_pystray_menu(nodes: Sequence[MenuNode]) -> pystray.Menu:
    """Convert MenuNode list to a pystray.Menu."""
    menu_items: List[pystray.MenuItem] = []
    debug_labels: List[str] = []
    for node in nodes:
        debug_labels.append(node.text)
        if node.children:
            submenu = _build_pystray_menu(node.children)
            menu_items.append(
                pystray.MenuItem(
                    node.text,
                    submenu,
                    enabled=not node.disabled,
                    default=False,
                )
            )
            continue

        callback = _ACTIONS.get(node.action or "")

        def _cb(_icon=None, _item=None, *, fn=callback, name=node.action):
            try:
                if fn:
                    fn({"action": name})
                else:
                    print(f"Tray action '{name}' has no registered handler")
            except Exception as exc:
                print(f"Tray action '{name}' failed: {exc}")

        checked_cb = (lambda _i: node.checked) if node.checked else None
        menu_items.append(
            pystray.MenuItem(
                node.text,
                _cb,
                enabled=not node.disabled,
                checked=checked_cb,
                default=False,
            )
        )
    if not menu_items:
        print("TrayApp: menu has no items")
        return pystray.Menu()
    print(f"TrayApp: pystray menu items -> {debug_labels}")
    return pystray.Menu(*menu_items)

class TrayApp:
    def __init__(
        self,
        name: str,
        title: str,
        icon_path: Optional[str],
        on_open: TrayCallback,
        on_exit: TrayCallback,
        menu: Optional[Iterable[dict]] = None,
        fallback_color=(128, 128, 128),
    ) -> None:
        self._icon_path = icon_path
        self._on_open = on_open
        self._on_exit = on_exit
        self._fallback_color = fallback_color
        self._menu_nodes = _normalise_menu(menu or [])
        # append default open/exit entries if caller did not supply any menu
        default_menu = not self._menu_nodes
        if default_menu:
            self._menu_nodes = [
                MenuNode(text="Open", action="open"),
                MenuNode(text="Exit", action="exit"),
            ]
        # ensure built-ins have handlers
        register_action("open", lambda *_: self._on_open(self))
        register_action("exit", lambda *_: self._on_exit(self))

        print(f"TrayApp: menu nodes -> {[n.text for n in self._menu_nodes]}")
        print(f"TrayApp: building menu with actions={list(_ACTIONS.keys())}")
        try:
            self.icon = pystray.Icon(
                name=name,
                icon=self._load_icon(),
                title=title,
                menu=_build_pystray_menu(self._menu_nodes),
            )
        except Exception as exc:
            print(f"TrayApp: failed to create Icon: {exc}")
            traceback.print_exc()
            raise

    def _load_icon(self) -> Image.Image:
        if self._icon_path:
            try:
                return Image.open(self._icon_path)
            except Exception:
                pass
        return Image.new("RGB", (64, 64), self._fallback_color)

    def start(self, mac: bool = False, block: bool = False) -> None:
        """
        Start the tray icon.

        On macOS the AppKit runloop must be on the main thread. When
        ``block`` is True, this will call ``icon.run()`` synchronously; use
        this from the main thread and run your app in a background thread.
        Otherwise it falls back to run_detached/threaded modes.
        """
        # Prefer blocking on main thread if asked
        if mac and block:
            print("TrayApp: starting on main thread (blocking run())")
            self.icon.run()
            return

        # On macOS try run_detached to avoid hangs on click
        if mac and hasattr(self.icon, "run_detached"):
            try:
                print("TrayApp: starting with run_detached (macOS)")
                self.icon.run_detached()
                return
            except Exception as exc:
                print(f"TrayApp: run_detached failed ({exc}), using thread")

        # Use run() in a background thread
        print("TrayApp: starting tray with run() in background thread")
        def _run():
            try:
                self.icon.run()
            except Exception as exc:
                print(f"TrayApp: icon.run() failed ({exc})")
        t = threading.Thread(target=_run, daemon=True)
        t.start()
        try:
            self.icon.visible = True
        except Exception:
            pass

    def stop(self) -> None:
        try:
            self.icon.stop()
        except Exception:
            pass

    @property
    def visible(self) -> bool:
        try:
            return bool(self.icon.visible)
        except Exception:
            return False

    @visible.setter
    def visible(self, value: bool) -> None:
        try:
            self.icon.visible = value
        except Exception:
            pass

    def __getattr__(self, item):
        return getattr(self.icon, item)


class TrayExtensionClient:
    """
    Client helper for the Flet tray extension (Flutter system_tray wrapper).

    Uses page.invoke_extension_method to send commands to the extension and
    routes extension events back to registered actions.
    """

    def __init__(self, page):
        self.page = page

    def _invoke(self, method: str, args: Optional[dict] = None):
        if hasattr(self.page, "invoke_extension_method"):
            try:
                self.page.invoke_extension_method(EXTENSION_NAME, method, args or {})
            except Exception as exc:
                print(f"Tray extension: invoke {method} failed ({exc})")
        elif hasattr(self.page, "invoke_extension"):
            try:
                self.page.invoke_extension(EXTENSION_NAME, method, args or {})
            except Exception as exc:
                print(f"Tray extension: invoke (legacy) {method} failed ({exc})")
        else:
            print("Tray extension: no invoke_extension_method / invoke_extension on page")

    def set_icon(self, path: str):
        self._invoke("setIcon", {"path": path or ""})

    def set_tooltip(self, text: str):
        self._invoke("setTooltip", {"text": text or ""})

    def set_menu(self, menu_nodes: Sequence[MenuNode] | Sequence[dict]):
        # accept already normalised dicts
        if menu_nodes and isinstance(menu_nodes[0], dict):  # type: ignore
            menu = menu_nodes  # type: ignore
        else:
            menu = menu_to_dict(menu_nodes)  # type: ignore
        self._invoke("setMenu", {"items": menu})

    def show_menu(self):
        self._invoke("showMenu")

    def destroy(self):
        self._invoke("destroy")


def register_extension(
    page,
    actions: Optional[Dict[str, ActionCallback]] = None,
) -> None:
    """
    Register the tray extension on a Flet page and wire events to action callbacks.

    This assumes Flet provides ``page.import_extension`` and an
    ``on_extension_event`` event. Calls are ignored if unavailable so the
    helper remains backwards compatible.
    """
    if actions:
        for name, fn in actions.items():
            register_action(name, fn)

    # load the extension on the frontend if supported
    if hasattr(page, "import_extension"):
        try:
            print(f"Tray extension: importing '{EXTENSION_NAME}'")
            page.import_extension(EXTENSION_NAME)
        except Exception as exc:
            print(f"tray extension import failed: {exc}")

    # wire events to the action registry
    if hasattr(page, "on_extension_event"):
        prev_handler = getattr(page, "on_extension_event", None)

        def _handle_ext(evt):
            if getattr(evt, "extension_name", None) and evt.extension_name != EXTENSION_NAME:
                if callable(prev_handler):
                    prev_handler(evt)
                return
            action_name = getattr(evt, "name", None) or getattr(evt, "action", None)
            payload = getattr(evt, "data", None)
            if isinstance(payload, str):
                try:
                    payload = json.loads(payload)
                except Exception:
                    pass
            if isinstance(payload, dict) and not action_name:
                action_name = payload.get("action")
            fn = _ACTIONS.get(action_name or "")
            if fn:
                try:
                    fn(payload)
                except Exception as exc:
                    print(f"tray extension handler '{action_name}' failed: {exc}")
            if callable(prev_handler):
                try:
                    prev_handler(evt)
                except Exception:
                    pass

        page.on_extension_event = _handle_ext
