import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'api_service.dart';

class DeptService {
  static final Map<int, String> _deptMap = {};
  static final ApiService _apiService = ApiService();
  static bool _remoteRefreshStarted = false;

  static Future<void> loadDepts() async {
    if (_deptMap.isEmpty) {
      await _loadFromAsset();
    }

    if (_deptMap.isEmpty) {
      await _refreshFromApi();
      return;
    }

    if (_remoteRefreshStarted) {
      return;
    }

    _remoteRefreshStarted = true;
    _refreshFromApi();
  }

  static Future<void> _refreshFromApi() async {
    try {
      final response = await _apiService.getDepartments();
      final nextMap = <int, String>{};
      for (final dept in response.departments) {
        nextMap[dept.deptNumber] = dept.name;
      }
      if (nextMap.isNotEmpty) {
        _deptMap
          ..clear()
          ..addAll(nextMap);
        debugPrint('[DeptService] loaded ${_deptMap.length} departments from API');
        return;
      }
    } catch (e) {
      debugPrint('[DeptService] API department load failed: $e');
    }
  }

  static Future<void> _loadFromAsset() async {
    try {
      final String content = await rootBundle.loadString('assets/dept.txt');
      final nextMap = <int, String>{};
      final lines = content.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;
        final parts = line.split(':');
        if (parts.length >= 2) {
          final int? id = int.tryParse(parts[0]);
          if (id != null) {
            nextMap[id] = parts[1];
          }
        }
      }
      if (nextMap.isNotEmpty) {
        _deptMap
          ..clear()
          ..addAll(nextMap);
        debugPrint('[DeptService] loaded ${_deptMap.length} departments from asset');
      }
    } catch (e) {
      debugPrint('Error loading depts: $e');
    }
  }

  static String getDeptName(int id) {
    return _deptMap[id] ?? '不明';
  }

  static List<int> getAvailableDeptIds() {
    return _deptMap.keys.toList()..sort();
  }

  static Map<int, String> get deptMap => _deptMap;
}
