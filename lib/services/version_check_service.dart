import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

class VersionCheckResult {
  final bool updateAvailable;
  final bool isRequired;
  final String currentVersion;
  final String latestVersion;
  final String? minSupportedVersion;
  final String? releaseNotes;
  final String? apkUrl;
  final String? releasePageUrl;
  final DateTime? publishedAt;
  final DateTime checkedAt;
  final String? error;

  const VersionCheckResult({
    required this.updateAvailable,
    required this.isRequired,
    required this.currentVersion,
    required this.latestVersion,
    required this.checkedAt,
    this.minSupportedVersion,
    this.releaseNotes,
    this.apkUrl,
    this.releasePageUrl,
    this.publishedAt,
    this.error,
  });

  Map<String, dynamic> toMap() {
    return {
      'updateAvailable': updateAvailable,
      'isRequired': isRequired,
      'currentVersion': currentVersion,
      'latestVersion': latestVersion,
      'minSupportedVersion': minSupportedVersion,
      'releaseNotes': releaseNotes,
      'apkUrl': apkUrl,
      'releasePageUrl': releasePageUrl,
      'publishedAt': publishedAt?.toIso8601String(),
      'checkedAt': checkedAt.toIso8601String(),
      'error': error,
    };
  }

  factory VersionCheckResult.fromMap(Map<String, dynamic> map) {
    return VersionCheckResult(
      updateAvailable: map['updateAvailable'] as bool? ?? false,
      isRequired: map['isRequired'] as bool? ?? false,
      currentVersion: map['currentVersion'] as String? ?? '0.0.0',
      latestVersion: map['latestVersion'] as String? ?? '0.0.0',
      minSupportedVersion: map['minSupportedVersion'] as String?,
      releaseNotes: map['releaseNotes'] as String?,
      apkUrl: map['apkUrl'] as String?,
      releasePageUrl: map['releasePageUrl'] as String?,
      publishedAt: map['publishedAt'] != null
          ? DateTime.tryParse(map['publishedAt'] as String)
          : null,
      checkedAt:
          DateTime.tryParse(map['checkedAt'] as String? ?? '') ??
          DateTime.now(),
      error: map['error'] as String?,
    );
  }
}

class VersionCheckService {
  static const String _cacheKey = 'update_check_cache';
  static const String _lastCheckedKey = 'update_check_last_checked_at';
  static const Duration checkInterval = Duration(hours: 24);

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {'Accept': 'application/json'},
    ),
  );

  Future<VersionCheckResult> checkForUpdate({bool force = false}) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = _normalizeVersion(packageInfo.version);
    final prefs = await SharedPreferences.getInstance();
    final checkStartedAt = DateTime.now();

    if (!force) {
      final cached = await getCachedResult();
      final lastCheckedAt = DateTime.tryParse(
        prefs.getString(_lastCheckedKey) ?? '',
      );

      if (cached != null &&
          lastCheckedAt != null &&
          DateTime.now().difference(lastCheckedAt) < checkInterval) {
        return cached;
      }
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      final cached = await getCachedResult();
      if (cached != null) {
        return cached;
      }

      return VersionCheckResult(
        updateAvailable: false,
        isRequired: false,
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        checkedAt: checkStartedAt,
        error: 'No network connection',
      );
    }

    try {
      final response = await _dio.get(AppConfig.effectiveUpdateMetadataUrl);
      final data = response.data as Map<String, dynamic>;

      final result = _buildResultFromResponse(
        data: data,
        currentVersion: currentVersion,
        checkedAt: checkStartedAt,
      );

      await prefs.setString(_cacheKey, jsonEncode(result.toMap()));
      await prefs.setString(
        _lastCheckedKey,
        result.checkedAt.toIso8601String(),
      );

      return result;
    } catch (e) {
      final cached = await getCachedResult();
      if (cached != null) {
        return cached;
      }

      return VersionCheckResult(
        updateAvailable: false,
        isRequired: false,
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        checkedAt: checkStartedAt,
        error: e.toString(),
      );
    } finally {
      await prefs.setString(_lastCheckedKey, checkStartedAt.toIso8601String());
    }
  }

  Future<VersionCheckResult?> getCachedResult() async {
    final prefs = await SharedPreferences.getInstance();
    final cache = prefs.getString(_cacheKey);
    if (cache == null || cache.isEmpty) {
      return null;
    }

    try {
      final map = jsonDecode(cache) as Map<String, dynamic>;
      return VersionCheckResult.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> getLastCheckedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastCheckedKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  String? _extractMinSupportedVersion(String body) {
    final regex = RegExp(
      r'min_supported_version\s*:\s*([0-9]+\.[0-9]+\.[0-9]+)',
    );
    final match = regex.firstMatch(body);
    if (match == null) {
      return null;
    }
    return _normalizeVersion(match.group(1)!);
  }

  bool _extractForceUpdate(String body) {
    final regex = RegExp(
      r'force_update\s*:\s*(true|false)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(body);
    if (match == null) {
      return false;
    }
    return (match.group(1) ?? '').toLowerCase() == 'true';
  }

  String? _extractApkUrl(dynamic assets) {
    if (assets is! List) {
      return null;
    }

    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) {
        continue;
      }
      final name = ((asset['name'] as String?) ?? '').toLowerCase();
      if (!name.endsWith('.apk')) {
        continue;
      }

      final url = (asset['browser_download_url'] as String?) ?? '';
      if (url.isNotEmpty) {
        return url;
      }
    }

    return null;
  }

  VersionCheckResult _buildResultFromResponse({
    required Map<String, dynamic> data,
    required String currentVersion,
    required DateTime checkedAt,
  }) {
    if (_looksLikeGitHubRelease(data)) {
      return _buildResultFromGitHubRelease(
        data: data,
        currentVersion: currentVersion,
        checkedAt: checkedAt,
      );
    }

    return _buildResultFromCustomManifest(
      data: data,
      currentVersion: currentVersion,
      checkedAt: checkedAt,
    );
  }

  bool _looksLikeGitHubRelease(Map<String, dynamic> data) {
    return data.containsKey('tag_name') || data.containsKey('assets');
  }

  VersionCheckResult _buildResultFromGitHubRelease({
    required Map<String, dynamic> data,
    required String currentVersion,
    required DateTime checkedAt,
  }) {
    final latestVersion = _resolveLatestVersion(data);
    final releaseBody = (data['body'] as String?) ?? '';
    final minSupported = _extractMinSupportedVersion(releaseBody);
    final forceUpdate = _extractForceUpdate(releaseBody);
    final apkUrl = _extractApkUrl(data['assets']);
    final publishedAt = DateTime.tryParse(
      (data['published_at'] as String?) ?? '',
    );
    final hasUpdate = _compareVersions(currentVersion, latestVersion) < 0;
    final belowMinimum =
        minSupported != null &&
        _compareVersions(currentVersion, minSupported) < 0;

    return VersionCheckResult(
      updateAvailable: hasUpdate,
      isRequired: hasUpdate && (belowMinimum || forceUpdate),
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      minSupportedVersion: minSupported,
      releaseNotes: releaseBody,
      apkUrl: apkUrl,
      releasePageUrl:
          _readString(data, ['html_url']) ??
          AppConfig.effectiveUpdateFallbackPageUrl,
      publishedAt: publishedAt,
      checkedAt: checkedAt,
    );
  }

  VersionCheckResult _buildResultFromCustomManifest({
    required Map<String, dynamic> data,
    required String currentVersion,
    required DateTime checkedAt,
  }) {
    final latestVersion = _normalizeVersion(
      _readString(data, ['latest_version', 'latestVersion', 'version']) ??
          '0.0.0',
    );
    final releaseNotes =
        _readString(data, ['release_notes', 'releaseNotes', 'notes']) ?? '';
    final minSupportedRaw = _readString(data, [
      'min_supported_version',
      'minSupportedVersion',
    ]);
    final minSupported = minSupportedRaw == null
        ? null
        : _normalizeVersion(minSupportedRaw);
    final forceUpdate =
        _readBool(data, ['force_update', 'forceUpdate']) ?? false;
    final apkUrl = _readString(data, [
      'apk_url',
      'apkUrl',
      'download_url',
      'downloadUrl',
    ]);
    final pageUrl =
        _readString(data, [
          'page_url',
          'pageUrl',
          'release_page_url',
          'releasePageUrl',
        ]) ??
        AppConfig.effectiveUpdateFallbackPageUrl;
    final publishedAt = DateTime.tryParse(
      _readString(data, ['published_at', 'publishedAt']) ?? '',
    );
    final hasUpdate = _compareVersions(currentVersion, latestVersion) < 0;
    final belowMinimum =
        minSupported != null &&
        _compareVersions(currentVersion, minSupported) < 0;

    return VersionCheckResult(
      updateAvailable: hasUpdate,
      isRequired: hasUpdate && (belowMinimum || forceUpdate),
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      minSupportedVersion: minSupported,
      releaseNotes: releaseNotes,
      apkUrl: apkUrl,
      releasePageUrl: pageUrl,
      publishedAt: publishedAt,
      checkedAt: checkedAt,
    );
  }

  String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  bool? _readBool(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is bool) {
        return value;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true') {
          return true;
        }
        if (normalized == 'false') {
          return false;
        }
      }
    }
    return null;
  }

  String _normalizeVersion(String version) {
    final cleaned = version.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final match = RegExp(r'([0-9]+)\.([0-9]+)\.([0-9]+)').firstMatch(cleaned);
    if (match == null) {
      return '0.0.0';
    }
    return '${match.group(1)}.${match.group(2)}.${match.group(3)}';
  }

  int _compareVersions(String a, String b) {
    final av = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bv = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final ai = i < av.length ? av[i] : 0;
      final bi = i < bv.length ? bv[i] : 0;
      if (ai != bi) {
        return ai.compareTo(bi);
      }
    }

    return 0;
  }

  String _resolveLatestVersion(Map<String, dynamic> releaseJson) {
    final candidates = <String>[
      (releaseJson['tag_name'] as String?) ?? '',
      (releaseJson['name'] as String?) ?? '',
      (releaseJson['body'] as String?) ?? '',
    ];

    for (final raw in candidates) {
      final normalized = _normalizeVersion(raw);
      if (normalized != '0.0.0') {
        return normalized;
      }
    }

    return '0.0.0';
  }
}
