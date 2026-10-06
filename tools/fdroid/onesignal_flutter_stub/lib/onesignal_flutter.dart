/// F-Droid build-only interface: it deliberately contains no native plugin,
/// network client, or OneSignal implementation. The app forces ntfy in this
/// variant, so these no-op members are only present to keep shared Dart code
/// compilable.
library onesignal_flutter;

enum OSLogLevel { verbose }

class OneSignal {
  OneSignal._();

  static final Debug = _Debug();
  static final Notifications = _Notifications();
  static final User = _User();

  static void initialize(String appId) {}
  static Future<void> login(String externalId) async {}
  static Future<void> logout() async {}
}

class _Debug {
  void setLogLevel(OSLogLevel level) {}
}

class _Notifications {
  Future<bool> requestPermission(bool fallbackToSettings) async => false;
  void addForegroundWillDisplayListener(
    FutureOrVoidCallback<OSNotificationWillDisplayEvent> listener,
  ) {}
  void addClickListener(FutureOrVoidCallback<OSNotificationClickEvent> listener) {}
}

typedef FutureOrVoidCallback<T> = dynamic Function(T event);

class _User {
  final pushSubscription = _PushSubscription();
}

class _PushSubscription {
  Future<void> optIn() async {}
  Future<void> optOut() async {}
}

class OSNotification {
  OSNotification({this.additionalData, this.title, this.body});

  final Map<String, dynamic>? additionalData;
  final String? title;
  final String? body;

  void display() {}
}

class OSNotificationWillDisplayEvent {
  OSNotificationWillDisplayEvent(this.notification);

  final OSNotification notification;

  void preventDefault() {}
}

class OSNotificationClickEvent {
  OSNotificationClickEvent(this.notification);

  final OSNotification notification;
}
