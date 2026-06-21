import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/cloudinary/cloudinary_service.dart';
import '../../data/datasources/admin_firestore_datasource.dart';

/// Lightweight persistent store for the admin's display name + photo.
/// Backed by shared_preferences; the avatar listens to [notifier].
class AdminProfile {
  AdminProfile._();
  static final AdminProfile instance = AdminProfile._();

  static const _kName = 'admin_profile_name';
  static const _kPhoto = 'admin_profile_photo';

  final ValueNotifier<({String name, String? photoUrl})> notifier =
      ValueNotifier((name: 'Admin', photoUrl: null));

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    notifier.value = (
      name: prefs.getString(_kName) ?? 'Admin',
      photoUrl: prefs.getString(_kPhoto),
    );
  }

  Future<void> save({required String name, String? photoUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, name);
    if (photoUrl != null) await prefs.setString(_kPhoto, photoUrl);
    notifier.value = (
      name: name,
      photoUrl: photoUrl ?? notifier.value.photoUrl,
    );
  }
}

/// Circular avatar that shows the admin's photo, or their initial in the
/// brand "D" style. Updates live when the profile changes.
class AdminAvatar extends StatelessWidget {
  const AdminAvatar({super.key, required this.name, this.radius = 16});
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<({String name, String? photoUrl})>(
      valueListenable: AdminProfile.instance.notifier,
      builder: (context, p, _) {
        final display = p.name.isNotEmpty ? p.name : name;
        final initial =
            display.isNotEmpty ? display[0].toUpperCase() : 'A';
        if (p.photoUrl != null && p.photoUrl!.isNotEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFF1C1D00).withValues(alpha: 0.18),
            backgroundImage: NetworkImage(p.photoUrl!),
          );
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFF1C1D00).withValues(alpha: 0.18),
          child: Text(
            initial,
            style: TextStyle(
                color: const Color(0xFF1C1D00),
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.9),
          ),
        );
      },
    );
  }
}

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  static const _lime = Color(0xFFBABC2F);
  static const _ink = Color(0xFF1C1D00);

  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    AdminProfile.instance.load().then((_) {
      if (mounted) {
        setState(() => _nameCtrl.text = AdminProfile.instance.notifier.value.name);
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return;
    setState(() => _saving = true);
    try {
      final uploaded = await CloudinaryService.instance.uploadFile(
        picked.path,
        folder: 'admin',
        publicId: 'profile',
      );
      // Cache-bust so the new image shows immediately.
      final url = '$uploaded?v=${DateTime.now().millisecondsSinceEpoch}';
      await AdminProfile.instance
          .save(name: _nameCtrl.text.trim().isEmpty ? 'Admin' : _nameCtrl.text.trim(), photoUrl: url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated.'), backgroundColor: _lime),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveName() async {
    setState(() => _saving = true);
    await AdminProfile.instance.save(
        name: _nameCtrl.text.trim().isEmpty ? 'Admin' : _nameCtrl.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved.'), backgroundColor: _lime),
    );
  }

  void _snack(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? _lime : Colors.red.shade700,
      ),
    );
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Change password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Current password',
                    prefixIcon: Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'New password',
                    prefixIcon: Icon(Icons.lock_reset_rounded)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    prefixIcon: Icon(Icons.lock_reset_rounded)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: FilledButton.styleFrom(backgroundColor: _lime),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (go != true) return;
    if (newCtrl.text.trim() != confirmCtrl.text.trim()) {
      _snack('New passwords do not match.');
      return;
    }
    try {
      await AdminFirestoreDataSource()
          .changePassword(currentCtrl.text, newCtrl.text);
      _snack('Password updated.', ok: true);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7E8),
      appBar: AppBar(
        backgroundColor: _lime,
        foregroundColor: _ink,
        title: const Text('Admin Profile',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                AdminAvatar(name: _nameCtrl.text, radius: 52),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: _lime,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _saving ? null : _pickPhoto,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.camera_alt_rounded,
                            size: 18, color: _ink),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD7E3E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Display name',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14, color: _ink)),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveName,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _ink))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save'),
                  style: FilledButton.styleFrom(
                      backgroundColor: _lime,
                      minimumSize: const Size.fromHeight(48)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Security ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD7E3E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Security',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14, color: _ink)),
                const SizedBox(height: 6),
                Text('Change the admin login password.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _changePassword,
                  icon: const Icon(Icons.lock_reset_rounded, size: 18),
                  label: const Text('Change password'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: const BorderSide(color: _lime),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
