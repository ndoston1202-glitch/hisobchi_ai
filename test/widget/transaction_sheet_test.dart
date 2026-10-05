import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisobchi/core/theme.dart';
import 'package:hisobchi/data/database.dart';
import 'package:hisobchi/domain/draft.dart';
import 'package:hisobchi/domain/enums.dart';
import 'package:hisobchi/features/transaction_form/transaction_sheet.dart';
import 'package:hisobchi/state/providers.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  Future<void> openSheet(WidgetTester tester, TransactionDraft Function() draft) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: ref.watch(ledgerProvider) == null
                  ? const SizedBox()
                  : Center(
                      child: ElevatedButton(
                        onPressed: () => showTransactionSheet(context, draft()),
                        child: const Text('ochish'),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20 && find.text('ochish').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.tap(find.text('ochish'));
    await tester.pumpAndSettle();
  }

  testWidgets('qarz turida "Kim?" maydoni chiqadi va odamsiz saqlanmaydi', (tester) async {
    final qarzBerish = await tester.runAsync(() => db.typeId('Qarz berish'));
    await openSheet(tester, () => TransactionDraft(direction: TxDirection.expense, typeId: qarzBerish));

    expect(find.text('Chiqim'), findsOneWidget);
    expect(find.text('Kimga qarz berdingiz?'), findsOneWidget);
    expect(find.text('Qaytarish sanasi (eslatma keladi)'), findsOneWidget);

    // Summa bo'sh — Saqlash faol emas
    FilledButton saveButton() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Saqlash'));
    expect(saveButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(1), '150000');
    await tester.pumpAndSettle();
    expect(find.text('150 000'), findsOneWidget, reason: 'summa formatlanadi');
    expect(saveButton().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pump();
    expect(find.text('Kimligini kiriting'), findsOneWidget);
    expect(await tester.runAsync(() => db.select(db.transactions).get()), isEmpty);
  });

  testWidgets('oddiy turda "Kim?" yo\'q va chiqim saqlanadi', (tester) async {
    await openSheet(tester, () => const TransactionDraft(direction: TxDirection.expense));

    expect(find.text('Taksi'), findsOneWidget, reason: 'birinchi chiqim turi tanlangan');
    expect(find.textContaining('Kim'), findsNothing);
    expect(find.text('Naqd'), findsOneWidget);
    expect(find.text('Payme'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '25000');
    await tester.pump();
    expect(find.textContaining('yetarli mablag\''), findsOneWidget, reason: 'naqd balans 0 — ogohlantirish');

    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(() => db.select(db.transactions).get());
    expect(saved!.single.amount, 25000);
    expect(saved.single.typeId, await tester.runAsync(() => db.typeId('Taksi')));
  });
}
