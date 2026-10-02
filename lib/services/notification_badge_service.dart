import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Service gérant le badge indicateur de notifications non lues.
class NotificationBadgeService {
  NotificationBadgeService._internal();
  static final NotificationBadgeService instance = NotificationBadgeService._internal();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  Timer? _pollTimer;
  bool _isRefreshing = false;

  /// Démarre l'actualisation périodique du badge (toutes les 30s)
  void start() {
    refresh();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refresh();
    });
  }

  /// Arrête l'actualisation périodique
  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Incrémente le badge lors de la réception d'une notification temps réel (ex: ntfy/push)
  void increment() {
    unreadCount.value++;
  }

  /// Réinitialise le compteur local à 0
  void clear() {
    unreadCount.value = 0;
  }

  /// Interroge l'API pour synchroniser le nombre réel de notifications non lues
  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final api = await ApiService.getInstance();
      if (api.token != null && api.token!.isNotEmpty) {
        final count = await api.getUnreadNotificationsCount();
        unreadCount.value = count;
      }
    } catch (_) {
      // Ignorer silencieusement les erreurs de connexion réseau en arrière-plan
    } finally {
      _isRefreshing = false;
    }
  }

  /// Marque toutes les notifications comme lues sur le serveur et vide le badge
  Future<void> markAllAsRead() async {
    unreadCount.value = 0;
    try {
      final api = await ApiService.getInstance();
      await api.markAllNotificationsAsRead();
    } catch (_) {}
  }
}
