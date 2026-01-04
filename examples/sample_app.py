import flet as ft

from flet_tray import TrayApp, register_extension, register_action


def main(page: ft.Page):
    # import/bridge the tray extension when supported
    register_extension(
        page,
        actions={
            "open": lambda *_: print("tray open clicked"),
            "exit": lambda *_: page.window_close(),
            "hello": lambda *_: print("hello from tray"),
        },
    )

    # extra action used by the menu below
    register_action("toggle_theme", lambda *_: setattr(page, "theme_mode", ft.ThemeMode.DARK if page.theme_mode != ft.ThemeMode.DARK else ft.ThemeMode.LIGHT))

    tray = TrayApp(
        name="flet_tray_demo",
        title="Flet Tray Demo",
        icon_path="icons/icon_128x128.png",
        on_open=lambda *_: print("open requested"),
        on_exit=lambda *_: page.window_close(),
        menu=[
            {"text": "Say hello", "action": "hello"},
            {"text": "Toggle theme", "action": "toggle_theme"},
            {"text": "Open", "action": "open"},
            {"text": "Exit", "action": "exit"},
        ],
    )
    tray.start(mac=page.platform == "macos")

    page.add(ft.Text("Tray extension demo running…"))


if __name__ == "__main__":
    ft.app(target=main, view=ft.AppView.FLET_APP)
