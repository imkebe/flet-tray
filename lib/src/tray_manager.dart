import 'dart:async';

import 'package:system_tray/system_tray.dart';

import 'menu_models.dart';

enum TrayEventType { menuItem, trayClick, cardAction }

class TrayEvent {
  final TrayEventType type;
  final String id;
  final Map<String, dynamic> payload;

  TrayEvent({required this.type, required this.id, this.payload = const {}});
}

class TrayManager {
  final SystemTray _tray = SystemTray();
  final Menu _menu = Menu();
  final StreamController<TrayEvent> _events = StreamController.broadcast();
  bool _initialized = false;

  Stream<TrayEvent> get events => _events.stream;

  Future<void> initialize({
    required String iconPath,
    String? tooltip,
    bool isTemplate = false,
  }) async {
    if (_initialized) return;

    await _tray.initSystemTray(
      title: '',
      iconPath: iconPath,
      isTemplate: isTemplate,
      toolTip: tooltip,
    );

    await _tray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        _events.add(TrayEvent(type: TrayEventType.trayClick, id: 'click'));
      }
    });

    _initialized = true;
  }

  Future<void> setTooltip(String? tooltip) async {
    if (!_initialized) return;
    await _tray.setToolTip(tooltip ?? '');
  }

  Future<void> setMenu(TrayMenu menu) async {
    if (!_initialized) {
      throw StateError('Tray not initialized');
    }

    _menu.items.clear();
    _menu.items.addAll(menu.items.map(_toMenuItem));
    await _tray.setContextMenu(_menu);
  }

  MenuItemBase _toMenuItem(TrayMenuItem item) {
    switch (item.type) {
      case TrayMenuItemType.separator:
        return MenuSeparator();
      case TrayMenuItemType.check:
        return MenuItemCheck(
          label: item.label,
          isChecked: item.checked,
          enabled: item.enabled,
          onClicked: (item) {
            _events.add(TrayEvent(type: TrayEventType.menuItem, id: item.id));
          },
          id: item.id,
        );
      case TrayMenuItemType.item:
        if (item.hasChildren) {
          return MenuItemSubmenu(
            label: item.label,
            enabled: item.enabled,
            id: item.id,
            children: item.children.map(_toMenuItem).toList(),
          );
        }
        return MenuItemLabel(
          label: item.label,
          enabled: item.enabled,
          id: item.id,
          onClicked: (item) {
            _events.add(TrayEvent(type: TrayEventType.menuItem, id: item.id));
          },
        );
    }
  }

  Future<void> popUpContextMenu() => _tray.popUpContextMenu();

  Future<void> dispose() async {
    await _tray.destroy();
    await _events.close();
    _initialized = false;
  }
}
