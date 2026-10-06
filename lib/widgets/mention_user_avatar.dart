import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/api_service.dart';

String? resolveMentionAvatarUrl(Map<String, dynamic> user, ApiService api) {
  for (final key in const [
    'avatar',
    'user_avatar',
    'profile_picture',
    'image',
  ]) {
    final value = user[key]?.toString().trim();
    if (value == null || value.isEmpty) continue;
    final resolved = api.getImageUrl(value);
    if (resolved != null && resolved.isNotEmpty) return resolved;
  }
  return null;
}

class MentionUserAvatar extends StatelessWidget {
  final Map<String, dynamic> user;
  final ApiService api;
  final double radius;

  const MentionUserAvatar({
    super.key,
    required this.user,
    required this.api,
    this.radius = 14,
  });

  Widget _fallback() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: Colors.white,
      padding: EdgeInsets.all(radius * 0.2),
      child: SvgPicture.asset('assets/logo.svg', fit: BoxFit.contain),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = resolveMentionAvatarUrl(user, api);

    return ClipOval(
      child: avatarUrl == null
          ? _fallback()
          : avatarUrl.toLowerCase().endsWith('.svg')
          ? SvgPicture.network(
              avatarUrl,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              placeholderBuilder: (_) => _fallback(),
            )
          : Image.network(
              avatarUrl,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            ),
    );
  }
}
