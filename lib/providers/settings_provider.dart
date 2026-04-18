import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../services/app_config.dart';
import '../services/notification_service.dart';

class SettingsProvider with ChangeNotifier {
  static const String barcodeScanMethodCamera = 'camera';
  static const String barcodeScanMethodDeviceReader = 'device_reader';

  String _serverUrl = '';
  bool _pushNotificationsEnabled = true;
  String _syncTiming = 'Manual';
  String _barcodeScanMethod = barcodeScanMethodCamera;
  bool _autoCheckUpdateOnStartup = true;
  int? _userId;
  String? _username;
  bool _isLoggedIn = false;

  String get serverUrl => _serverUrl;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  String get syncTiming => _syncTiming;
  String get barcodeScanMethod => _barcodeScanMethod;
  bool get autoCheckUpdateOnStartup => _autoCheckUpdateOnStartup;
  int? get userId => _userId;
  String? get username => _username;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString('serverUrl') ?? AppConfig.defaultBaseUrl;
    _pushNotificationsEnabled =
        prefs.getBool('pushNotificationsEnabled') ?? true;
    _syncTiming = prefs.getString('syncTiming') ?? 'Manual';
    _barcodeScanMethod = _normalizeBarcodeScanMethod(
      prefs.getString('barcodeScanMethod'),
    );
    _autoCheckUpdateOnStartup =
        prefs.getBool('autoCheckUpdateOnStartup') ?? true;

    // ユーザー情報を読み込む
    final apiClient = ApiClient();
    _userId = await apiClient.getUserId();
    _username = await apiClient.getUsername();
    _isLoggedIn = (await apiClient.getAccessToken()) != null;

    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    _serverUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverUrl', url);
    notifyListeners();
  }

  Future<void> setPushNotificationsEnabled(bool enabled) async {
    _pushNotificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pushNotificationsEnabled', enabled);
    if (enabled) {
      await NotificationService().initialize();
    } else {
      await NotificationService().clearActiveNotifications(resetState: true);
    }
    notifyListeners();
  }

  Future<void> setSyncTiming(String timing) async {
    _syncTiming = timing;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('syncTiming', timing);
    notifyListeners();
  }

  Future<void> setBarcodeScanMethod(String method) async {
    _barcodeScanMethod = _normalizeBarcodeScanMethod(method);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('barcodeScanMethod', _barcodeScanMethod);
    notifyListeners();
  }

  Future<void> setAutoCheckUpdateOnStartup(bool enabled) async {
    _autoCheckUpdateOnStartup = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoCheckUpdateOnStartup', enabled);
    notifyListeners();
  }

  /// ログイン状態を更新
  Future<void> setLoginStatus({
    required bool isLoggedIn,
    required int userId,
    required String username,
  }) async {
    _isLoggedIn = isLoggedIn;
    _userId = userId;
    _username = username;

    final apiClient = ApiClient();
    await apiClient.setUserId(userId);
    await apiClient.setUsername(username);

    notifyListeners();
  }

  /// ログアウト状態を更新
  Future<void> setLogoutStatus() async {
    _isLoggedIn = false;
    _userId = null;
    _username = null;

    final apiClient = ApiClient();
    await apiClient.clearTokens();

    notifyListeners();
  }

  String _normalizeBarcodeScanMethod(String? method) {
    if (method == barcodeScanMethodDeviceReader) {
      return barcodeScanMethodDeviceReader;
    }
    return barcodeScanMethodCamera;
  }
}
