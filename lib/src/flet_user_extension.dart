import 'dart:async';

import 'package:flet/flet.dart' as flet;

import 'extension_api.dart';
import 'tray_extension.dart' as impl;

/// Bridges the tray implementation to Flet's user-extension lifecycle.
class TrayUserExtension extends flet.UserExtension {
  late final InlineExtensionRegistry _registry;
  late final impl.TrayExtension _impl;
  StreamSubscription<ExtensionEvent>? _eventsSub;

  @override
  String get name => "tray";

  @override
  void init(flet.UserExtensionContext context) {
    _registry = InlineExtensionRegistry();
    _impl = impl.TrayExtension(navigatorKey: context.navigatorKey);
    _impl.register(_registry);

    // Forward actions coming from Flet to the inline registry.
    for (final entry in _registry.actions.entries) {
      context.addAction(entry.key, (args) => entry.value(args, _emitEvent));
    }

    // Emit events from the tray manager back to Flet runtime.
    _eventsSub = _registry.events.listen((event) {
      context.emitEvent(event.name, event.payload);
    });
  }

  @override
  Future<void> dispose() async {
    await _registry.dispatch('dispose', {});
    await _eventsSub?.cancel();
  }

  void _emitEvent(ExtensionEvent event) {
    _registry.emit(event.name, event.payload);
  }
}

/// Helper called by Flet to register the tray extension.
void registerExtensions() {
  flet.Extensions.instance.registerExtension(TrayUserExtension());
}
