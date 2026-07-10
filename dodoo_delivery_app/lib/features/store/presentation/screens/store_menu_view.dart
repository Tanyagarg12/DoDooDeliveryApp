import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import '../../../../core/cloudinary/cloudinary_service.dart';
import '../../../../core/constants/menu_suggestions.dart';
import '../../../../core/constants/store_categories.dart';
import '../../../../core/firebase/store_menu_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/fade_in.dart';
import '../../../../core/widgets/support_modal.dart';
import '../../../orders_api/data/dodoo_store_api.dart';
import '../../domain/entities/menu_item.dart';
import '../../domain/entities/store_entity.dart';

enum _MenuFilter { all, available, offer }

/// The store's Menu tab — manage items with photos, descriptions, offers,
/// veg/non-veg tags, recommended flags and category sections. Includes filter
/// chips, a section quick-nav bar, and store-type suggestions.
class StoreMenuView extends StatefulWidget {
  const StoreMenuView({super.key, required this.store});
  final StoreEntity store;

  @override
  State<StoreMenuView> createState() => _StoreMenuViewState();
}

class _StoreMenuViewState extends State<StoreMenuView> {
  final _svc = StoreMenuService.instance;
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  _MenuFilter _filter = _MenuFilter.all;

  String get _storeId => widget.store.id;

  GlobalKey _keyFor(String section) =>
      _sectionKeys.putIfAbsent(section, () => GlobalKey());

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(String section) {
    final ctx = _sectionKeys[section]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    }
  }

  List<MenuItem> _applyFilter(List<MenuItem> items) {
    switch (_filter) {
      case _MenuFilter.available:
        return items.where((i) => i.available).toList();
      case _MenuFilter.offer:
        return items.where((i) => i.hasDiscount).toList();
      case _MenuFilter.all:
        return items;
    }
  }

  List<String> _sectionsOf(List<MenuItem> items) {
    final set = <String>{};
    for (final it in items) {
      if (it.category != null && it.category!.trim().isNotEmpty) {
        set.add(it.category!.trim());
      }
    }
    return set.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(null, const []),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Add item',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: StreamBuilder<List<MenuItem>>(
                stream: _svc.streamMenu(_storeId),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snap.data!;
                  return items.isEmpty
                      ? _emptyWithSuggestions()
                      : _content(items);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Menu',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('Manage your items, photos & offers',
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const SupportIconButton(),
        ],
      ),
    );
  }

  // ── Populated content ───────────────────────────────────────────────────────

  Widget _content(List<MenuItem> items) {
    final total = items.length;
    final available = items.where((i) => i.available).length;
    final offers = items.where((i) => i.hasDiscount).length;
    final allSections = _sectionsOf(items);

    final shown = _applyFilter(items);

    // Group by section; recommended first, then by name.
    final grouped = <String, List<MenuItem>>{};
    for (final it in shown) {
      grouped.putIfAbsent(it.section, () => []).add(it);
    }
    for (final list in grouped.values) {
      list.sort((a, b) {
        if (a.isRecommended != b.isRecommended) {
          return a.isRecommended ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }
    final sectionNames = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'Other') return 1;
        if (b == 'Other') return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    final flat = sectionNames.length == 1 && sectionNames.first == 'Other';
    final showNav = sectionNames.length >= 2;

    var animIndex = 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _statsFilterRow(total, available, offers),
        ),
        if (showNav) _sectionNavBar(sectionNames),
        Expanded(
          child: shown.isEmpty
              ? _emptyFiltered()
              : ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  children: [
                    _suggestionStrip(items, allSections),
                    for (final sec in sectionNames) ...[
                      if (!flat)
                        _sectionLabel(sec, grouped[sec]!.length,
                            key: _keyFor(sec)),
                      for (final it in grouped[sec]!)
                        FadeIn(
                          index: (animIndex++).clamp(0, 8),
                          child: _tile(it, allSections),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  // ── Filter chips (Items / Available / On offer) ─────────────────────────────

  Widget _statsFilterRow(int total, int available, int offers) {
    return Row(
      children: [
        _filterCard(Icons.restaurant_menu_rounded, AppColors.primary, 'Items',
            total, _MenuFilter.all),
        const SizedBox(width: 10),
        _filterCard(Icons.check_circle_rounded, const Color(0xFF059669),
            'Available', available, _MenuFilter.available),
        const SizedBox(width: 10),
        _filterCard(Icons.local_offer_rounded, const Color(0xFFDC2626),
            'On offer', offers, _MenuFilter.offer),
      ],
    );
  }

  Widget _filterCard(
      IconData icon, Color color, String label, int value, _MenuFilter mode) {
    final selected = _filter == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          // Tapping the active non-default filter clears back to "all".
          _filter = (selected && mode != _MenuFilter.all)
              ? _MenuFilter.all
              : mode;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.16 : 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: selected ? 0.9 : 0.2),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 6),
              Text('$value',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: color)),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section quick-nav bar ────────────────────────────────────────────────────

  Widget _sectionNavBar(List<String> sections) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 2),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sec = sections[i];
          return ActionChip(
            label: Text(sec,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700)),
            onPressed: () => _scrollToSection(sec),
            backgroundColor: Colors.white,
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
            labelStyle: const TextStyle(color: AppColors.accent),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String name, int count, {Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Row(
          children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent)),
            ),
          ],
        ),
      );

  // ── Store-type suggestions (quick add) ──────────────────────────────────────

  Widget _suggestionStrip(List<MenuItem> items, List<String> sections) {
    final existing = items.map((i) => i.name.toLowerCase()).toSet();
    final suggestions = MenuSuggestions.forCategory(widget.store.category)
        .where((s) => !existing.contains(s.name.toLowerCase()))
        .toList();
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final catLabel = StoreCategories.byKey(widget.store.category).label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Suggested for your $catLabel',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              Text('Tap to add',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _SuggestionChip(
              suggestion: suggestions[i],
              onTap: () => _quickAdd(suggestions[i], sections),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Add a suggestion as a recommended item (auto-description + photo nudge) ──

  Future<void> _quickAdd(MenuSuggestion s, List<String> sections) async {
    final desc = _autoDescription(s.name, s.category, s.isVeg);
    try {
      final id = await _svc.addItem(
        _storeId,
        name: s.name,
        price: s.price,
        isVeg: s.isVeg,
        category: s.category,
        description: desc,
        isRecommended: true,
      );
      // Push to DoDoo (best-effort) if the store is linked.
      await _pushItemToDodoo(
        storeId: _storeId,
        dodooStoreId: widget.store.dodooStoreId,
        firestoreItemId: id,
        isVeg: s.isVeg,
        category: s.category,
        itemName: s.name,
        price: s.price,
        description: desc,
      );
      if (!mounted) return;
      final added = MenuItem(
        id: id,
        name: s.name,
        price: s.price,
        isVeg: s.isVeg,
        category: s.category,
        description: desc,
        isRecommended: true,
      );
      _nudgeAddPhoto(added, sections,
          message: '“${s.name}” added as recommended');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not add item. Check your connection.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// Turning "recommended" on auto-fills a description if missing, then nudges
  /// the store to add a photo. Turning it off just clears the flag.
  Future<void> _toggleRecommend(MenuItem it, List<String> sections) async {
    final turningOn = !it.isRecommended;
    MenuItem updated = it;
    try {
      if (turningOn && it.description == null) {
        final desc = _autoDescription(it.name, it.category, it.isVeg);
        await _svc.updateItem(
          _storeId,
          it.id,
          name: it.name,
          price: it.price,
          photoUrl: it.photoUrl,
          description: desc,
          discountPercent: it.discountPercent,
          isVeg: it.isVeg,
          isRecommended: true,
          category: it.category,
        );
        updated = MenuItem(
          id: it.id,
          name: it.name,
          price: it.price,
          available: it.available,
          photoUrl: it.photoUrl,
          description: desc,
          discountPercent: it.discountPercent,
          isVeg: it.isVeg,
          isRecommended: true,
          category: it.category,
        );
      } else {
        await _svc.setRecommended(_storeId, it.id, turningOn);
      }
      if (turningOn && it.photoUrl == null && mounted) {
        _nudgeAddPhoto(updated, sections,
            message: '“${it.name}” is now recommended');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not update item.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _nudgeAddPhoto(MenuItem item, List<String> sections,
      {required String message}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$message — add a photo so customers notice it'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Add photo',
            onPressed: () => _openEditor(item, sections),
          ),
        ),
      );
  }

  // ── Item tile ───────────────────────────────────────────────────────────────

  Widget _tile(MenuItem it, List<String> sections) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: it.isRecommended
              ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
              : const Color(0xFFEDEFE0),
          width: it.isRecommended ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: it.available ? 1 : 0.6,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumb(it),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (it.isVeg != null) ...[
                          _VegMark(veg: it.isVeg!),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(it.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                        if (it.isRecommended) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded,
                              size: 16, color: Color(0xFFF59E0B)),
                        ],
                      ],
                    ),
                    if (it.description != null) ...[
                      const SizedBox(height: 3),
                      Text(it.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              height: 1.25)),
                    ],
                    const SizedBox(height: 6),
                    _priceRow(it),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: it.available,
                      onChanged: (v) => _svc.setAvailable(_storeId, it.id, v),
                      activeThumbColor: Colors.white,
                      activeTrackColor: const Color(0xFF059669),
                    ),
                  ),
                  _tileMenu(it, sections),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumb(MenuItem it) {
    final initial =
        it.name.trim().isNotEmpty ? it.name.trim()[0].toUpperCase() : '?';
    if (it.photoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          it.photoUrl!,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _avatarFallback(initial, it.available),
          loadingBuilder: (c, child, progress) => progress == null
              ? child
              : _avatarFallback(initial, it.available),
        ),
      );
    }
    return _avatarFallback(initial, it.available);
  }

  Widget _avatarFallback(String initial, bool available) => Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: available
              ? AppGradients.primary
              : LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade500]),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(initial,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
      );

  Widget _priceRow(MenuItem it) {
    if (!it.hasDiscount) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('₹${it.price.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.accent,
                fontWeight: FontWeight.w800)),
      );
    }
    return Row(
      children: [
        Text('₹${it.price.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.lineThrough)),
        const SizedBox(width: 6),
        Text('₹${it.finalPrice.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF059669),
                fontWeight: FontWeight.w900)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text('${it.discountPercent.toStringAsFixed(0)}% OFF',
              style: const TextStyle(
                  fontSize: 9.5,
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _tileMenu(MenuItem it, List<String> sections) {
    return PopupMenuButton<String>(
      tooltip: 'Options',
      padding: EdgeInsets.zero,
      icon:
          Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey.shade600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        switch (v) {
          case 'edit':
            _openEditor(it, sections);
          case 'recommend':
            _toggleRecommend(it, sections);
          case 'delete':
            _confirmDelete(it);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_rounded, size: 18, color: AppColors.accent),
            SizedBox(width: 10),
            Text('Edit'),
          ]),
        ),
        PopupMenuItem(
          value: 'recommend',
          child: Row(children: [
            Icon(
                it.isRecommended
                    ? Icons.star_border_rounded
                    : Icons.star_rounded,
                size: 18,
                color: const Color(0xFFF59E0B)),
            const SizedBox(width: 10),
            Text(it.isRecommended ? 'Unrecommend' : 'Recommend'),
          ]),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.error),
            SizedBox(width: 10),
            Text('Delete', style: TextStyle(color: AppColors.error)),
          ]),
        ),
      ],
    );
  }

  // ── Empty states ──────────────────────────────────────────────────────────

  Widget _emptyFiltered() {
    final label = _filter == _MenuFilter.available ? 'available' : 'on offer';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt_off_rounded,
              size: 46, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No items $label',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => setState(() => _filter = _MenuFilter.all),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Clear filter'),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _emptyWithSuggestions() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryContainer,
                      AppColors.primaryContainer.withValues(alpha: 0.4),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restaurant_menu_rounded,
                    size: 46, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text('Your menu is empty',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                    'Add your items with photos, prices & offers — or tap a suggestion below to start fast.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey.shade600,
                        height: 1.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _suggestionStrip(const [], const []),
      ],
    );
  }

  // ── Add / edit ──────────────────────────────────────────────────────────────

  Future<void> _openEditor(MenuItem? existing, List<String> sections) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MenuItemEditor(
        storeId: _storeId,
        dodooStoreId: widget.store.dodooStoreId,
        existing: existing,
        sections: sections,
      ),
    );
  }

  Future<void> _confirmDelete(MenuItem it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove "${it.name}" from your menu?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await _svc.deleteItem(_storeId, it.id);
  }
}

/// Pushes a menu item to the DoDoo platform (SaveStoreItem) and records the
/// returned DoDoo item id locally so future edits update it instead of
/// inserting a duplicate. Best-effort: returns an error message on failure,
/// or null on success / when the store isn't linked to DoDoo yet.
Future<String?> _pushItemToDodoo({
  required String storeId,
  required String? dodooStoreId,
  required String firestoreItemId,
  String? existingDodooItemId,
  required bool? isVeg,
  String? category,
  required String itemName,
  required double price,
  String? photoUrl,
  bool available = true,
  String description = '',
  double discountPercent = 0,
}) async {
  final linked = (dodooStoreId ?? '').trim();
  if (linked.isEmpty) return null; // store not linked to DoDoo → skip silently
  try {
    final res = await DodooStoreApi().saveStoreItem(
      id: (existingDodooItemId ?? '').isNotEmpty ? existingDodooItemId! : '0',
      storeId: linked,
      dishType: isVeg == false ? 'Non-veg' : 'Veg',
      category: category ?? '',
      itemName: itemName,
      unitPrice: price.toStringAsFixed(0),
      imagePath: photoUrl ?? '',
      isActive: available,
      description: description,
      discountAmount: discountPercent.toStringAsFixed(0),
      discountType: 'Percentage',
    );
    if (res.ok) {
      final newId = res.id;
      if (newId != null && newId.isNotEmpty && newId != '0') {
        await StoreMenuService.instance
            .setDodooItemId(storeId, firestoreItemId, newId);
      }
      return null;
    }
    return res.message ?? 'DoDoo sync failed';
  } catch (_) {
    return 'DoDoo sync failed';
  }
}

/// Builds a friendly default description for a quick-added / recommended item.
String _autoDescription(String name, String? category, bool? isVeg) {
  final b = StringBuffer();
  if (isVeg == true) {
    b.write('Freshly prepared veg ');
  } else if (isVeg == false) {
    b.write('Freshly prepared ');
  } else {
    b.write('Our ');
  }
  b.write(name.toLowerCase());
  if (category != null && category.trim().isNotEmpty) {
    b.write(' from the ${category.trim()} section');
  }
  b.write(' — a customer favourite.');
  final s = b.toString();
  return s[0].toUpperCase() + s.substring(1);
}

// ── Veg / non-veg mark ──────────────────────────────────────────────────────

class _VegMark extends StatelessWidget {
  const _VegMark({required this.veg});
  final bool veg;

  @override
  Widget build(BuildContext context) {
    final color = veg ? const Color(0xFF059669) : const Color(0xFFDC2626);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

// ── Suggestion chip ─────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.suggestion, required this.onTap});
  final MenuSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(suggestion.name,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text('₹${suggestion.price.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add / edit editor sheet ─────────────────────────────────────────────────

class _MenuItemEditor extends StatefulWidget {
  const _MenuItemEditor({
    required this.storeId,
    required this.dodooStoreId,
    required this.existing,
    required this.sections,
  });
  final String storeId;
  final String? dodooStoreId;
  final MenuItem? existing;
  final List<String> sections;

  @override
  State<_MenuItemEditor> createState() => _MenuItemEditorState();
}

class _MenuItemEditorState extends State<_MenuItemEditor> {
  final _svc = StoreMenuService.instance;
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _descCtrl =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _priceCtrl = TextEditingController(
      text: widget.existing == null
          ? ''
          : widget.existing!.price.toStringAsFixed(0));
  late final _discountCtrl = TextEditingController(
      text: (widget.existing?.discountPercent ?? 0) > 0
          ? widget.existing!.discountPercent.toStringAsFixed(0)
          : '');
  late final _categoryCtrl =
      TextEditingController(text: widget.existing?.category ?? '');

  File? _photo;
  late final String? _existingPhotoUrl = widget.existing?.photoUrl;
  bool _removePhoto = false;
  late bool? _isVeg = widget.existing?.isVeg;
  late bool _recommended = widget.existing?.isRecommended ?? false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImageUtils.pickImage(source);
    if (file != null && mounted) {
      setState(() {
        _photo = file;
        _removePhoto = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      String? photoUrl = _removePhoto ? null : _existingPhotoUrl;
      if (_photo != null) {
        photoUrl = await CloudinaryService.instance
            .uploadFile(_photo!.path, folder: 'store_menu/${widget.storeId}');
      }
      final name = _nameCtrl.text.trim();
      final price = double.parse(_priceCtrl.text.trim());
      final discount = (double.tryParse(_discountCtrl.text.trim()) ?? 0)
          .clamp(0, 100)
          .toDouble();
      final desc = _descCtrl.text.trim();
      final cat = _categoryCtrl.text.trim();

      String itemId;
      if (widget.existing == null) {
        itemId = await _svc.addItem(
          widget.storeId,
          name: name,
          price: price,
          photoUrl: photoUrl,
          description: desc.isEmpty ? null : desc,
          discountPercent: discount,
          isVeg: _isVeg,
          isRecommended: _recommended,
          category: cat.isEmpty ? null : cat,
        );
      } else {
        itemId = widget.existing!.id;
        await _svc.updateItem(
          widget.storeId,
          widget.existing!.id,
          name: name,
          price: price,
          photoUrl: photoUrl,
          description: desc.isEmpty ? null : desc,
          discountPercent: discount,
          isVeg: _isVeg,
          isRecommended: _recommended,
          category: cat.isEmpty ? null : cat,
        );
      }

      // Push to DoDoo (best-effort; local save already succeeded).
      final dodooErr = await _pushItemToDodoo(
        storeId: widget.storeId,
        dodooStoreId: widget.dodooStoreId,
        firestoreItemId: itemId,
        existingDodooItemId: widget.existing?.dodooItemId,
        isVeg: _isVeg,
        category: cat.isEmpty ? null : cat,
        itemName: name,
        price: price,
        photoUrl: photoUrl,
        available: widget.existing?.available ?? true,
        description: desc,
        discountPercent: discount,
      );

      if (!mounted) return;
      navigator.pop();
      if (dodooErr != null) {
        messenger.showSnackBar(SnackBar(
          content: Text('Saved. DoDoo sync failed: $dodooErr'),
          backgroundColor: Colors.orange.shade800,
        ));
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not save item. Check your connection.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(editing ? 'Edit item' : 'Add menu item',
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Center(child: _photoPicker()),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Item name',
                    prefixIcon: Icon(Icons.label_outline_rounded)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                maxLength: 140,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g. Freshly made, serves 2',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                          labelText: 'Price (₹)', prefixText: '₹ '),
                      validator: (v) {
                        final p = double.tryParse(v?.trim() ?? '');
                        if (p == null || p <= 0) return 'Enter a valid price';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _discountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                          labelText: 'Offer', suffixText: '% off'),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return null;
                        final d = int.tryParse(t);
                        if (d == null || d < 0 || d > 100) return '0–100';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Food type',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _vegChoice('Veg', true, const Color(0xFF059669)),
                  const SizedBox(width: 8),
                  _vegChoice('Non-veg', false, const Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  _vegChoice('N/A', null, Colors.grey.shade600),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Section (optional)',
                  hintText: 'e.g. Starters, Beverages',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              if (widget.sections.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: widget.sections
                      .map((s) => ActionChip(
                            label:
                                Text(s, style: const TextStyle(fontSize: 12)),
                            onPressed: () => _categoryCtrl.text = s,
                            backgroundColor: AppColors.primaryContainer,
                            side: BorderSide.none,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  value: _recommended,
                  onChanged: (v) => setState(() => _recommended = v),
                  activeThumbColor: const Color(0xFFF59E0B),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: const Text('Mark as recommended',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Highlight this as a top pick',
                      style: TextStyle(fontSize: 11.5)),
                  secondary:
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(editing ? 'Save changes' : 'Add item',
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPicker() {
    final hasPhoto =
        _photo != null || (_existingPhotoUrl != null && !_removePhoto);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
              image: _photo != null
                  ? DecorationImage(
                      image: FileImage(_photo!), fit: BoxFit.cover)
                  : (_existingPhotoUrl != null && !_removePhoto)
                      ? DecorationImage(
                          image: NetworkImage(_existingPhotoUrl),
                          fit: BoxFit.cover)
                      : null,
            ),
            child: hasPhoto
                ? null
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo_rounded,
                          color: AppColors.primary, size: 28),
                      const SizedBox(height: 6),
                      Text('Add photo',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ],
                  ),
          ),
        ),
        if (hasPhoto)
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: () => setState(() {
                _photo = null;
                _removePhoto = true;
              }),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: AppColors.error, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _vegChoice(String label, bool? value, Color color) {
    final selected = _isVeg == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isVeg = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : const Color(0xFFDDE3E0),
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : Colors.grey.shade600)),
        ),
      ),
    );
  }
}
