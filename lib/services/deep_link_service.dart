import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../screens/group_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/post_detail_screen.dart';
import 'api_service.dart';
import 'incoming_call_service.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  Uri? _pendingUri;
  bool _isInitialized = false;

  /// Initialise la capture des liens profonds (App Links / Universal Links / Custom schemes)
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _linkSubscription?.cancel();

    // 1. Récupération du lien initial au démarrage à froid
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[DeepLinkService] Initial deep link détecté: $initialUri');
        await _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('[DeepLinkService] Erreur récupération lien initial: $e');
    }

    // 2. Écoute continue des liens reçus pendant l'exécution
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) async {
        debugPrint('[DeepLinkService] Flux de lien reçu: $uri');
        await _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('[DeepLinkService] Erreur stream deep link: $err');
      },
    );
  }

  /// Traite un lien brut sous forme de chaîne de caractères (ex: "post.php?id=123" ou "https://...")
  Future<void> handleLinkString(String rawLink) async {
    final trimmed = rawLink.trim();
    if (trimmed.isEmpty) return;

    Uri? uri;
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('militant://')) {
      uri = Uri.tryParse(trimmed);
    } else {
      // Lien relatif venant de l'API (ex: "post.php?id=123" ou "group_detail.php?id=5#post-8")
      final slash = trimmed.startsWith('/') ? '' : '/';
      uri = Uri.tryParse('https://militant.revlibertaire.com$slash$trimmed');
    }

    if (uri != null) {
      await _handleDeepLink(uri);
    } else {
      debugPrint('[DeepLinkService] Impossible de parser le lien brut: $rawLink');
    }
  }

  /// Vide le deep link en attente une fois l'UI / Navigator monté
  void flushPendingDeepLink() {
    final pending = _pendingUri;
    if (pending == null) return;
    _pendingUri = null;
    debugPrint('[DeepLinkService] Vidage du deep link en attente: $pending');
    _handleDeepLink(pending);
  }

  List<String> _pathTokens(Uri uri) {
    final tokens = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .map((segment) => Uri.decodeComponent(segment).toLowerCase())
        .toList();

    if (uri.scheme != 'http' && uri.scheme != 'https' && uri.host.isNotEmpty) {
      tokens.insert(0, uri.host.toLowerCase());
    }

    return tokens;
  }

  bool _matchesRoute(Uri uri, List<String> routeNames) {
    final tokens = _pathTokens(uri);

    for (final routeName in routeNames) {
      final normalized = routeName.toLowerCase();
      if (tokens.contains(normalized)) {
        return true;
      }
    }

    return false;
  }

  int? _extractId(Uri uri, List<String> routeNames) {
    // 1. Paramètres de requête standards
    final queryId = uri.queryParameters['id'] ??
        uri.queryParameters['post_id'] ??
        uri.queryParameters['groupId'] ??
        uri.queryParameters['userId'] ??
        uri.queryParameters['user_id'];
    if (queryId != null) {
      final parsed = int.tryParse(queryId);
      if (parsed != null && parsed > 0) return parsed;
    }

    // 2. Recherche dans les segments de chemin (ex: /post/123 ou /group/45)
    final tokens = _pathTokens(uri);
    for (final routeName in routeNames) {
      final index = tokens.indexOf(routeName.toLowerCase());
      if (index != -1 && index + 1 < tokens.length) {
        final parsed = int.tryParse(tokens[index + 1]);
        if (parsed != null && parsed > 0) return parsed;
      }
    }

    // 3. Dernier segment numérique (ex: /p/123)
    if (tokens.isNotEmpty) {
      final last = int.tryParse(tokens.last);
      if (last != null && last > 0) return last;
    }

    return null;
  }

  NavigatorState? get _navigator => appNavigatorKey.currentState;

  /// Routeur principal pour tous les liens reçus
  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('[DeepLinkService] Traitement deep link: $uri');

    // Vérifier si le lien comporte une ancre vers un post spécifique (ex: #post-123)
    if (uri.hasFragment && uri.fragment.startsWith('post-')) {
      final postId = int.tryParse(uri.fragment.replaceFirst('post-', ''));
      if (postId != null && postId > 0) {
        await _handlePostLink(postId, uri);
        return;
      }
    }

    if (_matchesRoute(uri, const [
      'post_detail.php',
      'post.php',
      'post',
      'p',
    ])) {
      final postId = _extractId(uri, const ['post', 'p']);
      if (postId != null) {
        await _handlePostLink(postId, uri);
        return;
      }
    }

    if (_matchesRoute(uri, const [
      'group_detail.php',
      'group.php',
      'group',
      'g',
    ])) {
      final groupId = _extractId(uri, const ['group', 'g']);
      if (groupId != null) {
        await _handleGroupLink(groupId, uri);
        return;
      }
    }

    if (_matchesRoute(uri, const [
      'profile.php',
      'profile',
      'user',
      'u',
    ])) {
      final userId = _extractId(uri, const ['profile', 'user', 'u']);
      if (userId != null) {
        await _handleProfileLink(userId, uri);
        return;
      }
    }

    debugPrint('[DeepLinkService] Aucun gestionnaire pour ce lien: $uri');
  }

  /// Ouvre le post cible
  Future<void> _handlePostLink(int postId, Uri originalUri) async {
    final navigator = _navigator;
    if (navigator == null) {
      debugPrint('[DeepLinkService] Navigator non prêt, mise en attente du post $postId');
      _pendingUri = originalUri;
      return;
    }

    debugPrint('[DeepLinkService] Redirection vers PostDetailScreen ($postId)');
    navigator.push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: postId),
      ),
    );
  }

  /// Ouvre le groupe cible
  Future<void> _handleGroupLink(int groupId, Uri originalUri) async {
    final navigator = _navigator;
    if (navigator == null) {
      debugPrint('[DeepLinkService] Navigator non prêt, mise en attente du groupe $groupId');
      _pendingUri = originalUri;
      return;
    }

    try {
      final api = await ApiService.getInstance();
      final groupData = await api.getSocialGroupDetails(groupId);

      final currentNav = _navigator;
      if (currentNav != null) {
        debugPrint('[DeepLinkService] Redirection vers GroupDetailScreen ($groupId)');
        currentNav.push(
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(group: groupData),
          ),
        );
      }
    } catch (e) {
      debugPrint('[DeepLinkService] Erreur chargement détails du groupe: $e');
    }
  }

  /// Ouvre le profil cible
  Future<void> _handleProfileLink(int userId, Uri originalUri) async {
    final navigator = _navigator;
    if (navigator == null) {
      debugPrint('[DeepLinkService] Navigator non prêt, mise en attente du profil $userId');
      _pendingUri = originalUri;
      return;
    }

    debugPrint('[DeepLinkService] Redirection vers ProfileScreen ($userId)');
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: userId),
      ),
    );
  }

  /// Nettoyage des ressources
  void dispose() {
    _linkSubscription?.cancel();
    _isInitialized = false;
  }
}
