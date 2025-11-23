import 'dart:async';

import 'package:flutter/material.dart';

import 'menu_models.dart';
import 'tray_manager.dart';

/// Renders a lightweight popover anchored to the tray icon.
class TrayCardHost {
  final GlobalKey<NavigatorState>? navigatorKey;
  OverlayEntry? _entry;
  Timer? _timer;

  TrayCardHost({this.navigatorKey});

  Future<void> showCard(TrayCardConfig config, {void Function(TrayEvent)? onAction}) async {
    final context = navigatorKey?.currentContext;
    if (context == null) return;

    _entry?.remove();
    _timer?.cancel();

    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(onTap: hide, child: const ModalBarrier(color: Colors.transparent)),
          ),
          Positioned(
            right: 12,
            top: 32,
            child: _TrayCard(
              title: config.title,
              body: config.body,
              actions: config.actions,
              onAction: (action) {
                onAction?.call(
                  TrayEvent(
                    type: TrayEventType.cardAction,
                    id: action.id,
                    payload: {'label': action.label},
                  ),
                );
                hide();
              },
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_entry!);

    if (config.autoClose != null) {
      _timer = Timer(config.autoClose!, hide);
    }
  }

  void hide() {
    _entry?.remove();
    _entry = null;
    _timer?.cancel();
  }
}

class _TrayCard extends StatelessWidget {
  final String? title;
  final String? body;
  final List<TrayCardAction> actions;
  final void Function(TrayCardAction action) onAction;

  const _TrayCard({
    this.title,
    this.body,
    required this.actions,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 240),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(title!, style: Theme.of(context).textTheme.titleMedium),
                  ),
                if (body != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(body!, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                if (actions.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final action in actions)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ElevatedButton(
                            onPressed: () => onAction(action),
                            child: Text(action.label),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
