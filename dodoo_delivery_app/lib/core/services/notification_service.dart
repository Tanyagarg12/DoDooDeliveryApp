import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_center.dart';

/// Wrapper around flutter_local_notifications for in-app push banners.
///
/// Each [NotificationType] uses its own Android channel so it can carry a
/// distinct sound. Every shown notification is also recorded in
/// [NotificationCenter] for the in-app history + unread badge.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );

    // Android 13+ requires explicit runtime permission, or notifications (and
    // their sound) never appear. Best-effort — older Androids return null.
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {/* not on Android / not supported */}

    await NotificationCenter.instance.load();
    _initialized = true;
  }

  /// Shows an OS notification on [type]'s channel and records it in history.
  /// Set [record] false to only show without storing (rarely needed).
  Future<void> notify({
    required NotificationType type,
    required String title,
    required String body,
    int? id,
    bool record = true,
  }) async {
    if (!_initialized) await init();

    final sound = type.soundName;
    final android = AndroidNotificationDetails(
      type.channelId,
      type.channelName,
      channelDescription: type.channelName,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: sound == null ? null : RawResourceAndroidNotificationSound(sound),
    );
    final ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: sound == null ? null : '$sound.caf',
    );
    await _plugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );

    if (record) {
      await NotificationCenter.instance
          .add(type: type, title: title, body: body);
    }
  }

  // ── Convenience wrappers (typed) ─────────────────────────────────────────

  Future<void> showNewOrder({
    required String title,
    required String body,
    int id = 0,
  }) =>
      notify(type: NotificationType.newOrder, title: title, body: body, id: id);

  Future<void> showOrderAssigned({required String title, required String body}) =>
      notify(type: NotificationType.orderAssigned, title: title, body: body);

  Future<void> showPayment({required String title, required String body}) =>
      notify(type: NotificationType.payment, title: title, body: body);

  Future<void> showApproval({required String title, required String body}) =>
      notify(type: NotificationType.approval, title: title, body: body);

  Future<void> showSupportMessage({required String title, required String body}) =>
      notify(type: NotificationType.support, title: title, body: body);

  /// Reminder shown when a rider has been offline longer than configured.
  Future<void> showOfflineReminder() => notify(
        type: NotificationType.general,
        title: 'Still offline?',
        body: 'You have been offline for a while. Would you like to go online?',
        id: 90001,
      );

  /// Cancels a single notification (e.g. an offer taken by another rider).
  Future<void> cancel(int id) async {
    if (!_initialized) return;
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }
}
