import 'dart:async';

/// A lightweight registry to mirror the Flet 1.0-alpha extension shape.
///
/// Hosts can wire this registry into their platform channel or message bus and
/// dispatch calls by name with a payload.
class InlineExtensionRegistry {
  final Map<String, ExtensionActionHandler> _handlers = {};
  final StreamController<ExtensionEvent> _events = StreamController.broadcast();

  Stream<ExtensionEvent> get events => _events.stream;

  Map<String, ExtensionActionHandler> get actions => Map.unmodifiable(_handlers);

  /// Registers a handler for a given action name.
  void registerAction(String name, ExtensionActionHandler handler) {
    _handlers[name] = handler;
  }

  /// Registers multiple actions at once.
  void registerActions(Map<String, ExtensionActionHandler> handlers) {
    handlers.forEach(registerAction);
  }

  /// Dispatches an action and returns its result payload.
  Future<ExtensionActionResult> dispatch(String name, Map<String, dynamic> args) async {
    final handler = _handlers[name];
    if (handler == null) {
      return ExtensionActionResult.error('Unknown action: $name');
    }
    return handler(args, _events.add);
  }

  /// Utility to emit events.
  void emit(String name, Map<String, dynamic> payload) {
    _events.add(ExtensionEvent(name, payload));
  }
}

class ExtensionEvent {
  final String name;
  final Map<String, dynamic> payload;

  ExtensionEvent(this.name, this.payload);
}

typedef ExtensionActionHandler = Future<ExtensionActionResult> Function(
  Map<String, dynamic> args,
  ExtensionEventEmitter emit,
);

typedef ExtensionEventEmitter = void Function(ExtensionEvent event);

class ExtensionActionResult {
  final bool ok;
  final String? error;
  final Map<String, dynamic>? data;

  ExtensionActionResult._(this.ok, this.error, this.data);

  factory ExtensionActionResult.success([Map<String, dynamic>? data]) =>
      ExtensionActionResult._(true, null, data);

  factory ExtensionActionResult.error(String message) =>
      ExtensionActionResult._(false, message, null);
}
