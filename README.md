# Flet Tray Extension (alpha)

This repository hosts an experimental Flet 1.0-alpha extension that exposes cross-platform system tray features for macOS, Windows 10+, and GTK-like Linux desktops. The extension wraps the [`system_tray`](https://pub.dev/packages/system_tray) package and aligns with the extension guidance in the Flet 1.0-alpha series.

## Features

- Initialize a native tray icon with tooltip and platform-appropriate assets (PNG/ICO/SVG templates).
- Render hierarchical native menus with separators and checkable items.
- Emit menu item and tray click events back to Flet.
- Optional lightweight custom card/popover rendered from Flutter widgets, anchored near the tray icon.
- Graceful disposal and hot-reload friendly re-initialization.

## Package layout

- `lib/` – core extension implementation and tray manager.
- `example/` – minimal Flutter/Flet bootstrap showing how to wire the extension.
- `README.md` – this guide.

## Getting started

1. Add the dependency to your Flet-hosted Flutter project:

   ```yaml
   dependencies:
     flet: ^1.0.0-alpha.0
     flet_tray_extension:
       path: ../flet-tray
   ```

2. Register the user extension before running your `FletApp` so `page.import_extension("tray")` can find it:

   ```dart
   import 'package:flet/flet.dart';
   import 'package:flet_tray_extension/flet_tray_extension.dart';

   void main() {
     WidgetsFlutterBinding.ensureInitialized();

     // Registers the tray extension with the Flet runtime using the default name "tray".
     registerExtensions();

     runApp(const FletApp(pageUrl: 'http://localhost:8550'));
   }
   ```

3. From Python (or JS) Flet code, import and interact with the extension via the registered name `tray`. A thin Python helper lives in `python/flet_tray/__init__.py` so apps can avoid hand-crafting payloads:

   ```python
   from flet_tray import TrayMenuItem, connect_tray

   async def main(page):
       tray = await connect_tray(page)
       await tray.init(icon="assets/icon.png", tooltip="Running")
       await tray.set_menu([
           TrayMenuItem(id="open", label="Open"),
           TrayMenuItem(id="sep1", type="separator"),
           TrayMenuItem(id="quit", label="Quit"),
       ])

       tray.on_menu_item_click(lambda e: print(f"menu click: {e['id']}"))
   ```

4. Optional: show a custom popover card built in Flutter:

   ```python
   await tray.show_card(
       title="Hello",
       body="This is a custom tray card",
       actions=[{"id": "ack", "label": "OK"}],
   )
   ```

## Platform notes

- **macOS**: prefer monochrome template icons and provide `@2x` assets. Menus are rendered on the UI isolate. Ensure the icon path points to a bundled asset (for `flet pack` you can place it under `assets/` and reference it as `assets/icon.png`).
- **Windows**: supply an `.ico` with multiple resolutions. Checkable items rely on the shell menu flags provided by `system_tray`.
- **Linux**: AppIndicator and legacy trays are supported by `system_tray`; on DEs without tray support the extension reports an error on init.

## Python helper & example

The `python/` directory ships a lightweight async client (`flet_tray.TrayClient`) plus a runnable Flet sample in `python/example/app.py`. Run it with:

```bash
python python/example/app.py
```

## License

This project is licensed under the terms of the MIT license.
