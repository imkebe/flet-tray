import 'dart:async';

import 'package:flutter/material.dart';

import 'extension_api.dart';
import 'menu_models.dart';
import 'tray_card_host.dart';
import 'tray_manager.dart';

class TrayExtension {
  final TrayManager _manager = TrayManager();
  final TrayCardHost _cardHost;
  StreamSubscription<TrayEvent>? _subscription;

  TrayExtension({GlobalKey<NavigatorState>? navigatorKey})
      : _cardHost = TrayCardHost(navigatorKey: navigatorKey);

  Map<String, ExtensionActionHandler> get actions => {
        'init': _init,
        'set_menu': _setMenu,
        'set_tooltip': _setTooltip,
        'show_card': _showCard,
        'popup_menu': _popupMenu,
        'dispose': _dispose,
      };

  void register(InlineExtensionRegistry registry) {
    registry.registerActions(actions);
    _subscription ??= _manager.events.listen((event) {
      registry.emit(_eventName(event), {
        'id': event.id,
        ...event.payload,
      });
    });
  }

  Future<ExtensionActionResult> _init(Map<String, dynamic> args, ExtensionEventEmitter emit) async {
    try {
      await _manager.initialize(
        iconPath: args['icon'] as String,
        tooltip: args['tooltip'] as String?,
        isTemplate: args['is_template'] as bool? ?? false,
      );
      return ExtensionActionResult.success();
    } catch (err) {
      return ExtensionActionResult.error('init failed: $err');
    }
  }

  Future<ExtensionActionResult> _setMenu(
    Map<String, dynamic> args,
    ExtensionEventEmitter emit,
  ) async {
    try {
      final menu = TrayMenu.fromJson(args);
      await _manager.setMenu(menu);
      return ExtensionActionResult.success();
    } catch (err) {
      return ExtensionActionResult.error('set_menu failed: $err');
    }
  }

  Future<ExtensionActionResult> _setTooltip(
    Map<String, dynamic> args,
    ExtensionEventEmitter emit,
  ) async {
    await _manager.setTooltip(args['tooltip'] as String?);
    return ExtensionActionResult.success();
  }

  Future<ExtensionActionResult> _popupMenu(
    Map<String, dynamic> args,
    ExtensionEventEmitter emit,
  ) async {
    await _manager.popUpContextMenu();
    return ExtensionActionResult.success();
  }

  Future<ExtensionActionResult> _showCard(
    Map<String, dynamic> args,
    ExtensionEventEmitter emit,
  ) async {
    final config = TrayCardConfig.fromJson(args);
    await _cardHost.showCard(config, onAction: (event) {
      emit(ExtensionEvent(_eventName(event), {'id': event.id, ...event.payload}));
    });
    return ExtensionActionResult.success();
  }

  Future<ExtensionActionResult> _dispose(
    Map<String, dynamic> args,
    ExtensionEventEmitter emit,
  ) async {
    await _subscription?.cancel();
    await _manager.dispose();
    return ExtensionActionResult.success();
  }

  String _eventName(TrayEvent event) {
    switch (event.type) {
      case TrayEventType.menuItem:
        return 'menu_item_click';
      case TrayEventType.trayClick:
        return 'tray_click';
      case TrayEventType.cardAction:
        return 'card_action';
    }
  }
}
