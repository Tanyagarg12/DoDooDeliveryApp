import 'package:flutter/material.dart';

import '../constants/dodoo_cities.dart';

/// A pill-styled dropdown for picking the active delivery city.
///
/// Used at the top of the admin orders tab (pick exactly one city) and the
/// rider orders tab (with an "All cities" option). [value] is the selected
/// city code, or `null` for "All cities" when [includeAll] is true.
class CitySelector extends StatelessWidget {
  const CitySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.includeAll = false,
    this.label = 'Delivering at',
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool includeAll;
  final String label;

  static const _brand = Color(0xFFBABC2F);
  static const _ink = Color(0xFF1C1D00);
  static const _bg = Color(0xFFF2F5A0);

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String?>>[
      if (includeAll)
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All cities'),
        ),
      ...DodooCities.all.map(
        (c) => DropdownMenuItem<String?>(value: c.code, child: Text(c.name)),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _brand.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF6B6E00)),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B6E00),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: value,
                isExpanded: true,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _ink),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
