// lib/features/petshop/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';
import 'cart_provider.dart';

const _coral = Color(0xFFF36C6C);
const _coralSoft = Color(0xFFFFEEF0);
const _ink = Color(0xFF222222);

// Dark mode colors
const _darkBg = Color(0xFF121212);
const _darkCard = Color(0xFF1E1E1E);
const _darkCardBorder = Color(0xFF2A2A2A);

// Storage keys for checkout info (shared with user_settings_screen)
const _kDeliveryAddress = 'user_delivery_address';
const _kCheckoutNotes = 'checkout_notes';
const _kDeliveryMode = 'checkout_delivery_mode';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  bool _loadingProfile = true;
  String _deliveryMode = 'pickup'; // 'delivery' or 'pickup'
  bool _providerDeliveryEnabled = false;
  bool _providerPickupEnabled = true;
  int? _deliveryFeeDa;
  int? _freeDeliveryAboveDa;
  int _commissionPercent = 5; // Default 5%, will be loaded from provider

  @override
  void initState() {
    super.initState();
    _loadProfileAndSavedInfo();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Load user profile data first, then fallback to saved checkout info
  Future<void> _loadProfileAndSavedInfo() async {
    setState(() => _loadingProfile = true);

    try {
      // 1. Try to get phone from user profile
      final api = ref.read(apiProvider);
      final me = await api.me();
      final profilePhone = (me['phone'] ?? '').toString();

      if (profilePhone.isNotEmpty) {
        _phoneController.text = profilePhone;
      }

      // 2. Load delivery address from storage (shared with settings)
      final savedAddress = await _storage.read(key: _kDeliveryAddress);
      if (savedAddress != null && savedAddress.isNotEmpty) {
        _addressController.text = savedAddress;
      }

      // 3. Load notes from storage
      final savedNotes = await _storage.read(key: _kCheckoutNotes);
      if (savedNotes != null && savedNotes.isNotEmpty) {
        _notesController.text = savedNotes;
      }

      // 4. Load delivery mode preference
      final savedDeliveryMode = await _storage.read(key: _kDeliveryMode);
      if (savedDeliveryMode != null && (savedDeliveryMode == 'delivery' || savedDeliveryMode == 'pickup')) {
        _deliveryMode = savedDeliveryMode;
      }

      // 5. Load delivery options from the first provider in cart
      final cart = ref.read(cartProvider);
      if (cart.items.isNotEmpty) {
        final firstProviderId = cart.items.first.providerId;
        try {
          final deliveryOptions = await api.getDeliveryOptions(firstProviderId);
          _providerDeliveryEnabled = deliveryOptions['deliveryEnabled'] == true;
          _providerPickupEnabled = deliveryOptions['pickupEnabled'] != false;
          _deliveryFeeDa = deliveryOptions['deliveryFeeDa'] as int?;
          _freeDeliveryAboveDa = deliveryOptions['freeDeliveryAboveDa'] as int?;
          // Load commission percent from provider (default 5%)
          _commissionPercent = (deliveryOptions['commissionPercent'] as num?)?.toInt() ?? 5;

          // Set default mode based on available options
          if (!_providerPickupEnabled && _providerDeliveryEnabled) {
            _deliveryMode = 'delivery';
          } else if (!_providerDeliveryEnabled && _providerPickupEnabled) {
            _deliveryMode = 'pickup';
          }
        } catch (_) {
          // Use defaults if API fails
        }
      }
    } catch (e) {
      // If profile fetch fails, just continue with empty fields
      debugPrint('Failed to load profile: $e');
    }

    if (mounted) {
      setState(() => _loadingProfile = false);
    }
  }

  /// Save checkout info for future orders
  Future<void> _saveCheckoutInfo() async {
    // Save address (shared key with settings)
    await _storage.write(key: _kDeliveryAddress, value: _addressController.text.trim());
    await _storage.write(key: _kCheckoutNotes, value: _notesController.text.trim());
    await _storage.write(key: _kDeliveryMode, value: _deliveryMode);

    // Also update phone in profile if changed
    try {
      final api = ref.read(apiProvider);
      final me = await api.me();
      final currentPhone = (me['phone'] ?? '').toString();

      if (_phoneController.text.trim() != currentPhone && _phoneController.text.trim().isNotEmpty) {
        await api.meUpdate(phone: _phoneController.text.trim());
      }
    } catch (_) {
      // Ignore profile update errors
    }
  }

  String _da(int v) => '${NumberFormat.decimalPattern("fr_FR").format(v)} DA';

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre panier est vide')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiProvider);
      final notifier = ref.read(cartProvider.notifier);

      // Create orders for each provider
      final itemsByProvider = cart.itemsByProvider;
      final orderIds = <String>[];

      for (final entry in itemsByProvider.entries) {
        final providerId = entry.key;
        final items = notifier.toApiItems(providerId);
        final total = notifier.totalForProvider(providerId);

        final result = await api.createPetshopOrder(
          providerId: providerId,
          items: items,
          deliveryAddress: _deliveryMode == 'delivery' ? _addressController.text.trim() : null,
          notes: _notesController.text.trim(),
          phone: _phoneController.text.trim(),
          deliveryMode: _deliveryMode,
          totalDa: total,
        );

        final orderId = result['id']?.toString() ?? '';
        if (orderId.isNotEmpty) {
          orderIds.add(orderId);
        }
      }

      // Save checkout info for future orders
      await _saveCheckoutInfo();

      // Clear cart after successful order
      notifier.clear();

      if (mounted) {
        // Navigate to confirmation
        // Use subtotalDa since item prices already include commission
        context.go('/petshop/order-confirmation', extra: {
          'orderId': orderIds.isNotEmpty ? orderIds.first : null,
          'totalDa': cart.subtotalDa,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Calculate actual delivery fee considering free delivery threshold
  int _calculateDeliveryFee(int subtotalDa) {
    if (_deliveryMode != 'delivery') return 0;
    if (_freeDeliveryAboveDa != null && subtotalDa >= _freeDeliveryAboveDa!) return 0;
    return _deliveryFeeDa ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final l10n = AppLocalizations.of(context);

    // Theme colors
    final bgColor = isDark ? _darkBg : const Color(0xFFF7F8FA);
    final cardColor = isDark ? _darkCard : Colors.white;
    final textPrimary = isDark ? Colors.white : _ink;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? _darkCardBorder : Colors.grey.shade200;

    return Theme(
      data: _themed(context, isDark),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(l10n.petshopFinalizeOrder),
          backgroundColor: cardColor,
          foregroundColor: textPrimary,
        ),
        body: _loadingProfile
            ? const Center(child: CircularProgressIndicator(color: _coral))
            : cart.isEmpty
                ? _buildEmptyCart(isDark, textPrimary, textSecondary, l10n)
                : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Info banner
                          if (_phoneController.text.isNotEmpty || _addressController.text.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _coral.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: _coral, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      l10n.petshopInfoFromProfile,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _coral,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => context.push('/profile/settings'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _coral,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 30),
                                    ),
                                    child: Text(l10n.petshopModify, style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),

                          // Delivery mode selection
                          if (_providerDeliveryEnabled || _providerPickupEnabled)
                            _buildDeliveryModeSection(
                              cart.subtotalDa,
                              isDark,
                              cardColor,
                              textPrimary,
                              textSecondary,
                              borderColor,
                              l10n,
                            ),

                          if (_providerDeliveryEnabled || _providerPickupEnabled)
                            const SizedBox(height: 16),

                          // Phone number
                          _buildSection(
                            icon: Icons.phone_outlined,
                            title: l10n.petshopPhoneNumber,
                            required: true,
                            isDark: isDark,
                            cardColor: cardColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(color: textPrimary),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: _inputDecoration(
                                hintText: '0555 00 00 00',
                                prefixText: '+213 ',
                                isDark: isDark,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return l10n.petshopPhoneRequired;
                                }
                                if (value.trim().length < 9) {
                                  return l10n.petshopInvalidPhone;
                                }
                                return null;
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Delivery address (only show if delivery mode)
                          if (_deliveryMode == 'delivery')
                            _buildSection(
                              icon: Icons.location_on_outlined,
                              title: l10n.petshopDeliveryAddress,
                              required: true,
                              isDark: isDark,
                              cardColor: cardColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              child: TextFormField(
                                controller: _addressController,
                                maxLines: 3,
                                textCapitalization: TextCapitalization.sentences,
                                style: TextStyle(color: textPrimary),
                                decoration: _inputDecoration(
                                  hintText: l10n.petshopAddressHint,
                                  isDark: isDark,
                                ),
                                validator: (value) {
                                  if (_deliveryMode != 'delivery') return null;
                                  if (value == null || value.trim().isEmpty) {
                                    return l10n.petshopAddressRequired;
                                  }
                                  if (value.trim().length < 10) {
                                    return l10n.petshopAddressTooShort;
                                  }
                                  return null;
                                },
                              ),
                            ),

                          if (_deliveryMode == 'delivery')
                            const SizedBox(height: 16),

                          // Notes
                          _buildSection(
                            icon: Icons.note_outlined,
                            title: _deliveryMode == 'delivery'
                                ? l10n.petshopDeliveryInstructions
                                : l10n.petshopSellerNotes,
                            subtitle: l10n.petshopOptional,
                            isDark: isDark,
                            cardColor: cardColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            child: TextFormField(
                              controller: _notesController,
                              maxLines: 2,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(color: textPrimary),
                              decoration: _inputDecoration(
                                hintText: _deliveryMode == 'delivery'
                                    ? l10n.petshopDeliveryExample
                                    : l10n.petshopPickupExample,
                                isDark: isDark,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Order summary
                          _buildOrderSummary(cart, isDark, cardColor, textPrimary, textSecondary, l10n),
                        ],
                      ),
                    ),

                    // Bottom bar with total and submit
                    _buildBottomBar(cart, isDark, cardColor, textPrimary, textSecondary, borderColor, l10n),
                  ],
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required bool isDark,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
      prefixStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
      filled: true,
      fillColor: isDark ? _darkCardBorder : Colors.grey.shade50,
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
        borderSide: const BorderSide(color: _coral, width: 2),
      ),
    );
  }

  Widget _buildDeliveryModeSection(
    int subtotalDa,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color? textSecondary,
    Color borderColor,
    AppLocalizations l10n,
  ) {
    final deliveryFee = _calculateDeliveryFee(subtotalDa);
    final freeDelivery = _freeDeliveryAboveDa != null && subtotalDa >= _freeDeliveryAboveDa!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? null : [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.local_shipping_rounded, color: Colors.blue.shade400, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.petshopReceptionMode,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pickup option
          if (_providerPickupEnabled)
            _buildDeliveryOption(
              icon: Icons.store_rounded,
              title: l10n.petshopPickupOption,
              subtitle: l10n.petshopPickupHint,
              isSelected: _deliveryMode == 'pickup',
              onTap: () => setState(() => _deliveryMode = 'pickup'),
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

          if (_providerPickupEnabled && _providerDeliveryEnabled)
            const SizedBox(height: 10),

          // Delivery option
          if (_providerDeliveryEnabled)
            _buildDeliveryOption(
              icon: Icons.local_shipping_rounded,
              title: l10n.petshopDeliveryOption,
              subtitle: freeDelivery
                  ? l10n.petshopFreeDelivery
                  : (deliveryFee > 0 ? '+$deliveryFee DA' : l10n.petshopFree),
              isSelected: _deliveryMode == 'delivery',
              onTap: () => setState(() => _deliveryMode = 'delivery'),
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              badge: freeDelivery ? l10n.petshopFree.toUpperCase() : null,
            ),

          // Free delivery info
          if (_providerDeliveryEnabled && _freeDeliveryAboveDa != null && !freeDelivery)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.green.withOpacity(0.1) : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${l10n.petshopFreeDeliveryInfo} ${_freeDeliveryAboveDa} DA ${l10n.petshopPurchase}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color textPrimary,
    Color? textSecondary,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? _coral.withOpacity(0.15) : _coralSoft)
              : (isDark ? _darkCardBorder : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _coral : (isDark ? _darkCardBorder : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? _coral.withOpacity(isDark ? 0.3 : 0.2)
                    : (isDark ? Colors.grey[800] : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? _coral : (isDark ? Colors.grey[400] : Colors.grey[600]),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isSelected ? _coral : textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: _coral,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart(bool isDark, Color textPrimary, Color? textSecondary, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? _coral.withOpacity(0.15) : _coralSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined, size: 64, color: _coral),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.petshopEmptyCart,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.petshopAddProductsToOrder,
            style: TextStyle(color: textSecondary),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: _coral,
              side: const BorderSide(color: _coral),
            ),
            child: Text(l10n.petshopBackToProducts),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    String? subtitle,
    bool required = false,
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    Color? textSecondary,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _darkCardBorder : Colors.transparent),
        boxShadow: isDark ? null : const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _coral, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: textPrimary,
                          ),
                        ),
                        if (required) ...[
                          const SizedBox(width: 4),
                          const Text(
                            '*',
                            style: TextStyle(color: _coral, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  /// Calculate commission based on subtotal using provider's commission rate
  int _calculateCommission(int subtotalDa) {
    return (subtotalDa * _commissionPercent / 100).round();
  }

  Widget _buildOrderSummary(CartState cart, bool isDark, Color cardColor, Color textPrimary, Color? textSecondary, AppLocalizations l10n) {
    final deliveryFee = _calculateDeliveryFee(cart.subtotalDa);
    final commissionDa = _calculateCommission(cart.subtotalDa);
    final totalWithDelivery = cart.subtotalDa + commissionDa + deliveryFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _darkCardBorder : Colors.transparent),
        boxShadow: isDark ? null : const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? _coral.withOpacity(0.2) : _coralSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long, color: _coral, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.petshopSummary,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Items
          ...cart.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item.quantity}x',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: textPrimary),
                      ),
                    ),
                    Text(
                      _da(item.totalDa),
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textPrimary),
                    ),
                  ],
                ),
              )),

          Divider(height: 24, color: isDark ? _darkCardBorder : Colors.grey.shade200),

          // Subtotal
          _buildSummaryRow(l10n.petshopSubtotal, _da(cart.subtotalDa), isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary),
          const SizedBox(height: 8),

          // Commission / Service fee
          _buildSummaryRow(l10n.petshopServiceFee, _da(commissionDa), isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary),
          const SizedBox(height: 8),

          // Delivery fee row - always shows "to discuss with store" when no fee set
          if (_deliveryMode == 'delivery')
            _buildSummaryRow(
              l10n.petshopDeliveryFee,
              _deliveryFeeDa != null && _deliveryFeeDa! > 0
                  ? (deliveryFee == 0 ? l10n.petshopFree : _da(deliveryFee))
                  : l10n.petshopDeliveryFeeToDiscuss,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              valueColor: _deliveryFeeDa != null && _deliveryFeeDa! > 0 && deliveryFee == 0 ? Colors.green : Colors.orange,
            ),

          if (_deliveryMode == 'delivery')
            const SizedBox(height: 8),

          // Mode badge
          Row(
            children: [
              Icon(
                _deliveryMode == 'delivery' ? Icons.local_shipping_rounded : Icons.store_rounded,
                size: 14,
                color: textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                _deliveryMode == 'delivery' ? l10n.petshopDeliveryOption : l10n.petshopPickupOption,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          Divider(height: 24, color: isDark ? _darkCardBorder : Colors.grey.shade200),

          // Total
          _buildSummaryRow(l10n.petshopTotal, _da(totalWithDelivery), isBold: true, isDark: isDark, textPrimary: textPrimary, textSecondary: textSecondary),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    required bool isDark,
    required Color textPrimary,
    Color? textSecondary,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? textPrimary : textSecondary,
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            fontSize: isBold ? 16 : 13,
            color: valueColor ?? (isBold ? _coral : textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(CartState cart, bool isDark, Color cardColor, Color textPrimary, Color? textSecondary, Color borderColor, AppLocalizations l10n) {
    final deliveryFee = _calculateDeliveryFee(cart.subtotalDa);
    final commissionDa = _calculateCommission(cart.subtotalDa);
    final totalWithDelivery = cart.subtotalDa + commissionDa + deliveryFee;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.petshopTotalToPay,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _da(totalWithDelivery),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_coral, Color(0xFFFF8A8A)]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _coral.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading ? null : _submitOrder,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check, size: 20, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                l10n.petshopConfirm,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ThemeData _themed(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: _coral,
        surface: isDark ? _darkCard : Colors.white,
        onPrimary: Colors.white,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: isDark ? _darkCard : Colors.white,
        foregroundColor: isDark ? Colors.white : _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : _ink,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _coral,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: _coral),
    );
  }
}
