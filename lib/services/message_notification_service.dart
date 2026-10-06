import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'message_navigation_service.dart';
import 'notification_badge_service.dart';
import 'ntfy_push_service.dart';

const String _groupCallMessagePrefix = '__militant_group_call__:';

/// Service qui affiche des notifications locales avec bouton "Répondre"
/// pour les messages privés et de groupe — comme Signal/WhatsApp
class MessageNotificationService {
  MessageNotificationService._internal();
  static final MessageNotificationService instance =
      MessageNotificationService._internal();

  static const _channel = MethodChannel(
    'com.militant.militant_flutter/notifications',
  );

  bool _isInitialized = false;
  bool _oneSignalListenerAdded = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    // Écouter les notifications OneSignal en avant-plan pour les messages (si OneSignal actif)
    final provider = await NtfyPushService.instance.getSelectedProvider();
    if (provider == PushProvider.onesignal || provider == PushProvider.both) {
      enableOneSignalListener();
    }

    // Écouter les événements depuis le canal natif Android
    if (Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'messageNotificationClicked' ||
            call.method == 'notificationClicked') {
          final rawPayload = call.arguments;
          if (rawPayload is Map) {
            MessageNavigationService.instance.handlePayload(
              Map<String, dynamic>.from(rawPayload),
            );
          }
        }
      });

      // Vérifier si l'app a été démarrée à froid depuis un clic sur une notification native
      try {
        final initial = await _channel.invokeMethod<Map>(
          'getInitialMessageNotification',
        );
        if (initial != null) {
          MessageNavigationService.instance.handlePayload(
            Map<String, dynamic>.from(initial),
          );
        }
      } catch (e) {
        debugPrint(
          'MessageNotificationService: Erreur getInitialMessageNotification: $e',
        );
      }
    }

    _isInitialized = true;
  }

  /// Initialise l'écouteur OneSignal en avant-plan si activé dynamiquement
  void enableOneSignalListener() {
    if (_oneSignalListenerAdded) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
      OneSignal.Notifications.addForegroundWillDisplayListener((event) async {
        final data = event.notification.additionalData;
        if (data == null) {
          event.notification.display();
          return;
        }

        final type = data['type']?.toString();
        if (type == 'call') {
          return;
        }

        final messagePreview = data['message_preview']?.toString().trim() ?? '';
        final isGroupCallMarker =
            type == 'group_message' &&
            messagePreview.startsWith(_groupCallMessagePrefix);

        if (isGroupCallMarker) {
          event.preventDefault();
          return;
        }

        // Mettre à jour l'indicateur de notifications non lues en haut à droite
        NotificationBadgeService.instance.increment();

        final isHandled = await handleMessagePayload(
          title: event.notification.title ?? 'Nouveau message',
          body: event.notification.body ?? '',
          data: data,
        );

        if (isHandled) {
          event.preventDefault();
          return;
        }

        event.notification.display();
      });
      _oneSignalListenerAdded = true;
    } catch (_) {}
  }

  /// Traite un payload de message (reçu via OneSignal ou ntfy)
  Future<bool> handleMessagePayload({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final type = data['type']?.toString();
    if (type == 'call') return false;

    final messagePreview = data['message_preview']?.toString().trim() ?? '';
    final isGroupCallMarker =
        type == 'group_message' &&
        messagePreview.startsWith(_groupCallMessagePrefix);

    if (isGroupCallMarker) return false;

    if (type == 'message' || type == 'group_message') {
      await _showReplyableNotification(title: title, body: body, data: data);
      return true;
    }

    return false;
  }

  Future<void> _showReplyableNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final baseUrl = prefs.getString('base_url') ?? '';

      final isGroup = data['type'] == 'group_message';
      final senderId = int.tryParse(data['sender_id']?.toString() ?? '') ?? -1;
      final groupId = int.tryParse(data['group_id']?.toString() ?? '') ?? -1;

      final convName =
          data['username']?.toString() ??
          data['sender_name']?.toString() ??
          data['group_name']?.toString() ??
          (title.isNotEmpty && !title.contains('Nouveau message')
              ? title
              : null) ??
          (isGroup ? 'Groupe' : 'Message');
      final avatar =
          data['avatar']?.toString() ?? data['sender_avatar']?.toString();

      await _channel.invokeMethod('showReplyNotification', {
        'title': title,
        'body': body,
        'senderId': senderId,
        'groupId': groupId,
        'isGroup': isGroup,
        'conversationName': convName,
        'avatar': avatar,
        'token': token,
        'baseUrl': baseUrl,
      });
    } catch (e) {
      debugPrint('MessageNotificationService: Erreur affichage notif: $e');
    }
  }

  /// Affiche une notification Android générale (commentaires, likes, mentions...)
  Future<void> showNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    int? id,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('showNotification', {
        'id': id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        'title': title,
        'body': body,
        'channelId': 'messages_v2',
        'payload': data,
      });
    } catch (e) {
      debugPrint('[MessageNotificationService] Erreur showNotification: $e');
    }
  }
}
