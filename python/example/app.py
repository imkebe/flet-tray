"""Minimal Python Flet app using the tray extension helper."""
from __future__ import annotations

import asyncio
import flet as ft
from flet_tray import TrayClient, TrayMenuItem, connect_tray


def main(page: ft.Page):
    page.title = "Tray extension demo"
    page.theme_mode = ft.ThemeMode.LIGHT

    async def setup_tray():
        tray: TrayClient = await connect_tray(page)
        await tray.init(icon="assets/icon.png", tooltip="Tray is running")
        await tray.set_menu(
            [
                TrayMenuItem(id="open", label="Open window"),
                TrayMenuItem(id="sep1", type="separator"),
                TrayMenuItem(id="quit", label="Quit"),
            ]
        )

        def on_menu(e):
            match e.get("id"):
                case "open":
                    page.show_snack_bar(ft.SnackBar(ft.Text("Open clicked")))
                case "quit":
                    page.window_close()

        tray.on_menu_item_click(on_menu)

    asyncio.create_task(setup_tray())

    page.add(ft.Text("Tray extension connected; interact via the system tray."))


if __name__ == "__main__":
    ft.app(target=main)
