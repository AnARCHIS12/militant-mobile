import 'package:flutter_test/flutter_test.dart';
import 'package:militant/services/notification_badge_service.dart';

void main() {
  group('NotificationBadgeService Tests', () {
    final badgeService = NotificationBadgeService.instance;

    setUp(() {
      badgeService.clear();
    });

    test('starts with unread count of 0 after clear', () {
      expect(badgeService.unreadCount.value, equals(0));
    });

    test('increment increases unread count by 1', () {
      badgeService.increment();
      expect(badgeService.unreadCount.value, equals(1));

      badgeService.increment();
      expect(badgeService.unreadCount.value, equals(2));
    });

    test('clear resets unread count to 0', () {
      badgeService.increment();
      badgeService.increment();
      expect(badgeService.unreadCount.value, equals(2));

      badgeService.clear();
      expect(badgeService.unreadCount.value, equals(0));
    });

    test('ValueNotifier notifies listeners on increment and clear', () {
      int notificationsReceived = 0;
      void listener() {
        notificationsReceived++;
      }

      badgeService.unreadCount.addListener(listener);

      badgeService.increment();
      expect(notificationsReceived, equals(1));

      badgeService.increment();
      expect(notificationsReceived, equals(2));

      badgeService.clear();
      expect(notificationsReceived, equals(3));

      badgeService.unreadCount.removeListener(listener);
    });
  });
}
