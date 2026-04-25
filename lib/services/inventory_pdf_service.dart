import 'dart:typed_data';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InventoryPdfDataResult {
  const InventoryPdfDataResult({
    required this.success,
    required this.message,
    this.bytes,
    this.fileName,
  });

  final bool success;
  final String message;
  final Uint8List? bytes;
  final String? fileName;
}

class InventoryPdfSaveResult {
  const InventoryPdfSaveResult({
    required this.success,
    required this.message,
    this.filePath,
  });

  final bool success;
  final String message;
  final String? filePath;
}

class InventoryPdfService {
  static final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  static final DateFormat _fileDateFormat = DateFormat('yyyyMMdd_HHmmss');

  Future<InventoryPdfDataResult> buildInventoryPdfBytes(
    List<Map<String, dynamic>> inventories,
  ) async {
    if (inventories.isEmpty) {
      return const InventoryPdfDataResult(
        success: false,
        message: '出力対象の在庫データがありません。',
      );
    }

    try {
      final pdf = pw.Document();
      final generatedAt = DateTime.now();
      final fileName = 'inventory_status_${_fileDateFormat.format(generatedAt)}.pdf';

      final rows = inventories.map((item) {
        final productName = _stringValue(item['name'], fallback: '未登録商品');
        final janCode = _stringValue(item['janCode'], fallback: '-');
        final quantity = _stringValue(item['quantity'], fallback: '0');
        final registrationDate = _formatDate(item['registrationDate']);
        final expirationDate = _formatDate(item['expirationDate']);
        return [productName, janCode, quantity, registrationDate, expirationDate];
      }).toList(growable: false);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text(
              '在庫状況一覧',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text('出力日時: ${_dateFormat.format(generatedAt)}'),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: const ['商品名', 'JAN', '数量', '登録日', '期限日'],
              data: rows,
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      return InventoryPdfDataResult(
        success: true,
        message: 'PDFを生成しました。',
        bytes: bytes,
        fileName: fileName,
      );
    } catch (e) {
      return InventoryPdfDataResult(
        success: false,
        message: 'PDF生成に失敗しました: $e',
      );
    }
  }

  Future<InventoryPdfSaveResult> savePdfBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = p.join(directory.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      return InventoryPdfSaveResult(
        success: true,
        message: 'PDFを保存しました。',
        filePath: filePath,
      );
    } catch (e) {
      return InventoryPdfSaveResult(
        success: false,
        message: 'PDF保存に失敗しました: $e',
      );
    }
  }

  String _formatDate(dynamic rawValue) {
    if (rawValue == null) {
      return '-';
    }

    if (rawValue is DateTime) {
      return _dateFormat.format(rawValue);
    }

    final parsed = DateTime.tryParse(rawValue.toString());
    if (parsed == null) {
      return '-';
    }

    return _dateFormat.format(parsed);
  }

  String _stringValue(dynamic rawValue, {required String fallback}) {
    final value = rawValue?.toString().trim() ?? '';
    if (value.isEmpty) {
      return fallback;
    }
    return value;
  }
}
