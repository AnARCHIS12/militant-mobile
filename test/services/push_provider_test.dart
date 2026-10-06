import 'package:flutter_test/flutter_test.dart';
import 'package:militant/services/ntfy_push_service.dart';

void main() {
  group('PushProvider', () {
    test('utilise OneSignal par défaut pour la version Play Store', () {
      expect(PushProvider.isFdroidBuild, isFalse);
      expect(PushProvider.fromString(null), PushProvider.onesignal);
      expect(PushProvider.fromString(''), PushProvider.onesignal);
    });

    test('conserve un choix explicite valide', () {
      expect(PushProvider.fromString('ntfy'), PushProvider.ntfy);
      expect(PushProvider.fromString('onesignal'), PushProvider.onesignal);
      expect(PushProvider.fromString('both'), PushProvider.both);
    });

    test('revient à OneSignal si la préférence stockée est invalide', () {
      expect(PushProvider.fromString('inconnu'), PushProvider.onesignal);
    });
  });
}
