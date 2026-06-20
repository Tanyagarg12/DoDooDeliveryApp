import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _rateCtrl = TextEditingController();
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
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final m = await _db.offlineReminderMinutes();
    final rate = await _db.pricePerKm();
    if (!mounted) return;
    setState(() {
      _minutesCtrl.text = m.toString();
      _rateCtrl.text = rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2);
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
    final rate = double.tryParse(_rateCtrl.text.trim());
    if (rate == null || rate < 0 || rate > 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price per km.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _db.setSetting('offline_reminder_minutes', mins.toString());
      await _db.setSetting('price_per_km', rate.toString());
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
                _card('Pricing', [
                  const Text(
                    'Delivery rate per kilometre. Used as the fare for imported '
                    'orders that don\'t carry a price.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Price per km (₹)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                    ),
                  ),
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
