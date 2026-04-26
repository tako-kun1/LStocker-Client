import 'dart:typed_data';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  static final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm');
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
      final pdf = pw.Document(
        theme: await _buildJapaneseTheme(),
      );
      final generatedAt = DateTime.now();
      final fileName = 'inventory_status_${_fileDateFormat.format(generatedAt)}.pdf';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                '在庫状況一覧',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('出力日時: ${_dateFormat.format(generatedAt)}'),
            ),
            pw.SizedBox(height: 12),
            _buildInventoryTable(inventories),
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

  Future<pw.ThemeData> _buildJapaneseTheme() async {
    try {
      final baseFont = await PdfGoogleFonts.iBMPlexSansJPRegular();
      final boldFont = await PdfGoogleFonts.iBMPlexSansJPBold();
      return pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    } catch (_) {
      // Fallback when font download is unavailable.
      return pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
  }

  pw.Widget _buildInventoryTable(List<Map<String, dynamic>> inventories) {
    final headerTitles = const ['登録日時', '商品名', 'JANコード', '期限日', '在庫数', '概要'];

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: headerTitles.map(_buildHeaderCell).toList(growable: false),
      ),
      ...inventories.map((item) {
        final registrationDate = _formatDateTime(item['registrationDate']);
        final productName = _stringValue(item['name'], fallback: '未登録商品');
        final janCode = _stringValue(item['janCode'], fallback: '-');
        final expirationDate = _formatDate(item['expirationDate']);
        final quantity = _stringValue(item['quantity'], fallback: '0');

        return pw.TableRow(
          children: [
            _buildDataCell(registrationDate),
            _buildDataCell(productName),
            _buildDataCell(janCode),
            _buildDataCell(expirationDate),
            _buildDataCell(quantity),
            _buildDataCell('', minHeight: 26),
          ],
        );
      }),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.6),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(2.2),
        2: pw.FlexColumnWidth(1.9),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.0),
        5: pw.FlexColumnWidth(3.2),
      },
      children: tableRows,
    );
  }

  pw.Widget _buildHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildDataCell(String text, {double minHeight = 20}) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      constraints: pw.BoxConstraints(minHeight: minHeight),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
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

  String _formatDateTime(dynamic rawValue) {
    if (rawValue == null) {
      return '-';
    }

    if (rawValue is DateTime) {
      return _dateTimeFormat.format(rawValue);
    }

    final parsed = DateTime.tryParse(rawValue.toString());
    if (parsed == null) {
      return '-';
    }

    return _dateTimeFormat.format(parsed);
  }

  String _stringValue(dynamic rawValue, {required String fallback}) {
    final value = rawValue?.toString().trim() ?? '';
    if (value.isEmpty) {
      return fallback;
    }
    return value;
  }
}
