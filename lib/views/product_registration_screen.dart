import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../services/dept_service.dart';
import 'components/barcode_scanner.dart';
import 'components/camera_screen.dart';

class ProductRegistrationScreen extends StatefulWidget {
  final Product? editProduct;
  const ProductRegistrationScreen({super.key, this.editProduct});

  @override
  State<ProductRegistrationScreen> createState() => _ProductRegistrationScreenState();
}

class _ProductRegistrationScreenState extends State<ProductRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _janController = TextEditingController();
  final _janFocusNode = FocusNode();
  final _nameController = TextEditingController();
  final _deptController = TextEditingController();
  final _salesPeriodController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _selectedDept;
  String? _imagePath;
  bool _isEditing = false;

  String _normalizeJan(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 13 ? digits.substring(0, 13) : digits;
  }

  @override
  void initState() {
    super.initState();
    if (widget.editProduct != null) {
      _isEditing = true;
      _janController.text = widget.editProduct!.janCode;
      _nameController.text = widget.editProduct!.name;
      _deptController.text = widget.editProduct!.deptNumber.toString();
      _salesPeriodController.text = widget.editProduct!.salesPeriod.toString();
      _descriptionController.text = widget.editProduct!.description;
      _selectedDept = widget.editProduct!.deptNumber;
      _imagePath = widget.editProduct!.imagePath;
    }
  }

  @override
  void dispose() {
    _janController.dispose();
    _janFocusNode.dispose();
    _nameController.dispose();
    _deptController.dispose();
    _salesPeriodController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final navigator = Navigator.of(context);
    final result = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted) return;
    if (result != null) {
      final normalized = _normalizeJan(result);
      setState(() {
        _janController.text = normalized;
        _janController.selection = TextSelection.collapsed(offset: normalized.length);
      });
    }
  }

  Future<void> _takePhoto() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    if (!mounted) return;
    final navigator = Navigator.of(context);
    final result = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => CameraScreen(camera: cameras.first)),
    );

    if (result != null) {
      setState(() {
        _imagePath = result;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final normalizedJan = _normalizeJan(_janController.text);
    _janController.text = normalizedJan;

    final dept = int.tryParse(_deptController.text);
    final availableDeptIds = DeptService.getAvailableDeptIds();
    if (dept == null || !availableDeptIds.contains(dept)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('有効なDEPT番号を入力してください')));
      return;
    }
    _selectedDept = dept;

    final product = Product(
      janCode: normalizedJan,
      name: _nameController.text,
      imagePath: _imagePath ?? '',
      deptNumber: _selectedDept!,
      salesPeriod: int.parse(_salesPeriodController.text),
      description: _descriptionController.text,
    );

    final provider = Provider.of<ProductProvider>(context, listen: false);
    if (_isEditing) {
      await provider.updateProduct(product);
    } else {
      await provider.addProduct(product);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '商品情報編集' : '商品登録'),
        actions: [
          IconButton(onPressed: _saveProduct, icon: const Icon(Icons.save)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _janController,
                      focusNode: _janFocusNode,
                      decoration: const InputDecoration(labelText: 'JANコード'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(13),
                      ],
                      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      validator: (v) => v == null || v.isEmpty ? '入力してください' : null,
                    ),
                  ),
                  IconButton(onPressed: _scanBarcode, icon: const Icon(Icons.qr_code_scanner)),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '商品名'),
                validator: (v) => v == null || v.isEmpty ? '入力してください' : null,
              ),
              const SizedBox(height: 16),
              const Text('商品画像'),
              const SizedBox(height: 8),
              if (_imagePath != null && _imagePath!.isNotEmpty)
                Image.file(File(_imagePath!), height: 200, fit: BoxFit.cover),
              ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('カメラで撮影 (600x600)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deptController,
                decoration: const InputDecoration(
                  labelText: 'DEPT番号',
                  hintText: '数字で入力 (例: 1)',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return '入力してください';
                  final val = int.tryParse(v);
                  if (val == null || !DeptService.getAvailableDeptIds().contains(val)) {
                    return '有効なDEPT番号を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salesPeriodController,
                decoration: const InputDecoration(labelText: '販売許容期間 (0～1000)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return '入力してください';
                  final val = int.tryParse(v);
                  if (val == null || val < 0 || val > 1000) return '0から1000の間で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: '商品情報 (最大2000文字)'),
                maxLines: 5,
                maxLength: 2000,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveProduct,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(_isEditing ? '更新する' : '登録する', style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
