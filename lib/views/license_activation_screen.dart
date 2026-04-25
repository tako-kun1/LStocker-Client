import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/inventory_provider.dart';
import '../services/inventory_backup_service.dart';
import '../services/product_key_service.dart';
import '../services/support_contact.dart';

class LicenseActivationScreen extends StatefulWidget {
  const LicenseActivationScreen({super.key});

  @override
  State<LicenseActivationScreen> createState() =>
      _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen> {
  final _controller = TextEditingController();
  final _service = ProductKeyService();
  final _inventoryBackupService = InventoryBackupService();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_submitting) return;

    final inventoryProvider = context.read<InventoryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _submitting = true);
    try {
      final result = await _service.activateProductKey(_controller.text);
      if (!mounted) return;

      if (result.success) {
        final restoreResult = await _inventoryBackupService
            .downloadLatestBackupForCurrentKey();
        if (!mounted) return;

        await inventoryProvider.fetchInventories();

        messenger.showSnackBar(
          SnackBar(
            content: Text('${result.message}\n${restoreResult.message}'),
          ),
        );
        navigator.pop(true);
        return;
      }

      messenger.showSnackBar(SnackBar(content: Text(result.message)));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _openSupportContact() async {
    if (!SupportContact.hasUrl) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('お問い合わせ先URLが未設定です。')),
      );
      return;
    }

    final uri = Uri.tryParse(SupportContact.effectiveUrl);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('お問い合わせ先URLの形式が不正です。')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('お問い合わせ先を開けませんでした。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supportName = SupportContact.effectiveName;
    final supportEmail = SupportContact.effectiveEmail;
    final supportPhone = SupportContact.effectivePhone;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('プロダクトキー認証'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'プロダクトキーを入力してください',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '形式: XXXX-XXXX-XXXX-XXXX（英大文字・数字）',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          labelText: 'プロダクトキー',
                          hintText: 'XXXX-XXXX-XXXX-XXXX',
                        ),
                        keyboardType: TextInputType.visiblePassword,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: const [_ProductKeyTextFormatter()],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _activate(),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: _submitting ? null : _activate,
                        child: Text(_submitting ? '認証とバックアップ取得中...' : '認証する'),
                      ),
                      if (SupportContact.hasAny) ...[
                        const SizedBox(height: 10),
                        if (SupportContact.hasName)
                          Text(
                            'お問い合わせ先: $supportName',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (SupportContact.hasEmail)
                          Text(
                            'メール: $supportEmail',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (SupportContact.hasPhone)
                          Text(
                            '電話: $supportPhone',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (SupportContact.hasUrl) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _openSupportContact,
                            icon: const Icon(Icons.support_agent),
                            label: const Text('お問い合わせ先を開く'),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
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
    final raw = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
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
