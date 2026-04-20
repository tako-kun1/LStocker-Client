import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasDetectedBarcode = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_hasDetectedBarcode) {
      return;
    }

    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    _hasDetectedBarcode = true;

    try {
      await _controller.stop();
    } catch (_) {
      // stop に失敗しても結果返却は継続する。
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(rawValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('バーコードスキャン')),
      body: MobileScanner(controller: _controller, onDetect: _handleDetection),
    );
  }
}
