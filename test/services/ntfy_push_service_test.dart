import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:militant/services/ntfy_push_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NtfyPushService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'Push provider preferences defaults and storage on NtfyPushService',
      () async {
        final service = NtfyPushService.instance;

        // Par défaut, la version Play Store utilise OneSignal.
        final defaultProvider = await service.getSelectedProvider();
        expect(defaultProvider, equals(PushProvider.onesignal));

        // Modification vers onesignal
        await service.setSelectedProvider(PushProvider.onesignal);
        expect(
          await service.getSelectedProvider(),
          equals(PushProvider.onesignal),
        );

        // Modification vers both
        await service.setSelectedProvider(PushProvider.both);
        expect(await service.getSelectedProvider(), equals(PushProvider.both));
      },
    );

    test('Topic construction follows militant_u_<userId> convention', () {
      final service = NtfyPushService.instance;
      expect(service.serverUrl, contains('push.revlibertaire.com'));
      expect(service.topicPrefix, equals('militant_u_'));
    });

    test('Ntfy JSON decoding and actions extras extraction', () {
      const ntfyJson = '''
      {
        "id": "abc123xyz",
        "time": 1790944747,
        "event": "message",
        "topic": "militant_u_42",
        "title": "Nouveau commentaire",
        "message": "Bob a commenté votre post",
        "priority": 3,
        "tags": ["comment"],
        "actions": [
          {
            "action": "broadcast",
            "label": "Open",
            "clear": false,
            "extras": {
              "type": "comment",
              "post_id": 99,
              "link": "post.php?id=99"
            }
          }
        ]
      }
      ''';

      final decoded = jsonDecode(ntfyJson) as Map<String, dynamic>;
      expect(decoded['event'], equals('message'));
      expect(decoded['topic'], equals('militant_u_42'));
      expect(decoded['title'], equals('Nouveau commentaire'));

      final actions = decoded['actions'] as List;
      expect(actions, isNotEmpty);
      final extras = actions.first['extras'] as Map;
      expect(extras['type'], equals('comment'));
      expect(extras['post_id'], equals(99));
      expect(extras['link'], equals('post.php?id=99'));
    });

    test('Ntfy call payload extraction with priority 5', () {
      const callJson = '''
      {
        "id": "call987",
        "event": "message",
        "topic": "militant_u_42",
        "title": "Appel entrant",
        "message": "Alice vous appelle",
        "priority": 5,
        "tags": ["phone", "incoming_call"],
        "actions": [
          {
            "action": "broadcast",
            "extras": {
              "type": "call",
              "call_id": "c_12345",
              "caller_id": 10,
              "caller_name": "Alice"
            }
          }
        ]
      }
      ''';

      final decoded = jsonDecode(callJson) as Map<String, dynamic>;
      expect(decoded['priority'], equals(5));
      expect(decoded['tags'], contains('incoming_call'));

      final extras = (decoded['actions'] as List).first['extras'] as Map;
      expect(extras['type'], equals('call'));
      expect(extras['call_id'], equals('c_12345'));
      expect(extras['caller_name'], equals('Alice'));
    });
  });
}
