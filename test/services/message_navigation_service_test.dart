import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:militant/screens/chat_screen.dart';
import 'package:militant/screens/group_chat_screen.dart';
import 'package:militant/screens/post_detail_screen.dart';
import 'package:militant/screens/profile_screen.dart';
import 'package:militant/services/incoming_call_service.dart';
import 'package:militant/widgets/incoming_call_banner.dart';
import 'package:militant/services/message_navigation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessageNavigationService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      IncomingCallController.instance.stopListening();
    });

    testWidgets('handlePayload queues post notification when navigator is unmounted', (tester) async {
      final service = MessageNavigationService.instance;

      service.handlePayload({
        'type': 'comment',
        'post_id': 123,
      });

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      service.flushPendingNotification();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PostDetailScreen), findsOneWidget);
      appNavigatorKey.currentState?.pop();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('handlePayload routes directly to PostDetailScreen on comment', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      final service = MessageNavigationService.instance;
      service.handlePayload({
        'type': 'post_comment',
        'post_id': 456,
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PostDetailScreen), findsOneWidget);
      appNavigatorKey.currentState?.pop();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('handlePayload routes directly to PostDetailScreen on like/reaction', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      final service = MessageNavigationService.instance;
      service.handlePayload({
        'type': 'like',
        'post_id': 789,
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PostDetailScreen), findsOneWidget);
      appNavigatorKey.currentState?.pop();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('handlePayload routes to ChatScreen on private message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      final service = MessageNavigationService.instance;
      service.handlePayload({
        'type': 'message',
        'sender_id': 50,
        'username': 'JeanJaures',
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ChatScreen), findsOneWidget);

      appNavigatorKey.currentState?.pop();
      IncomingCallController.instance.stopListening();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('handlePayload routes to GroupChatScreen on group message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      final service = MessageNavigationService.instance;
      service.handlePayload({
        'type': 'group_message',
        'group_id': 12,
        'group_name': 'CNT-AIT',
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(GroupChatScreen), findsOneWidget);

      appNavigatorKey.currentState?.pop();
      IncomingCallController.instance.stopListening();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('handlePayload routes to ProfileScreen on follow or friend request', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      final service = MessageNavigationService.instance;
      service.handlePayload({
        'type': 'follow',
        'user_id': 77,
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ProfileScreen), findsOneWidget);
      appNavigatorKey.currentState?.pop();
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
