import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/dodoo_cities.dart';
import '../../../../core/firebase/admin_firestore_service.dart';
import '../controllers/admin_controller.dart';
import 'admin_login_screen.dart';

/// Admin settings — currently the offline-reminder timing + logout.
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  static const _lime = Color(0xFFBABC2F);
  static const _ink = Color(0xFF1C1D00);

  final _db = AdminFirestoreService.instance;
  final _minutesCtrl = TextEditingController();
  final _baseFareCtrl = TextEditingController(); // flat base added to earning
  final _minChargeCtrl = TextEditingController(); // min store earning (floor)
  final _pdpChargeCtrl = TextEditingController(); // flat PDP earning
  // One km-rate field per city.
  final Map<String, TextEditingController> _rateCtrls = {
    for (final c in DodooCities.all) c.code: TextEditingController(),
  };
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minutesCtrl.dispose();
    _baseFareCtrl.dispose();
    _minChargeCtrl.dispose();
    _pdpChargeCtrl.dispose();
    for (final c in _rateCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final m = await _db.offlineReminderMinutes();
    final base = await _db.riderBaseFare();
    final minC = await _db.minDeliveryCharge();
    final pdp = await _db.pickDropCharge();
    for (final city in DodooCities.all) {
      final r = await _db.pricePerKm(cityCode: city.code);
      _rateCtrls[city.code]!.text =
          r.toStringAsFixed(r.truncateToDouble() == r ? 0 : 2);
    }
    if (!mounted) return;
    setState(() {
      String fmt(double d) =>
          d.toStringAsFixed(d.truncateToDouble() == d ? 0 : 2);
      _minutesCtrl.text = m.toString();
      _baseFareCtrl.text = fmt(base);
      _minChargeCtrl.text = fmt(minC);
      _pdpChargeCtrl.text = fmt(pdp);
      _loading = false;
    });
  }

  Future<void> _save() async {
    final mins = int.tryParse(_minutesCtrl.text.trim());
    if (mins == null || mins < 1 || mins > 1440) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter minutes between 1 and 1440.')),
      );
      return;
    }
    for (final city in DodooCities.all) {
      final rate = double.tryParse(_rateCtrls[city.code]!.text.trim());
      if (rate == null || rate < 0 || rate > 10000) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter a valid price per km for ${city.name}.')),
        );
        return;
      }
    }
    final base = double.tryParse(_baseFareCtrl.text.trim());
    if (base == null || base < 0 || base > 100000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid base fare.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _db.setSetting('offline_reminder_minutes', mins.toString());
      await _db.setSetting('rider_base_fare', _baseFareCtrl.text.trim());
      await _db.setSetting('min_delivery_charge', _minChargeCtrl.text.trim());
      await _db.setSetting('pickdrop_charge', _pdpChargeCtrl.text.trim());
      for (final city in DodooCities.all) {
        await _db.setSetting(
            'price_per_km_${city.code}', _rateCtrls[city.code]!.text.trim());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Settings saved.'), backgroundColor: _lime),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Save failed: $e'),
              backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(adminAuthControllerProvider.notifier).logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7E8),
      appBar: AppBar(
        backgroundColor: _lime,
        foregroundColor: _ink,
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card('Rider Reminders', [
                  const Text(
                    'Notify a rider to go online after they have been offline '
                    'for this many minutes.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _minutesCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Offline reminder (minutes)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                _card('Rider earning', [
                  const Text(
                    'Store orders: base fare + (distance km × city per-km rate), '
                    'never below the minimum delivery charge. Pick & Drop (PDP) '
                    'orders pay a flat charge.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _baseFareCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Base fare (₹)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _minChargeCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Minimum delivery charge (₹)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.south_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pdpChargeCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Pick & Drop (PDP) charge (₹)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.swap_horiz_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Per-km rate by city (₹)',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  for (final city in DodooCities.all) ...[
                    TextField(
                      controller: _rateCtrls[city.code],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: '${city.name} — price per km (₹)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.currency_rupee_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ]),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _ink))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save settings'),
                  style: FilledButton.styleFrom(
                      backgroundColor: _lime,
                      minimumSize: const Size.fromHeight(50)),
                ),
                const SizedBox(height: 16),
                _card('Account', [
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Logout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ]),
              ],
            ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E3E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: _ink)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
