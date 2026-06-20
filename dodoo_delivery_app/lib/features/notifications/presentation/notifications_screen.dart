import 'package:flutter/material.dart';

import '../../../core/services/notification_center.dart';
import '../../../core/theme/app_theme.dart';

IconData iconForType(NotificationType t) => switch (t) {
      NotificationType.newOrder => Icons.delivery_dining_rounded,
      NotificationType.orderAssigned => Icons.assignment_turned_in_rounded,
      NotificationType.payment => Icons.payments_rounded,
      NotificationType.support => Icons.support_agent_rounded,
      NotificationType.approval => Icons.verified_rounded,
      NotificationType.general => Icons.notifications_rounded,
    };

Color colorForType(NotificationType t) => switch (t) {
      NotificationType.newOrder => AppColors.busy,
      NotificationType.orderAssigned => AppColors.primary,
      NotificationType.payment => AppColors.online,
      NotificationType.support => AppColors.accent,
      NotificationType.approval => AppColors.online,
      NotificationType.general => AppColors.offline,
    };

/// Bell icon with an unread badge. Drop into any AppBar `actions:`.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: NotificationCenter.instance.notifier,
      builder: (context, items, _) {
        final unread = items.where((n) => !n.read).length;
        return IconButton(
          tooltip: 'Notifications',
          color: color,
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_rounded),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        );
      },
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the screen marks everything read (clears the badge).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationCenter.instance.markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => NotificationCenter.instance.clear(),
            child: const Text('Clear all'),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<AppNotification>>(
        valueListenable: NotificationCenter.instance.notifier,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_rounded,
                      size: 48, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No notifications yet',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _NotificationTile(item: items[i]),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});
  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final color = colorForType(item.type);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.read
            ? (isDark ? AppColors.cardDark : Colors.white)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.read
              ? (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE8F0EE))
              : color.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconForType(item.type), color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    if (!item.read)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(item.body,
                    style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(_relativeTime(item.time),
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }
}
