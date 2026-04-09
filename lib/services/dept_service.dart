import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class DeptService {
  static final Map<int, String> _deptMap = {};

  static Future<void> loadDepts() async {
    if (_deptMap.isNotEmpty) return;
    try {
      final String content = await rootBundle.loadString('assets/dept.txt');
      final lines = content.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;
        final parts = line.split(':');
        if (parts.length >= 2) {
          final int? id = int.tryParse(parts[0]);
          if (id != null) {
            _deptMap[id] = parts[1];
          }
        }
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
