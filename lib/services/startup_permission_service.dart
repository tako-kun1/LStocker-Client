import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartupPermissionService {
  static const String _requestedVersionKey =
      'startupRequestedPermissionsVersion';

  Future<void> requestPermissionsIfFirstLaunchOfVersion() async {
    if (!Platform.isAndroid) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersionTag = '${packageInfo.version}+${packageInfo.buildNumber}';
    final requestedVersionTag = prefs.getString(_requestedVersionKey);

    if (requestedVersionTag == currentVersionTag) {
      return;
    }

    try {
      await Permission.notification.request();
    } catch (_) {}

    try {
      await Permission.camera.request();
    } catch (_) {}

    await prefs.setString(_requestedVersionKey, currentVersionTag);
  }
}