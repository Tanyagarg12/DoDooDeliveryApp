import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Categories of notifications. Each maps to its own Android channel (so it can
/// carry a distinct sound) and an icon/label for the in-app history list.
enum NotificationType { newOrder, orderAssigned, payment, support, approval, general }

extension NotificationTypeInfo on NotificationType {
  // NOTE: a channel's sound is fixed when Android first creates it. To change
  // the sound on devices that already have the app, the channel id must change
  // — hence the "_v2" suffix on the sound-carrying channels.
  String get channelId => switch (this) {
        NotificationType.newOrder => 'new_orders_channel_v2',
        NotificationType.orderAssigned => 'order_assigned_channel_v2',
        NotificationType.payment => 'payment_channel',
        NotificationType.support => 'support_channel',
        NotificationType.approval => 'approval_channel',
        NotificationType.general => 'general_channel',
      };

  String get channelName => switch (this) {
        NotificationType.newOrder => 'New Orders',
        NotificationType.orderAssigned => 'Order Assigned',
        NotificationType.payment => 'Payments',
        NotificationType.support => 'Support Messages',
        NotificationType.approval => 'Account Updates',
        NotificationType.general => 'General',
      };

  /// Custom sound file (WITHOUT extension) placed in
  /// android/app/src/main/res/raw/. When null the channel uses the system
  /// default sound.
  ///
  /// `new_order` maps to android/app/src/main/res/raw/new_order.mp3 — replace
  /// that file (keep the same name) to change the new-order alert tone.
  String? get soundName => switch (this) {
        NotificationType.newOrder => 'new_order',
        NotificationType.orderAssigned => 'new_order',
        NotificationType.payment => null,
        NotificationType.support => null,
        NotificationType.approval => null,
        NotificationType.general => null,
      };

  String get storageKey => name;

  static NotificationType fromName(String? n) =>
      NotificationType.values.firstWhere((t) => t.name == n,
          orElse: () => NotificationType.general);
}

/// A stored notification for the in-app history list.
class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timeMillis,
    this.read = false,
  });

  final int id;
  final NotificationType type;
  final String title;
  final String body;
  final int timeMillis;
  bool read;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'time': timeMillis,
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] as num).toInt(),
        type: NotificationTypeInfo.fromName(j['type'] as String?),
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        timeMillis: (j['time'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        read: j['read'] == true,
      );

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timeMillis);
}

/// Singleton store for the notification history + unread badge. Persisted to
/// shared_preferences so it survives restarts. UI listens to [notifier].
class NotificationCenter {
  NotificationCenter._();
  static final NotificationCenter instance = NotificationCenter._();

  static const _prefsKey = 'notification_history_v1';
  static const _maxItems = 100;

  final ValueNotifier<List<AppNotification>> notifier =
      ValueNotifier<List<AppNotification>>([]);

  bool _loaded = false;

  int get unreadCount => notifier.value.where((n) => !n.read).length;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        notifier.value = list;
      }
    } catch (_) {/* start empty */}
  }

  Future<void> add({
    required NotificationType type,
    required String title,
    required String body,
  }) async {
    await load();
    final item = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      type: type,
      title: title,
      body: body,
      timeMillis: DateTime.now().millisecondsSinceEpoch,
    );
    final updated = [item, ...notifier.value];
    if (updated.length > _maxItems) updated.removeRange(_maxItems, updated.length);
    notifier.value = updated;
    await _save();
  }

  Future<void> markAllRead() async {
    await load();
    for (final n in notifier.value) {
      n.read = true;
    }
    notifier.value = List.of(notifier.value);
    await _save();
  }

  Future<void> clear() async {
    notifier.value = [];
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(notifier.value.map((e) => e.toJson()).toList()),
      );
    } catch (_) {/* best-effort */}
  }
}
