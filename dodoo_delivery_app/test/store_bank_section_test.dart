import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dodoo_delivery_app/core/theme/app_theme.dart';
import 'package:dodoo_delivery_app/features/store/domain/entities/store_wallet_entity.dart';

// Replicates the exact widget trees used by store_settings_screen.dart's bank
// section, rendered inside a ListView (unbounded height) — the same context
// the real screen uses — so any "RenderBox was not laid out" surfaces here.

Widget _bankEmpty() => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8F0EE)),
      ),
      child: Column(
        children: [
          Icon(Icons.account_balance_rounded, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text('No bank accounts yet',
              style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 4),
          Text('Add one to receive payouts to your bank.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add bank account'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );

Widget _accountTile(StoreBankAccount acc) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: acc.isDefault ? AppColors.primary : const Color(0xFFE8F0EE),
        width: acc.isDefault ? 1.5 : 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_rounded,
                  size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(acc.holderName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    '${acc.accountNumber.substring(acc.accountNumber.length - 4).padLeft(acc.accountNumber.length, '*')} • ${acc.ifscCode}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (acc.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Default',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side:
                        BorderSide(color: AppColors.error.withValues(alpha: 0.5))),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _wrap(List<Widget> children) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: children,
        ),
      ),
    );

void main() {
  const acc = StoreBankAccount(
    id: '1',
    holderName: 'Ravi Kumar',
    accountNumber: '50100234567890',
    ifscCode: 'HDFC0001234',
    isDefault: true,
  );

  testWidgets('bank loader renders without layout error', (tester) async {
    await tester.pumpWidget(_wrap(const [
      Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
    ]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('bank empty card renders without layout error', (tester) async {
    await tester.pumpWidget(_wrap([_bankEmpty()]));
    expect(tester.takeException(), isNull);
    expect(find.text('Add bank account'), findsOneWidget);
  });

  testWidgets('account tile as DIRECT ListView child', (tester) async {
    await tester.pumpWidget(_wrap([_accountTile(acc)]));
    expect(tester.takeException(), isNull);
    expect(find.text('Ravi Kumar'), findsOneWidget);
  });

  testWidgets('account tile inside STRETCH column', (tester) async {
    await tester.pumpWidget(_wrap([
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_accountTile(acc)],
      ),
    ]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('account tile inside PLAIN column', (tester) async {
    await tester.pumpWidget(_wrap([
      Column(children: [_accountTile(acc)]),
    ]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('add-account dialog (form + checkbox row) renders w/o error',
      (tester) async {
    final formKey = GlobalKey<FormState>();
    bool isDefault = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Add bank account'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const TextField(
                                decoration: InputDecoration(
                                    labelText: 'Account holder name')),
                            const SizedBox(height: 12),
                            const TextField(
                                decoration: InputDecoration(
                                    labelText: 'Account number')),
                            const SizedBox(height: 12),
                            const TextField(
                                decoration:
                                    InputDecoration(labelText: 'IFSC code')),
                            const SizedBox(height: 12),
                            StatefulBuilder(
                              builder: (bCtx, setBState) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                      value: isDefault,
                                      onChanged: (v) => setBState(
                                          () => isDefault = v ?? false)),
                                  const Text('Set as default',
                                      style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Set as default'), findsOneWidget);
  });
}
