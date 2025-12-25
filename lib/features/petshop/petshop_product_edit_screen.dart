// lib/features/petshop/petshop_product_edit_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/locale_provider.dart';

// Colors
const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);

// Dark mode colors
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

class PetshopProductEditScreen extends ConsumerStatefulWidget {
  final String? productId;
  const PetshopProductEditScreen({super.key, this.productId});

  @override
  ConsumerState<PetshopProductEditScreen> createState() =>
      _PetshopProductEditScreenState();
}

class _PetshopProductEditScreenState
    extends ConsumerState<PetshopProductEditScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();

  bool _loading = false;
  bool _active = true;
  List<String> _imageUrls = [];
  List<File> _localImages = [];

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _loadProduct();
    }
  }

  Future<void> _loadProduct() async {
    if (widget.productId == null) return;
    setState(() => _loading = true);
    try {
      final products = await ref.read(apiProvider).myProducts();
      final product = products.firstWhere(
        (p) => (p['id'] ?? '').toString() == widget.productId,
      );
      _titleController.text = (product['title'] ?? '').toString();
      _descriptionController.text = (product['description'] ?? '').toString();
      _priceController.text = (product['priceDa'] ?? product['price'] ?? 0).toString();
      _stockController.text = (product['stock'] ?? 0).toString();
      _categoryController.text = (product['category'] ?? '').toString();
      _active = product['active'] != false;
      final urls = product['imageUrls'] as List?;
      if (urls != null) {
        _imageUrls = urls.map((e) => e.toString()).where((e) => e.startsWith('http')).toList();
      }
    } catch (e) {
      if (mounted) {
        final tr = AppLocalizations(ref.read(localeProvider));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr.error}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _localImages.add(File(image.path)));
    }
  }

  Future<void> _uploadImages() async {
    if (_localImages.isEmpty) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiProvider);
      for (final file in _localImages) {
        final url = await api.uploadLocalFile(file, folder: 'products');
        _imageUrls.add(url);
      }
      _localImages.clear();
    } catch (e) {
      if (mounted) {
        final tr = AppLocalizations(ref.read(localeProvider));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr.error}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final tr = AppLocalizations(ref.read(localeProvider));

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.titleRequired)),
      );
      return;
    }
    if (_priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.priceRequired)),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _uploadImages();

      final api = ref.read(apiProvider);
      final price = int.tryParse(_priceController.text.trim()) ?? 0;
      final stock = int.tryParse(_stockController.text.trim()) ?? 0;

      if (widget.productId == null) {
        await api.createProduct(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priceDa: price,
          stock: stock,
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
          imageUrls: _imageUrls.isEmpty ? null : _imageUrls,
          active: _active,
        );
      } else {
        await api.updateProduct(
          widget.productId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priceDa: price,
          stock: stock,
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
          imageUrls: _imageUrls.isEmpty ? null : _imageUrls,
          active: _active,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.productId == null ? tr.productCreated : tr.productUpdated),
        ),
      );
      context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr.error}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final tr = AppLocalizations(ref.read(localeProvider));
    final isDark = ref.read(themeProvider) == AppThemeMode.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        title: Text(
          tr.deleteProduct,
          style: TextStyle(color: isDark ? Colors.white : _ink),
        ),
        content: Text(
          tr.deleteProductConfirm,
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr.delete),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ref.read(apiProvider).deleteProduct(widget.productId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.productDeleted)),
      );
      context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr.error}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    final locale = ref.watch(localeProvider);
    final tr = AppLocalizations(locale);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.productId == null ? tr.newProduct : tr.editProduct,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _coral),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                tr.save,
                style: const TextStyle(color: _coral, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: _loading && widget.productId != null
          ? const Center(child: CircularProgressIndicator(color: _coral))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Images section
                  _buildCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.photo_library, color: Colors.blue, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              tr.productImages,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _imageUrls.length + _localImages.length + 1,
                            itemBuilder: (_, i) {
                              if (i == _imageUrls.length + _localImages.length) {
                                return _buildAddImageButton(isDark, tr);
                              }
                              if (i < _imageUrls.length) {
                                return _buildImageTile(
                                  image: NetworkImage(_imageUrls[i]),
                                  onRemove: () => setState(() => _imageUrls.removeAt(i)),
                                  isDark: isDark,
                                );
                              }
                              final localIdx = i - _imageUrls.length;
                              return _buildImageTile(
                                image: FileImage(_localImages[localIdx]),
                                onRemove: () => setState(() => _localImages.removeAt(localIdx)),
                                isDark: isDark,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Product info card
                  _buildCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.inventory_2, color: _coral, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              tr.productTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          '${tr.productTitle} *',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _titleController,
                          style: TextStyle(color: textPrimary),
                          decoration: _inputDecoration(isDark, tr.productTitleHint),
                        ),
                        const SizedBox(height: 16),

                        // Description
                        Text(
                          tr.productDescription,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _descriptionController,
                          maxLines: 4,
                          style: TextStyle(color: textPrimary),
                          decoration: _inputDecoration(isDark, tr.productDescriptionHint),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price and Stock card
                  _buildCard(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.green.withOpacity(0.15) : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.payments, color: Colors.green.shade600, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              tr.productPrice,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${tr.productPrice} *',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _priceController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: TextStyle(color: textPrimary),
                                    decoration: _inputDecoration(isDark, '0'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr.productStock,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _stockController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: TextStyle(color: textPrimary),
                                    decoration: _inputDecoration(isDark, '0'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Category
                        Text(
                          tr.productCategory,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _categoryController,
                          style: TextStyle(color: textPrimary),
                          decoration: _inputDecoration(isDark, tr.productCategoryHint),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Active toggle card
                  _buildCard(
                    isDark: isDark,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? (_active ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15))
                                : (_active ? Colors.green.shade50 : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _active ? Icons.visibility : Icons.visibility_off,
                            color: _active ? Colors.green : Colors.grey,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr.productActive,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                tr.productActiveHint,
                                style: TextStyle(fontSize: 12, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _active,
                          onChanged: (v) => setState(() => _active = v),
                          activeColor: Colors.green,
                          activeTrackColor: Colors.green.withOpacity(0.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Delete button if editing
                  if (widget.productId != null) ...[
                    OutlinedButton.icon(
                      onPressed: _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.delete),
                      label: Text(tr.delete, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Save button
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _loading ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _coral,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        tr.save,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _darkCardBorder : _coral.withOpacity(0.15)),
        boxShadow: isDark
            ? null
            : const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _buildAddImageButton(bool isDark, AppLocalizations tr) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isDark ? _darkCardBorder : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? _darkCardBorder : Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              tr.addImage,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageTile({
    required ImageProvider image,
    required VoidCallback onRemove,
    required bool isDark,
  }) {
    return Stack(
      children: [
        Container(
          width: 120,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(image: image, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 6,
          right: 14,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(bool isDark, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? _darkCardBorder : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _coral),
      ),
      filled: true,
      fillColor: isDark ? _darkCardBorder : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
