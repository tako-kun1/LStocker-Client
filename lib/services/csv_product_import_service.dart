import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';
import 'database_helper.dart';

const Duration _kConnectTimeout = Duration(seconds: 15);
const Duration _kReceiveTimeout = Duration(seconds: 30);

class CsvProductImportResult {
  final bool success;
  final String message;
  final int totalRows;
  final int insertedCount;
  final int skippedExistingCount;
  final int skippedDuplicateCount;
  final int invalidRowCount;

  const CsvProductImportResult({
    required this.success,
    required this.message,
    required this.totalRows,
    required this.insertedCount,
    required this.skippedExistingCount,
    required this.skippedDuplicateCount,
    required this.invalidRowCount,
  });
}

class CsvProductImportService {
  static const int maxJanLength = 24;
  static const String defaultName = '未設定商品';

  final Dio _dio;
  final DatabaseHelper _dbHelper;

  CsvProductImportService({Dio? dio, DatabaseHelper? dbHelper})
    : _dio = dio ?? Dio(),
      _dbHelper = dbHelper ?? DatabaseHelper();

  Future<CsvProductImportResult> importFromUrl(String csvUrl) async {
    final trimmedUrl = csvUrl.trim();
    if (trimmedUrl.isEmpty) {
      return const CsvProductImportResult(
        success: false,
        message: 'CSV URL が未設定です。',
        totalRows: 0,
        insertedCount: 0,
        skippedExistingCount: 0,
        skippedDuplicateCount: 0,
        invalidRowCount: 0,
      );
    }

    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null || !uri.hasScheme || !uri.isAbsolute) {
      return const CsvProductImportResult(
        success: false,
        message: 'CSV URL の形式が不正です。',
        totalRows: 0,
        insertedCount: 0,
        skippedExistingCount: 0,
        skippedDuplicateCount: 0,
        invalidRowCount: 0,
      );
    }

    try {
      final response = await _dio.get<String>(
        trimmedUrl,
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: _kConnectTimeout,
          receiveTimeout: _kReceiveTimeout,
        ),
      );
      if (response.statusCode == 404) {
        return const CsvProductImportResult(
          success: true,
          message: 'CSV が見つからないため、インポートをスキップしました (HTTP 404)。',
          totalRows: 0,
          insertedCount: 0,
          skippedExistingCount: 0,
          skippedDuplicateCount: 0,
          invalidRowCount: 0,
        );
      }
      if (response.statusCode != 200) {
        return CsvProductImportResult(
          success: false,
          message: 'CSV の取得に失敗しました (HTTP ${response.statusCode})。',
          totalRows: 0,
          insertedCount: 0,
          skippedExistingCount: 0,
          skippedDuplicateCount: 0,
          invalidRowCount: 0,
        );
      }
      final body = response.data ?? '';
      if (body.trim().isEmpty) {
        return const CsvProductImportResult(
          success: false,
          message: 'CSV が空です。',
          totalRows: 0,
          insertedCount: 0,
          skippedExistingCount: 0,
          skippedDuplicateCount: 0,
          invalidRowCount: 0,
        );
      }

      final lines = body
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.length < 2) {
        return const CsvProductImportResult(
          success: false,
          message: 'CSV のデータ行がありません。',
          totalRows: 0,
          insertedCount: 0,
          skippedExistingCount: 0,
          skippedDuplicateCount: 0,
          invalidRowCount: 0,
        );
      }

      final header = _parseCsvLine(
        lines.first,
      ).map((e) => e.trim().toLowerCase()).toList();

      final janIndex = _findHeaderIndex(header, const [
        'jancode',
        'jan_code',
        'jan',
      ]);
      final nameIndex = _findHeaderIndex(header, const [
        'name',
        'product_name',
      ]);
      final deptIndex = _findHeaderIndex(header, const [
        'deptnumber',
        'dept_number',
        'dept',
      ]);
      final salesPeriodIndex = _findHeaderIndex(header, const [
        'salesperiod',
        'sales_period',
      ]);
      final descriptionIndex = _findHeaderIndex(header, const [
        'description',
        'detail',
      ]);
      final imagePathIndex = _findHeaderIndex(header, const [
        'imagepath',
        'image_path',
      ]);

      if (janIndex < 0) {
        return const CsvProductImportResult(
          success: false,
          message: 'CSV に janCode 列がありません。',
          totalRows: 0,
          insertedCount: 0,
          skippedExistingCount: 0,
          skippedDuplicateCount: 0,
          invalidRowCount: 0,
        );
      }

      final existingJanCodes = await _dbHelper.getAllProductJanCodes();
      final duplicateCheckSet = <String>{};
      final pendingProducts = <Product>[];

      int skippedExistingCount = 0;
      int skippedDuplicateCount = 0;
      int invalidRowCount = 0;

      for (var i = 1; i < lines.length; i++) {
        final fields = _parseCsvLine(lines[i]);
        if (fields.isEmpty) {
          continue;
        }

        final jan = _normalizeJan(_getField(fields, janIndex));
        if (jan.isEmpty) {
          invalidRowCount++;
          continue;
        }

        if (duplicateCheckSet.contains(jan)) {
          skippedDuplicateCount++;
          continue;
        }
        duplicateCheckSet.add(jan);

        if (existingJanCodes.contains(jan)) {
          skippedExistingCount++;
          continue;
        }

        final name = _normalizeText(_getField(fields, nameIndex));
        final deptNumber = _parseIntOrDefault(
          _getField(fields, deptIndex),
          0,
        );
        final salesPeriod = _parseIntOrDefault(
          _getField(fields, salesPeriodIndex),
          0,
        );
        final description = _normalizeText(
          _getField(fields, descriptionIndex),
        );
        final imagePath = _normalizeText(_getField(fields, imagePathIndex));

        pendingProducts.add(
          Product(
            janCode: jan,
            name: name.isEmpty ? defaultName : name,
            imagePath: imagePath,
            deptNumber: deptNumber,
            salesPeriod: salesPeriod,
            description: description,
          ),
        );

        existingJanCodes.add(jan);
      }

      final insertedCount = await _dbHelper.insertProductsInTransaction(
        pendingProducts,
        syncStatus: 'synced',
      );

      final message =
          'CSV取込完了: 追加 $insertedCount 件 / 既存スキップ $skippedExistingCount 件 / '
          'CSV重複スキップ $skippedDuplicateCount 件 / 不正行 $invalidRowCount 件';

      debugPrint('[CsvProductImportService] $message');

      return CsvProductImportResult(
        success: true,
        message: message,
        totalRows: lines.length - 1,
        insertedCount: insertedCount,
        skippedExistingCount: skippedExistingCount,
        skippedDuplicateCount: skippedDuplicateCount,
        invalidRowCount: invalidRowCount,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const CsvProductImportResult(
          success: true,
          message: 'CSV が見つからないため、インポートをスキップしました (HTTP 404)。',
          totalRows: 0,
          insertedCount: 0,
          skippedExistingCount: 0,
          skippedDuplicateCount: 0,
          invalidRowCount: 0,
        );
      }
      final msg = e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout
          ? 'CSV の取得がタイムアウトしました。'
          : 'CSV の取得中にネットワークエラーが発生しました: ${e.message}';
      debugPrint('[CsvProductImportService] DioException: $e');
      return CsvProductImportResult(
        success: false,
        message: msg,
        totalRows: 0,
        insertedCount: 0,
        skippedExistingCount: 0,
        skippedDuplicateCount: 0,
        invalidRowCount: 0,
      );
    }
  }

  int _findHeaderIndex(List<String> header, List<String> candidates) {
    for (final candidate in candidates) {
      final index = header.indexOf(candidate);
      if (index >= 0) {
        return index;
      }
    }
    return -1;
  }

  String _getField(List<String> fields, int index) {
    if (index < 0 || index >= fields.length) {
      return '';
    }
    return fields[index];
  }

  String _normalizeJan(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > maxJanLength) {
      return digits.substring(0, maxJanLength);
    }
    return digits;
  }

  String _normalizeText(String value) {
    return value.trim();
  }

  int _parseIntOrDefault(String value, int defaultValue) {
    return int.tryParse(value.trim()) ?? defaultValue;
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    result.add(buffer.toString());
    return result;
  }
}
