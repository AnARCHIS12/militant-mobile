import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'incoming_call_service.dart';
import 'message_notification_service.dart';

/// Provider de push choisi par l'utilisateur
enum PushProvider {
  ntfy,
  onesignal,
  both,
  none;

  static PushProvider fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'onesignal':
        return PushProvider.onesignal;
      case 'both':
        return PushProvider.both;
      case 'none':
        return PushProvider.none;
      case 'ntfy':
      default:
        // Par défaut: ntfy (auto-hébergé, dégooglisé)
        return PushProvider.ntfy;
    }
  }

  String get key {
    switch (this) {
      case PushProvider.onesignal:
        return 'onesignal';
      case PushProvider.both:
        return 'both';
      case PushProvider.none:
        return 'none';
      case PushProvider.ntfy:
        return 'ntfy';
    }
  }
}

/// Service d'écoute en temps réel pour le serveur de push auto-hébergé ntfy
class NtfyPushService {
  NtfyPushService._internal();
  static final NtfyPushService instance = NtfyPushService._internal();

  static const String _prefKeyProvider = 'militant_push_provider';
  static const String defaultServerUrl = 'https://push.revlibertaire.com';
  static const String defaultTopicPrefix = 'militant_u_';

  http.Client? _client;
  StreamSubscription<String>? _streamSub;
  bool _isRunning = false;
  bool _isConnected = false;
  int? _currentUserId;
  String _serverUrl = defaultServerUrl;
  String _topicPrefix = defaultTopicPrefix;
  Timer? _reconnectTimer;
  int _retryAttempt = 0;

  bool get isConnected => _isConnected;
  bool get isRunning => _isRunning;

  /// Récupère le provider de push configuré (défaut: ntfy)
  Future<PushProvider> getSelectedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKeyProvider);
    return PushProvider.fromString(raw);
  }

  /// Définit le provider de push
  Future<void> setSelectedProvider(PushProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyProvider, provider.key);
  }

  /// Démarre l'écoute du topic ntfy pour l'utilisateur connecté
  Future<void> startListening({
    required int userId,
    String? serverUrl,
    String? topicPrefix,
  }) async {
    if (_isRunning && _currentUserId == userId) {
      debugPrint('[NtfyPushService] Déjà en cours d\'écoute pour userId: $userId');
      return;
    }

    await stopListening();

    _isRunning = true;
    _currentUserId = userId;
    _retryAttempt = 0;

    // Charger les réglages dynamiques du serveur si disponibles
    try {
      final api = await ApiService.getInstance();
      final settings = await api.getServerSettings();
      if (settings['ntfy_server'] != null &&
          settings['ntfy_server'].toString().trim().isNotEmpty) {
        _serverUrl = settings['ntfy_server'].toString().trim();
      } else if (serverUrl != null && serverUrl.isNotEmpty) {
        _serverUrl = serverUrl;
      }

      if (settings['ntfy_topic_prefix'] != null &&
          settings['ntfy_topic_prefix'].toString().trim().isNotEmpty) {
        _topicPrefix = settings['ntfy_topic_prefix'].toString().trim();
      } else if (topicPrefix != null && topicPrefix.isNotEmpty) {
        _topicPrefix = topicPrefix;
      }
    } catch (e) {
      debugPrint('[NtfyPushService] Erreur lecture réglages ntfy: $e');
    }

    _serverUrl = _serverUrl.replaceAll(RegExp(r'/+$'), '');
    _connectStream();
  }

  /// Établit la connexion HTTP streaming vers ntfy
  void _connectStream() {
    if (!_isRunning || _currentUserId == null) return;

    _cleanupClient();

    final topic = '$_topicPrefix$_currentUserId';
    final streamUri = Uri.parse('$_serverUrl/$topic/json');

    debugPrint('[NtfyPushService] Connexion au flux ntfy: $streamUri');

    _client = http.Client();
    final request = http.Request('GET', streamUri);
    request.headers['User-Agent'] = 'Militant-Flutter/1.0';

    _client!
        .send(request)
        .then((response) {
          if (response.statusCode != 200) {
            debugPrint(
              '[NtfyPushService] Erreur HTTP ${response.statusCode} lors de la connexion',
            );
            _scheduleReconnect();
            return;
          }

          _isConnected = true;
          _retryAttempt = 0;
          debugPrint('[NtfyPushService] Connecté avec succès au flux ntfy ($topic)');

          _streamSub = response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen(
                (line) => _handleStreamLine(line),
                onError: (e) {
                  debugPrint('[NtfyPushService] Erreur dans le flux: $e');
                  _scheduleReconnect();
                },
                onDone: () {
                  debugPrint('[NtfyPushService] Flux fermé par le serveur');
                  _scheduleReconnect();
                },
                cancelOnError: true,
              );
        })
        .catchError((e) {
          debugPrint('[NtfyPushService] Échec de connexion réseau: $e');
          _scheduleReconnect();
        });
  }

  /// Traite chaque événement JSON reçu du flux ntfy
  void _handleStreamLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    try {
      final json = jsonDecode(trimmed);
      if (json is! Map<String, dynamic>) return;

      final event = json['event']?.toString();
      if (event == 'keepalive' || event == 'open') {
        // Heartbeat / ping régulier ntfy
        return;
      }

      if (event == 'message') {
        _dispatchNtfyMessage(json);
      }
    } catch (e) {
      debugPrint('[NtfyPushService] Erreur décodage message ntfy: $e');
    }
  }

  /// Dispatche un message reçu vers le bon service de l'application
  Future<void> _dispatchNtfyMessage(Map<String, dynamic> rawEvent) async {
    final title = rawEvent['title']?.toString() ?? 'Militant';
    final message = rawEvent['message']?.toString() ?? '';

    // Extraction des métadonnées (data / extras)
    Map<String, dynamic> data = {};

    // 1. Depuis actions[0].extras
    if (rawEvent['actions'] is List && (rawEvent['actions'] as List).isNotEmpty) {
      final action = (rawEvent['actions'] as List).first;
      if (action is Map && action['extras'] is Map) {
        data = Map<String, dynamic>.from(action['extras']);
      }
    }

    // 2. Depuis rawEvent['data'] si présent
    if (data.isEmpty && rawEvent['data'] is Map) {
      data = Map<String, dynamic>.from(rawEvent['data']);
    }

    // 3. Si message est lui-même un JSON sérialisé
    if (data.isEmpty && message.startsWith('{') && message.endsWith('}')) {
      try {
        final decoded = jsonDecode(message);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    final type = data['type']?.toString();
    debugPrint('[NtfyPushService] Notification ntfy reçue: type=$type title=$title');

    // ─── Appels entrants audio / vidéo ─────────────────────────────────────────
    if (type == 'call' || rawEvent['priority'] == 5) {
      if (type == 'call' || data.containsKey('call_id')) {
        await IncomingCallService.instance.handleIncomingCallPayload(
          data,
          body: message,
          openScreenImmediately: false,
        );
        return;
      }
    }

    // ─── Messages privés / de groupe ──────────────────────────────────────────
    if (type == 'message' || type == 'group_message') {
      await MessageNotificationService.instance.handleMessagePayload(
        title: title,
        body: message,
        data: data,
      );
      return;
    }

    // ─── Autres notifications sociales ────────────────────────────────────────
    // Affichage natif ou géré par l'app
    debugPrint('[NtfyPushService] Notification sociale: $title - $message');
  }

  /// Planifie une reconnexion automatique avec backoff progressif
  void _scheduleReconnect() {
    _isConnected = false;
    if (!_isRunning) return;

    _cleanupClient();

    _retryAttempt++;
    final seconds = (_retryAttempt * 2).clamp(2, 30);
    debugPrint('[NtfyPushService] Reconnexion dans $seconds secondes (tentative $_retryAttempt)...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (_isRunning) {
        _connectStream();
      }
    });
  }

  /// Nettoie les ressources du client
  void _cleanupClient() {
    _streamSub?.cancel();
    _streamSub = null;
    _client?.close();
    _client = null;
    _isConnected = false;
  }

  /// Arrête l'écoute du flux
  Future<void> stopListening() async {
    _isRunning = false;
    _isConnected = false;
    _currentUserId = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupClient();
    debugPrint('[NtfyPushService] Écoute ntfy arrêtée');
  }
}
