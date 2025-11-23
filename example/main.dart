import 'package:flutter/material.dart';

import 'package:flet/flet.dart';
import 'package:flet_tray_extension/flet_tray_extension.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register the tray extension so Flet pages can call `import_extension("tray")`.
  registerExtensions();

  runApp(TrayDemoApp());
}

class TrayDemoApp extends StatefulWidget {
  const TrayDemoApp({super.key});

  @override
  State<TrayDemoApp> createState() => _TrayDemoAppState();
}

class _TrayDemoAppState extends State<TrayDemoApp> {
  final navigatorKey = GlobalKey<NavigatorState>();
  final registry = InlineExtensionRegistry();

  @override
  void initState() {
    super.initState();
    _bootstrapTray();
  }

  Future<void> _bootstrapTray() async {
    final trayExtension = TrayExtension(navigatorKey: navigatorKey);
    trayExtension.register(registry);

    await registry.dispatch('init', {
      'icon': 'assets/app_icon.png',
      'tooltip': 'Flet tray demo',
      'is_template': false,
    });

    await registry.dispatch('set_menu', {
      'items': [
        {'id': 'open', 'label': 'Open'},
        {'id': 'sep', 'type': 'separator'},
        {'id': 'card', 'label': 'Show card'},
        {'id': 'quit', 'label': 'Quit'},
      ],
    });

    registry.events.listen((event) {
      if (event.name == 'menu_item_click') {
        switch (event.payload['id']) {
          case 'card':
            registry.dispatch('show_card', {
              'title': 'Hello from tray',
              'body': 'This card is rendered in Flutter and wired to the tray.',
              'actions': [
                {'id': 'ok', 'label': 'OK'},
              ],
              'auto_close_ms': 6000,
            });
            break;
          case 'quit':
            registry.dispatch('dispose', {});
            break;
          default:
            break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: Scaffold(
        appBar: AppBar(title: const Text('Flet tray extension demo')),
        body: const Center(
          child: Text('The tray demo runs in the background. Use the tray menu.'),
        ),
      ),
    );
  }
}
