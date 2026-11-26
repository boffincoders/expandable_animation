import 'package:expandable_animation/expandable_animation.dart';
import 'package:flutter/material.dart';

import '../widgets/common.dart';

class AppNotification {
  const AppNotification(
      this.app, this.title, this.body, this.time, this.icon, this.color);

  final String app;
  final String title;
  final String body;
  final String time;
  final IconData icon;
  final Color color;
}

const List<AppNotification> notifications = <AppNotification>[
  AppNotification(
      'Calendar',
      'Design review in 15 minutes',
      'Room 4B · Bring the motion prototypes for the onboarding flow.',
      'now',
      Icons.event,
      Color(0xFFE53935)),
  AppNotification(
      'Messages',
      'Jordan Lee',
      'The new drag-to-dismiss feels great. Can we try a lower threshold?',
      '5m',
      Icons.chat_bubble,
      Color(0xFF43A047)),
  AppNotification(
      'Deliveries',
      'Your order is arriving',
      'The courier is two stops away. Estimated arrival 14:20.',
      '22m',
      Icons.local_shipping,
      Color(0xFF1E88E5)),
];

/// Compact notifications that expand into an interactive bottom sheet.
class NotificationsDemo extends StatelessWidget {
  const NotificationsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Expandable notifications',
      description: 'Each notification expands into a partial-height sheet '
          'with actions. This is sheet mode: the expanded view is anchored to '
          'the bottom edge and covers part of the screen.',
      child: Column(
        children: <Widget>[
          for (final AppNotification notification in notifications)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ExpandableAnimation(
                mode: const ExpandableAnimationMode.sheet(heightFactor: 0.55),
                borderRadius: BorderRadius.circular(20),
                expandedBorderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                collapsedColor:
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                expandedColor: Theme.of(context).colorScheme.surfaceContainer,
                semanticLabel: 'Open notification from ${notification.app}',
                expandedBuilder: (BuildContext context) =>
                    NotificationSheet(notification: notification),
                child: NotificationBanner(notification: notification),
              ),
            ),
        ],
      ),
    );
  }
}

class NotificationBanner extends StatelessWidget {
  const NotificationBanner({super.key, required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            backgroundColor: notification.color,
            foregroundColor: Colors.white,
            child: Icon(notification.icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(notification.app.toUpperCase(),
                          style: theme.textTheme.labelSmall),
                    ),
                    Text(notification.time, style: theme.textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: 2),
                Text(notification.title, style: theme.textTheme.titleSmall),
                Text(
                  notification.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key, required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: <Widget>[
            const DragHandle(),
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 26,
                  backgroundColor: notification.color,
                  foregroundColor: Colors.white,
                  child: Icon(notification.icon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(notification.app, style: theme.textTheme.labelLarge),
                      Text(notification.title,
                          style: theme.textTheme.titleLarge),
                    ],
                  ),
                ),
                const CollapseButton(),
              ],
            ),
            const SizedBox(height: 20),
            Text(notification.body, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Quick reply',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ExpandableAnimation.of(context).collapse(),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => ExpandableAnimation.of(context).collapse(),
                    child: const Text('Reply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
