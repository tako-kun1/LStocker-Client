import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/device_barcode_scanner.dart';

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
    final scanMethod = context.watch<SettingsProvider>().barcodeScanMethod;

    if (scanMethod == SettingsProvider.barcodeScanMethodDeviceReader) {
      return const _DeviceBarcodeScannerScreen();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('バーコードスキャン')),
      body: MobileScanner(controller: _controller, onDetect: _handleDetection),
    );
  }
}

class _DeviceBarcodeScannerScreen extends StatefulWidget {
  const _DeviceBarcodeScannerScreen();

  @override
  State<_DeviceBarcodeScannerScreen> createState() =>
      _DeviceBarcodeScannerScreenState();
}

class _DeviceBarcodeScannerScreenState extends State<_DeviceBarcodeScannerScreen> {
  StreamSubscription<String>? _subscription;
  bool _isInitializing = true;
  bool _hasDetectedBarcode = false;
  String? _errorMessage;

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
    super.dispose();
  }

  Future<void> _startDeviceReader() async {
    try {
      _subscription = DeviceBarcodeScanner.scanStream.listen((barcode) async {
        if (_hasDetectedBarcode) {
          return;
        }

        _hasDetectedBarcode = true;
        await DeviceBarcodeScanner.stopScan();
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(barcode);
      }, onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorMessage = error.toString();
          _isInitializing = false;
        });
      });

      final initialized = await DeviceBarcodeScanner.initialize();
      if (!mounted) {
        return;
      }
      if (!initialized) {
        setState(() {
          _errorMessage = 'Zebra EMDK スキャナを初期化できませんでした。';
          _isInitializing = false;
        });
        return;
      }

      await DeviceBarcodeScanner.startScan();
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '端末スキャナの開始に失敗しました: $e';
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('端末スキャナ読取')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isInitializing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('端末スキャナを初期化しています...'),
              ] else if (_errorMessage != null) ...[
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                const Icon(Icons.document_scanner_outlined, size: 56),
                const SizedBox(height: 16),
                const Text('端末のトリガーを押してバーコードを読み取ってください。'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
