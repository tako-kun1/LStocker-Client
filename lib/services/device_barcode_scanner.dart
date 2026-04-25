import 'package:flutter/services.dart';

class DeviceBarcodeScanner {
  static const MethodChannel _methodChannel = MethodChannel(
    'cloud.nazono.lstocker/barcode_reader',
  );
  static const EventChannel _eventChannel = EventChannel(
    'cloud.nazono.lstocker/barcode_reader_events',
  );

  static Stream<String> get scanStream => _eventChannel
      .receiveBroadcastStream()
      .where((event) => event is String)
      .cast<String>();

  static Future<bool> initialize() async {
    final result = await _methodChannel.invokeMethod<bool>('initialize');
    return result ?? false;
  }

  static Future<void> startScan() async {
    await _methodChannel.invokeMethod<void>('startScan');
  }

  static Future<void> stopScan() async {
    await _methodChannel.invokeMethod<void>('stopScan');
  }

  static Future<void> disposeReader() async {
    await _methodChannel.invokeMethod<void>('dispose');
  }
}
