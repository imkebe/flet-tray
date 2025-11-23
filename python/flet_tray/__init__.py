"""Python helper for the flet-tray extension.

This module provides a thin async wrapper around Flet's extension API so
apps can easily initialize the tray, wire up menus, and react to events.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Awaitable, Callable, Dict, Iterable, Optional

import flet as ft

TrayEventHandler = Callable[[Dict[str, Any]], Any]


def _merge_if(value: Optional[Any], key: str, target: Dict[str, Any]) -> None:
    if value is not None:
        target[key] = value


@dataclass
class TrayMenuItem:
    """Represents a single menu item mapping for the extension."""

    id: str
    label: Optional[str] = None
    type: str = "item"  # "item", "separator", or "checkable"
    checked: Optional[bool] = None
    enabled: Optional[bool] = None
    children: Optional[Iterable["TrayMenuItem"]] = None

    def to_json(self) -> Dict[str, Any]:
        data: Dict[str, Any] = {"id": self.id, "type": self.type}
        _merge_if(self.label, "label", data)
        _merge_if(self.checked, "checked", data)
        _merge_if(self.enabled, "enabled", data)
        if self.children:
            data["items"] = [child.to_json() for child in self.children]
        return data


class TrayClient:
    """Async wrapper for the registered tray extension instance."""

    def __init__(self, ext: ft.Extension):
        self._ext = ext

    @classmethod
    async def connect(cls, page: ft.Page, name: str = "tray") -> "TrayClient":
        """Imports the tray extension and returns a connected client."""

        ext = await page.import_extension(name)
        return cls(ext)

    # ----- actions -----
    async def init(
        self,
        icon: str,
        tooltip: Optional[str] = None,
        *,
        is_template: bool = False,
    ) -> Dict[str, Any]:
        payload: Dict[str, Any] = {"icon": icon, "is_template": is_template}
        _merge_if(tooltip, "tooltip", payload)
        return await self._ext.call_action("init", payload)

    async def set_menu(self, items: Iterable[TrayMenuItem]) -> Dict[str, Any]:
        payload = {"items": [item.to_json() for item in items]}
        return await self._ext.call_action("set_menu", payload)

    async def set_tooltip(self, tooltip: Optional[str]) -> Dict[str, Any]:
        return await self._ext.call_action("set_tooltip", {"tooltip": tooltip})

    async def popup_menu(self) -> Dict[str, Any]:
        return await self._ext.call_action("popup_menu", {})

    async def show_card(
        self,
        *,
        title: Optional[str] = None,
        body: Optional[str] = None,
        actions: Optional[Iterable[Dict[str, str]]] = None,
    ) -> Dict[str, Any]:
        payload: Dict[str, Any] = {}
        _merge_if(title, "title", payload)
        _merge_if(body, "body", payload)
        if actions is not None:
            payload["actions"] = list(actions)
        return await self._ext.call_action("show_card", payload)

    async def dispose(self) -> Dict[str, Any]:
        return await self._ext.call_action("dispose", {})

    # ----- events -----
    def on_menu_item_click(self, handler: TrayEventHandler) -> Callable[[], Awaitable[None]]:
        return self._ext.listen("menu_item_click", handler)

    def on_tray_click(self, handler: TrayEventHandler) -> Callable[[], Awaitable[None]]:
        return self._ext.listen("tray_click", handler)

    def on_card_action(self, handler: TrayEventHandler) -> Callable[[], Awaitable[None]]:
        return self._ext.listen("card_action", handler)


async def connect_tray(page: ft.Page, name: str = "tray") -> TrayClient:
    """Convenience helper to connect to the tray extension."""

    return await TrayClient.connect(page, name=name)
