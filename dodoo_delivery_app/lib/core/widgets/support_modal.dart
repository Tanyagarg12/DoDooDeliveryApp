import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/support_config.dart';
import '../theme/app_theme.dart';

/// Opens the Contact Support sheet. Call from anywhere:
///   showSupportSheet(context);
Future<void> showSupportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SupportSheet(),
  );
}

/// A reusable help icon button that opens the support sheet. Drop into any
/// AppBar `actions:` list.
class SupportIconButton extends StatelessWidget {
  const SupportIconButton({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Help & Support',
      icon: const Icon(Icons.support_agent_rounded),
      color: color,
      onPressed: () => showSupportSheet(context),
    );
  }
}

class _SupportSheet extends StatelessWidget {
  const _SupportSheet();

  Future<void> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _digits(String phone) => phone.replaceAll(RegExp(r'[^\d]'), '');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent_rounded, color: cs.primary),
                const SizedBox(width: 10),
                const Text('Help & Support',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 4),
            Text('We\'re here to help. Reach us any way you like.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),

            _SupportTile(
              icon: Icons.phone_rounded,
              color: AppColors.online,
              title: 'Call Support',
              subtitle: SupportConfig.supportPhone,
              onTap: () => _launch(Uri.parse('tel:${SupportConfig.supportPhone}')),
            ),
            _SupportTile(
              icon: Icons.chat_rounded,
              color: const Color(0xFF25D366),
              title: 'WhatsApp',
              subtitle: SupportConfig.whatsappNumber,
              onTap: () => _launch(
                  Uri.parse('https://wa.me/${_digits(SupportConfig.whatsappNumber)}')),
            ),
            _SupportTile(
              icon: Icons.email_rounded,
              color: cs.primary,
              title: 'Email',
              subtitle: SupportConfig.supportEmail,
              onTap: () => _launch(Uri(
                scheme: 'mailto',
                path: SupportConfig.supportEmail,
                query: 'subject=DoDoo Rider Support',
              )),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const ReportIssueSheet(),
                  );
                },
                icon: const Icon(Icons.report_problem_rounded, size: 18),
                label: const Text('Report an Issue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12.5, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple "Report an Issue" form. Stores the ticket in Supabase
/// `support_tickets` and falls back to opening the user's email client.
class ReportIssueSheet extends StatefulWidget {
  const ReportIssueSheet({super.key});

  @override
  State<ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<ReportIssueSheet> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields.')),
      );
      return;
    }
    setState(() => _submitting = true);
    var stored = false;
    try {
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'rider_id': FirebaseAuth.instance.currentUser?.uid,
        'subject': subject,
        'message': message,
        'status': 'open',
        'created_at': FieldValue.serverTimestamp(),
      });
      stored = true;
    } catch (_) {
      // On any failure — fall back to email so nothing is lost.
    }

    if (!stored) {
      final uri = Uri(
        scheme: 'mailto',
        path: SupportConfig.supportEmail,
        query: 'subject=${Uri.encodeComponent(subject)}'
            '&body=${Uri.encodeComponent(message)}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(stored
            ? 'Thanks — your issue has been submitted.'
            : 'Opening your email app to send the report…'),
        backgroundColor: AppColors.online,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Report an Issue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(
              labelText: 'Subject',
              prefixIcon: Icon(Icons.title_rounded),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Describe the issue',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onPrimary))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_submitting ? 'Submitting…' : 'Submit'),
            ),
          ),
        ],
      ),
    );
  }
}
