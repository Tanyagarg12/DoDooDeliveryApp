import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/firebase/firebase_refs.dart';
import '../../../../core/firebase/store_menu_service.dart';
import '../../../../core/firebase/store_order_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../../auth/presentation/widgets/custom_text_field.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/entities/store_entity.dart';

/// Model B — a store creates a delivery order itself (walk-in / phone order).
/// Items are picked from the store's Menu (bill = item total = store payout);
/// if the menu is empty, the store can type items + amount manually.
class StoreCreateOrderScreen extends StatefulWidget {
  const StoreCreateOrderScreen({super.key, required this.store});
  final StoreEntity store;

  @override
  State<StoreCreateOrderScreen> createState() => _StoreCreateOrderScreenState();
}

class _StoreCreateOrderScreenState extends State<StoreCreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dropCtrl = TextEditingController();
  final _itemsCtrl = TextEditingController(); // manual fallback
  final _amountCtrl = TextEditingController(); // manual fallback
  bool _saving = false;

  List<MenuItem> _menu = [];
  final Map<String, int> _qty = {}; // itemId → quantity
  bool _loadingMenu = true;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      final items = await StoreMenuService.instance.getMenu(widget.store.id);
      if (!mounted) return;
      setState(() {
        _menu = items.where((i) => i.available).toList();
        _loadingMenu = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMenu = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dropCtrl.dispose();
    _itemsCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  bool get _hasMenu => _menu.isNotEmpty;

  double get _menuTotal {
    double t = 0;
    for (final it in _menu) {
      // Bill uses the discounted price so active offers actually reduce it.
      t += it.finalPrice * (_qty[it.id] ?? 0);
    }
    return t;
  }

  String get _menuSummary => _menu
      .where((it) => (_qty[it.id] ?? 0) > 0)
      .map((it) => '${_qty[it.id]}× ${it.name}')
      .join(', ');

  Future<double> _riderEarning() async {
    try {
      final snap = await Db.appSettings.doc('min_delivery_charge').get();
      return double.tryParse(snap.data()?['value']?.toString() ?? '') ?? 42.0;
    } catch (_) {
      return 42.0;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    String itemsSummary;
    double? amount;
    if (_hasMenu) {
      if (_menuTotal <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one item from the menu')),
        );
        return;
      }
      itemsSummary = _menuSummary;
      amount = double.parse(_menuTotal.toStringAsFixed(2));
    } else {
      itemsSummary = _itemsCtrl.text.trim();
      amount = double.tryParse(_amountCtrl.text.trim());
    }

    setState(() => _saving = true);
    try {
      final earning = await _riderEarning();
      final store = widget.store;
      await StoreOrderService.instance.createOrder(
        storeId: store.id,
        storeName: store.storeName,
        fromAddress: store.address,
        cityCode: store.cityCode,
        customerName: _nameCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        dropAddress: _dropCtrl.text.trim(),
        itemsSummary: itemsSummary,
        orderAmount: amount,
        riderEarning: earning,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order created. Accept it to start.')),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Could not create the order. Try again.'),
              backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1C00),
        title: const Text('New Order',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: const [SupportIconButton()],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pickup is your store: ${widget.store.address}',
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.grey.shade800),
                    ),
                  ),
                ],
              ),
            ),
            CustomTextField(
              label: 'Customer Name *',
              hint: 'Who is this order for?',
              controller: _nameCtrl,
              validator: (v) => Validators.required(v, field: 'Customer name'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Customer Phone *',
              hint: '10-digit mobile number',
              controller: _phoneCtrl,
              validator: Validators.phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Delivery Address *',
              hint: 'Where should the rider deliver?',
              controller: _dropCtrl,
              validator: (v) =>
                  Validators.required(v, field: 'Delivery address'),
              maxLines: 3,
              keyboardType: TextInputType.streetAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),
            _itemsSection(),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.onPrimary))
                  : const Text('Create order', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemsSection() {
    if (_loadingMenu) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
    }
    if (!_hasMenu) {
      // No menu yet — manual entry fallback.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Items'),
          const SizedBox(height: 8),
          Text(
            'Tip: add items to your Menu tab for one-tap ordering & auto totals.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          CustomTextField(
            label: 'Items *',
            hint: 'e.g. 2× Veg Biryani, 1× Coke',
            controller: _itemsCtrl,
            validator: (v) => Validators.required(v, field: 'Items'),
            maxLines: 2,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Bill Amount (₹) *',
            hint: 'Order total',
            controller: _amountCtrl,
            validator: (v) {
              final d = double.tryParse(v?.trim() ?? '');
              if (d == null || d <= 0) return 'Enter a valid amount';
              return null;
            },
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
          ),
        ],
      );
    }

    // Menu picker with quantity steppers + live total.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Items from menu *'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8F0EE)),
          ),
          child: Column(
            children: [
              ..._menu.map(_menuRow),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    const Text('Bill total (store earns)',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('₹${_menuTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppColors.accent)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menuRow(MenuItem it) {
    final q = _qty[it.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (it.hasDiscount)
                  Row(
                    children: [
                      Text('₹${it.price.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade500,
                              decoration: TextDecoration.lineThrough)),
                      const SizedBox(width: 5),
                      Text('₹${it.finalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.w800)),
                      const SizedBox(width: 5),
                      Text('${it.discountPercent.toStringAsFixed(0)}% off',
                          style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w700)),
                    ],
                  )
                else
                  Text('₹${it.price.toStringAsFixed(0)}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: q > 0 ? AppColors.accent : Colors.grey.shade300,
            onPressed: q > 0
                ? () => setState(() => _qty[it.id] = q - 1)
                : null,
          ),
          SizedBox(
            width: 22,
            child: Text('$q',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_rounded),
            color: AppColors.primary,
            onPressed: () => setState(() => _qty[it.id] = q + 1),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600, color: const Color(0xFF374151)));
}
