import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/utils/image_utils.dart';

class DocumentUploadTile extends StatefulWidget {
  const DocumentUploadTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onFilePicked,
    this.isRequired = false,
  });

  final String label;
  final IconData icon;
  final void Function(File file) onFilePicked;
  final bool isRequired;

  @override
  State<DocumentUploadTile> createState() => _DocumentUploadTileState();
}

class _DocumentUploadTileState extends State<DocumentUploadTile> {
  File? _file;

  Future<void> _pick(ImageSource source) async {
    final file = await ImageUtils.pickImage(source);
    if (file == null) return;
    setState(() => _file = file);
    widget.onFilePicked(file);
  }

  void _showSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0F766E);
    final hasFile = _file != null;

    return GestureDetector(
      onTap: _showSourceDialog,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: hasFile ? teal.withOpacity(0.06) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasFile ? teal : Colors.grey.shade300,
            width: hasFile ? 1.5 : 1,
            style: hasFile ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
        child: hasFile
            ? _PreviewTile(file: _file!, label: widget.label, onRetap: _showSourceDialog)
            : _UploadPlaceholder(
                label: widget.label,
                icon: widget.icon,
                isRequired: widget.isRequired,
              ),
      ),
    );
  }
}

class _UploadPlaceholder extends StatelessWidget {
  const _UploadPlaceholder({
    required this.label,
    required this.icon,
    required this.isRequired,
  });

  final String label;
  final IconData icon;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(icon, size: 32, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Tap to upload',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    if (isRequired) ...[
                      const SizedBox(width: 4),
                      const Text('*', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.upload_outlined, color: Color(0xFF0F766E)),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.file,
    required this.label,
    required this.onRetap,
  });

  final File file;
  final String label;
  final VoidCallback onRetap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF0F766E),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 14, color: Color(0xFF0F766E)),
                  const SizedBox(width: 4),
                  Text(
                    'Uploaded',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onRetap,
          child: const Text('Change', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
