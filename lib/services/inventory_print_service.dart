import 'dart:typed_data';

import 'package:printing/printing.dart';

class InventoryPrintResult {
  const InventoryPrintResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class InventoryPrintService {
  Future<InventoryPrintResult> printPdfBytes({
    required Uint8List pdfBytes,
    required String jobName,
  }) async {
    try {
      if (pdfBytes.isEmpty) {
        return const InventoryPrintResult(
          success: false,
          message: '印刷対象のPDFデータがありません。',
        );
      }

      await Printing.layoutPdf(
        name: jobName,
        onLayout: (format) async => pdfBytes,
      );

      return const InventoryPrintResult(
        success: true,
        message: '印刷が完了しました。',
      );
    } catch (e) {
      return InventoryPrintResult(
        success: false,
        message: '印刷に失敗しました: $e',
      );
    }
  }
}
