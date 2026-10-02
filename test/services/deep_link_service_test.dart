import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:militant/screens/post_detail_screen.dart';
import 'package:militant/screens/profile_screen.dart';
import 'package:militant/services/incoming_call_service.dart';
import 'package:militant/services/deep_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeepLinkService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('handleLinkString parses web post URL and navigates to PostDetailScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      final service = DeepLinkService();
      await service.handleLinkString('https://militant.revlibertaire.com/post.php?id=123');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PostDetailScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('handleLinkString parses path-based post URL /post/456', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      final service = DeepLinkService();
      await service.handleLinkString('https://militant.revlibertaire.com/post/456');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PostDetailScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('handleLinkString parses short path /p/789', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      final service = DeepLinkService();
      await service.handleLinkString('https://militant.revlibertaire.com/p/789');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PostDetailScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('handleLinkString parses group URL with #post-99 fragment and targets the post', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      final service = DeepLinkService();
      await service.handleLinkString('https://militant.revlibertaire.com/group_detail.php?id=5#post-99');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PostDetailScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('handleLinkString parses profile link and navigates to ProfileScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      final service = DeepLinkService();
      await service.handleLinkString('https://militant.revlibertaire.com/profile.php?id=42');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ProfileScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('handleLinkString parses custom scheme militant://post/202', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      final service = DeepLinkService();
      await service.handleLinkString('militant://post/202');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PostDetailScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('handleLinkString queues pending deep link when navigator is null', (tester) async {
      final service = DeepLinkService();

      // Avant le montage de l'arbre
      await service.handleLinkString('https://militant.revlibertaire.com/post.php?id=333');

      // Montage ultérieur de l'application
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      // Vidage de la file d'attente
      service.flushPendingDeepLink();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PostDetailScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
