import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  static const String _channelId = 'inventory_notifications';
  static const String _channelName = 'Inventory Notifications';
  static const String _channelDescription = '賞味期限が近い在庫の通知';
  static const String _lastNotificationSignatureKey =
      'lastNearExpirationNotificationSignature';
  static const int _summaryNotificationId = 1001;
  static const String _androidNotificationIcon = 'app_icon_drawe';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize({bool requestPermissions = false}) async {
    if (_initialized) {
      if (requestPermissions) {
        await _requestPermissions();
      }
      return;
    }

    await _initializeWithPreferredIcon();
    await _createAndroidChannel();
    if (requestPermissions) {
      await _requestPermissions();
    }
    _initialized = true;
  }

  Future<void> _initializeWithPreferredIcon() async {
    try {
      const androidSettings = AndroidInitializationSettings(
        _androidNotificationIcon,
      );
      const settings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(settings: settings);
    } catch (_) {
      // Keep app booting even if a custom icon cannot be resolved.
      const fallbackAndroidSettings = AndroidInitializationSettings(
        'launcher_icon',
      );
      const fallbackSettings = InitializationSettings(
        android: fallbackAndroidSettings,
      );
      await _plugin.initialize(settings: fallbackSettings);
    }
  }

  Future<void> syncNearExpirationNotifications(
    List<Map<String, dynamic>> inventories,
  ) async {
    await initialize(requestPermissions: false);

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('pushNotificationsEnabled') ?? true;
    if (!enabled) {
      await clearActiveNotifications(resetState: true);
      return;
    }

    final notifications = _extractNearExpirationInventories(inventories);
    if (notifications.isEmpty) {
      await clearActiveNotifications(resetState: true);
      return;
    }

    final signature = _buildSignature(notifications);
    final previousSignature = prefs.getString(_lastNotificationSignatureKey);
    if (signature == previousSignature) {
      return;
    }

    final count = notifications.length;
    final names = notifications
        .take(3)
        .map((item) => item['name'] as String? ?? '商品')
        .join('、');
    final moreSuffix = count > 3 ? ' ほか${count - 3}件' : '';

    await _plugin.show(
      id: _summaryNotificationId,
      title: count == 1 ? '期限間近の商品があります' : '期限間近の商品が$count件あります',
      body: '$names$moreSuffix の販売制限開始日が近づいています。',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          icon: _androidNotificationIcon,
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'inventory_alert',
        ),
      ),
    );

    await prefs.setString(_lastNotificationSignatureKey, signature);
  }

  Future<void> clearActiveNotifications({bool resetState = false}) async {
    await initialize(requestPermissions: false);
    await _plugin.cancel(id: _summaryNotificationId);

    if (resetState) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastNotificationSignatureKey);
    }
  }

  List<Map<String, dynamic>> _extractNearExpirationInventories(
    List<Map<String, dynamic>> inventories,
  ) {
    final now = DateTime.now();

    return inventories
        .where((item) {
          final expirationRaw = item['expirationDate'] as String?;
          final salesPeriod = item['salesPeriod'] as int?;
          if (expirationRaw == null || salesPeriod == null) {
            return false;
          }

          final expirationDate = DateTime.tryParse(expirationRaw);
          if (expirationDate == null) {
            return false;
          }

          final notificationDate = expirationDate.subtract(
            Duration(days: salesPeriod),
          );
          final diff = notificationDate.difference(now).inDays;
          return diff <= 3;
        })
        .toList(growable: false);
  }

  String _buildSignature(List<Map<String, dynamic>> notifications) {
    final keys = notifications.map((item) {
      final id = item['id']?.toString() ?? '';
      final expirationDate = item['expirationDate']?.toString() ?? '';
      final quantity = item['quantity']?.toString() ?? '';
      return '$id|$expirationDate|$quantity';
    }).toList()..sort();

    return keys.join(',');
  }

  Future<void> _createAndroidChannel() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
      ),
    );
  }

  Future<void> _requestPermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
  }
}
