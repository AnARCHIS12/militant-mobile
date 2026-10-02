import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:militant/services/language_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageService Notification Translations', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    const expectedKeys = [
      'notifications_push',
      'notifications_push_subtitle',
      'notifications_provider_title',
      'notifications_provider_ntfy',
      'notifications_provider_ntfy_subtitle',
      'notifications_provider_onesignal',
      'notifications_provider_onesignal_subtitle',
      'notifications_provider_both',
      'notifications_provider_both_subtitle',
      'test_notifications',
      'test_notifications_desc',
      'notification_test_sent',
      'notifications_likes',
      'notifications_comments',
      'notifications_messages',
      'notifications_friend_requests',
      'notifications_follows',
      'notifications_mentions',
    ];

    for (final langCode in ['fr', 'en', 'es']) {
      test('Language $langCode contains all notification translation keys with non-empty values', () async {
        final service = LanguageService.instance;
        await service.setLanguage(langCode);

        for (final key in expectedKeys) {
          final translation = service.translate(key);
          expect(
            translation,
            isNot(equals(key)),
            reason: 'Missing translation for key "$key" in language "$langCode"',
          );
          expect(
            translation.trim(),
            isNotEmpty,
            reason: 'Empty translation for key "$key" in language "$langCode"',
          );
        }
      });
    }

    test('English translations match expected terminology', () async {
      final service = LanguageService.instance;
      await service.setLanguage('en');

      expect(service.translate('notifications_provider_title'), equals('Notification Provider'));
      expect(service.translate('notifications_provider_ntfy'), contains('Self-hosted, DeGoogled'));
      expect(service.translate('notifications_provider_both'), contains('Dual delivery'));
      expect(service.translate('notification_test_sent'), contains('Test sent!'));
    });

    test('Spanish translations match expected terminology', () async {
      final service = LanguageService.instance;
      await service.setLanguage('es');

      expect(service.translate('notifications_provider_title'), equals('Proveedor de notificaciones'));
      expect(service.translate('notifications_provider_ntfy'), contains('Autohospedado, Desgooglizado'));
      expect(service.translate('notifications_provider_both'), contains('Doble difusión'));
      expect(service.translate('notification_test_sent'), contains('¡Prueba enviada!'));
    });
  });
}
