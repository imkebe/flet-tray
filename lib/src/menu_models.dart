class TrayMenu {
  final List<TrayMenuItem> items;

  const TrayMenu({required this.items});

  factory TrayMenu.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? [])
        .map((item) => TrayMenuItem.fromJson(item as Map<String, dynamic>))
        .toList();
    return TrayMenu(items: rawItems);
  }
}

enum TrayMenuItemType { item, separator, check }

class TrayMenuItem {
  final String id;
  final String label;
  final TrayMenuItemType type;
  final bool enabled;
  final bool checked;
  final List<TrayMenuItem> children;

  const TrayMenuItem({
    required this.id,
    required this.label,
    this.type = TrayMenuItemType.item,
    this.enabled = true,
    this.checked = false,
    this.children = const [],
  });

  bool get hasChildren => children.isNotEmpty;

  factory TrayMenuItem.fromJson(Map<String, dynamic> json) {
    final children = (json['items'] ?? json['children']) as List<dynamic>? ?? [];
    return TrayMenuItem(
      id: json['id'] as String,
      label: json['label'] as String? ?? json['id'] as String,
      type: _typeFromString(json['type'] as String? ?? 'item'),
      enabled: json['enabled'] as bool? ?? true,
      checked: json['checked'] as bool? ?? false,
      children: children
          .map((child) => TrayMenuItem.fromJson(child as Map<String, dynamic>))
          .toList(),
    );
  }

  static TrayMenuItemType _typeFromString(String value) {
    switch (value) {
      case 'separator':
        return TrayMenuItemType.separator;
      case 'check':
      case 'checkbox':
        return TrayMenuItemType.check;
      default:
        return TrayMenuItemType.item;
    }
  }
}

class TrayCardAction {
  final String id;
  final String label;

  const TrayCardAction({required this.id, required this.label});

  factory TrayCardAction.fromJson(Map<String, dynamic> json) => TrayCardAction(
        id: json['id'] as String,
        label: json['label'] as String? ?? json['id'] as String,
      );
}

class TrayCardConfig {
  final String? title;
  final String? body;
  final List<TrayCardAction> actions;
  final Duration? autoClose;

  const TrayCardConfig({this.title, this.body, this.actions = const [], this.autoClose});

  factory TrayCardConfig.fromJson(Map<String, dynamic> json) {
    return TrayCardConfig(
      title: json['title'] as String?,
      body: json['body'] as String?,
      autoClose: json['auto_close_ms'] != null
          ? Duration(milliseconds: json['auto_close_ms'] as int)
          : null,
      actions: (json['actions'] as List<dynamic>? ?? [])
          .map((raw) => TrayCardAction.fromJson(raw as Map<String, dynamic>))
          .toList(),
    );
  }
}
