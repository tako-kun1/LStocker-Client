import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/product_key_service.dart';

class LicenseActivationScreen extends StatefulWidget {
  const LicenseActivationScreen({super.key});

  @override
  State<LicenseActivationScreen> createState() => _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen> {
  final _controller = TextEditingController();
  final _service = ProductKeyService();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      final result = await _service.activateProductKey(_controller.text);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );

      if (result.success) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text('プロダクトキー認証')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('プロダクトキーを入力してください。'),
              const SizedBox(height: 4),
              const Text(
                '形式: XXXX-XXXX-XXXX-XXXX（英大文字・数字）',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'プロダクトキー',
                  hintText: 'XXXX-XXXX-XXXX-XXXX',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: const [
                  _ProductKeyTextFormatter(),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _activate(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submitting ? null : _activate,
                child: Text(_submitting ? '認証中...' : '認証する'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductKeyTextFormatter extends TextInputFormatter {
  const _ProductKeyTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final clipped = raw.length > 16 ? raw.substring(0, 16) : raw;

    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write('-');
      }
      buffer.write(clipped[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
