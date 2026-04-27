import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/device_barcode_scanner.dart';

class ScanResult {
  final String rawValue;
  final bool isFromCamera;

  const ScanResult({required this.rawValue, required this.isFromCamera});
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  StreamSubscription<String>? _subscription;
  bool _hasDetectedBarcode = false;

  @override
  void initState() {
    super.initState();
    _startDeviceReader();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(DeviceBarcodeScanner.stopScan());
    unawaited(DeviceBarcodeScanner.disposeReader());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startDeviceReader() async {
    try {
      _subscription = DeviceBarcodeScanner.scanStream.listen((barcode) {
        _handleBarcodeString(barcode, isFromCamera: false);
      }, onError: (Object error) {
        // ignore errors
      });
      final initialized = await DeviceBarcodeScanner.initialize();
      if (initialized && mounted) {
        await DeviceBarcodeScanner.startScan();
      }
    } catch (_) {
      // ignore init errors
    }
  }

  Future<void> _handleBarcodeString(String rawValue, {required bool isFromCamera}) async {
    if (_hasDetectedBarcode) return;
    if (rawValue.isEmpty) return;

    _hasDetectedBarcode = true;
    try {
      await _controller.stop();
      await DeviceBarcodeScanner.stopScan();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pop(ScanResult(rawValue: rawValue, isFromCamera: isFromCamera));
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue != null) {
      await _handleBarcodeString(rawValue, isFromCamera: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('バーコードスキャン')),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _handleDetection),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'カメラ枠内に写すか、\n端末のトリガーボタンを押してください',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                backgroundColor: Colors.black54,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
