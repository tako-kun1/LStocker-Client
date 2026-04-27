import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/inventory.dart';
import '../providers/product_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/settings_provider.dart';
import 'product_registration_screen.dart';
import 'components/barcode_scanner.dart';

class InventoryRegistrationScreen extends StatefulWidget {
  const InventoryRegistrationScreen({super.key});

  @override
  State<InventoryRegistrationScreen> createState() =>
      _InventoryRegistrationScreenState();
}

class _InventoryRegistrationScreenState
    extends State<InventoryRegistrationScreen> {
  static const int _maxJanLength = 24;
  final _janController = TextEditingController();
  final _janFocusNode = FocusNode();
  final _dateController = TextEditingController();
  final _dateFocusNode = FocusNode();
  final _quantityController = TextEditingController();
  final _quantityFocusNode = FocusNode();
  Product? _foundProduct;
  bool _isLoading = false;

  String _normalizeJan(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > _maxJanLength
        ? digits.substring(0, _maxJanLength)
        : digits;
  }

  String _normalizeJanFromCamera(String value) {
    final normalized = _normalizeJan(value);
    if (normalized.length <= 1) return normalized;
    return normalized.substring(0, normalized.length - 1);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _janFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _janController.dispose();
    _janFocusNode.dispose();
    _dateController.dispose();
    _dateFocusNode.dispose();
    _quantityController.dispose();
    _quantityFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _searchProduct(String jan) async {
    final normalizedJan = _normalizeJan(jan);
    if (normalizedJan.isEmpty) return false;

    if (_janController.text != normalizedJan) {
      _janController.text = normalizedJan;
      _janController.selection = TextSelection.collapsed(
        offset: normalizedJan.length,
      );
    }

    setState(() => _isLoading = true);
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final product = await provider.getProduct(normalizedJan);
    setState(() {
      _foundProduct = product;
      _isLoading = false;
    });

    return product != null;
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<ScanResult>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null) {
      final normalized = result.isFromCamera
          ? _normalizeJanFromCamera(result.rawValue)
          : _normalizeJan(result.rawValue);
      _janController.text = normalized;
      _janController.selection = TextSelection.collapsed(
        offset: normalized.length,
      );
      final found = await _searchProduct(normalized);
      if (found && mounted) {
        _dateFocusNode.requestFocus();
      }
    }
  }

  Future<void> _saveInventory() async {
    if (_foundProduct == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('商品を特定してください')));
      return;
    }
    final dateText = _dateController.text;
    if (!RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(dateText)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日付形式が不正です (YYYY/MM/DD)')));
      return;
    }

    final dateParts = dateText.split('/');
    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    if (year == null || month == null || day == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日付形式が不正です (YYYY/MM/DD)')));
      return;
    }
    if (month < 1 || month > 12) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('月は 01 から 12 の範囲で入力してください')));
      return;
    }
    if (day < 1 || day > 31) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日は 01 から 31 の範囲で入力してください')));
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('数量を正しく入力してください')));
      return;
    }

    try {
      final expirationDate = DateTime(year, month, day);
      if (expirationDate.year != year ||
          expirationDate.month != month ||
          expirationDate.day != day) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('存在しない日付です')));
        return;
      }

      final inventory = Inventory(
        janCode: _foundProduct!.janCode,
        expirationDate: expirationDate,
        quantity: quantity,
        registrationDate: DateTime.now(),
      );

      await Provider.of<InventoryProvider>(
        context,
        listen: false,
      ).addInventory(inventory);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('在庫を登録しました')));
        setState(() {
          _janController.clear();
          _dateController.clear();
          _quantityController.clear();
          _foundProduct = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存に失敗しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('在庫登録')),
      body: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.tab):
              DoNothingAndStopPropagationIntent(),
          SingleActivator(LogicalKeyboardKey.enter):
              DoNothingAndStopPropagationIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter):
              DoNothingAndStopPropagationIntent(),
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _janController,
                      focusNode: _janFocusNode,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'JANコード'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.none,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_maxJanLength),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner),
                  ),
                  IconButton(
                    onPressed: () => _searchProduct(_janController.text),
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
              if (_foundProduct != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        if (_foundProduct!.imagePath.isNotEmpty)
                          Image.file(
                            File(_foundProduct!.imagePath),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          )
                        else
                          const Icon(Icons.image_not_supported, size: 80),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _foundProduct!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text('JAN: ${_foundProduct!.janCode}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('賞味期限を入力してください。'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dateController,
                  focusNode: _dateFocusNode,
                  decoration: const InputDecoration(
                    labelText: '賞味期限 (YYYYMMDD入力)',
                    hintText: '例: 20260712 (自動で 2026/07/12 に変換)',
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.none,
                  inputFormatters: [_DateInputFormatter()],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  focusNode: _quantityFocusNode,
                  decoration: const InputDecoration(labelText: '数量'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.none,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveInventory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('在庫登録を確定する', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ] else if (_janController.text.isNotEmpty && !_isLoading) ...[
                const Center(child: Text('商品が見つかりません。先に商品を登録してください。')),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProductRegistrationScreen(),
                    ),
                  ),
                  child: const Text('商品登録画面へ'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text
        .replaceAllMapped(RegExp(r'[０-９]'), (match) {
          final code = match.group(0)!.codeUnitAt(0) - 0xFF10;
          return String.fromCharCode(0x30 + code);
        })
        .replaceAll(RegExp(r'[^0-9]'), '');

    // 月の先頭文字が2~9の場合、自動で0を補完する
    if (text.length >= 5) {
      final m1 = text[4];
      if (['2', '3', '4', '5', '6', '7', '8', '9'].contains(m1)) {
        text = text.substring(0, 4) + '0' + text.substring(4);
      }
    }

    // 日の先頭文字が4~9の場合、自動で0を補完する
    if (text.length >= 7) {
      final d1 = text[6];
      if (['4', '5', '6', '7', '8', '9'].contains(d1)) {
        text = text.substring(0, 6) + '0' + text.substring(6);
      }
    }

    if (text.length > 8) {
      text = text.substring(0, 8);
    }

    String formatted = '';

    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if ((i == 3 || i == 5) && i != text.length - 1) {
        formatted += '/';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
