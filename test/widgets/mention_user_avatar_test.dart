import 'package:flutter_test/flutter_test.dart';
import 'package:militant/services/api_service.dart';
import 'package:militant/widgets/mention_user_avatar.dart';

void main() {
  final api = ApiService(baseUrl: 'https://api.militant.revlibertaire.com');

  test('résout l’avatar renvoyé par la recherche de mentions', () {
    expect(
      resolveMentionAvatarUrl({'avatar': 'avatar_42.jpg'}, api),
      'https://militant.revlibertaire.com/uploads/avatar_42.jpg',
    );
  });

  test('accepte les noms de champ avatar compatibles', () {
    expect(
      resolveMentionAvatarUrl({'user_avatar': 'avatar_7.webp'}, api),
      'https://militant.revlibertaire.com/uploads/avatar_7.webp',
    );
  });

  test('utilise le logo de secours pour l’avatar par défaut', () {
    expect(resolveMentionAvatarUrl({'avatar': 'default.svg'}, api), isNull);
  });
}
