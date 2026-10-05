// Ilova ekranlarining skrinshotlarini haqiqiy shriftlar bilan chiqaradi.
//
//   flutter test tool/screenshots/screenshots_test.dart --update-goldens
//
// Natija: tool/screenshots/out/*.png (git'ga kiritilmaydi).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisobchi/app.dart';
import 'package:hisobchi/data/database.dart';
import 'package:hisobchi/data/repository.dart';
import 'package:hisobchi/domain/draft.dart';
import 'package:hisobchi/domain/enums.dart';
import 'package:hisobchi/features/transaction_form/transaction_sheet.dart';
import 'package:hisobchi/state/providers.dart';

import '../../test/helpers.dart';

Future<void> _loadFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold', 'Black']) {
    roboto.addFont(Future.value(ByteData.sublistView(File('$dir/Roboto-$w.ttf').readAsBytesSync())));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File('$dir/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

Future<void> _seed(Repository repo) async {
  final now = DateTime.now();
  DateTime ago(int days, [int hour = 12]) => DateTime(now.year, now.month, now.day - days, hour, 15);
  await repo.saveWallet(id: await repo.db.walletId('Naqd'), name: 'Naqd', icon: 'cash', initialBalance: 117200);
  await addTxn(repo, 'Maosh', 6500000, wallet: 'Karta', date: ago(4, 10));
  await addTxn(repo, 'Taksi', 18000, date: ago(0, 9));
  await addTxn(repo, 'Tushlik', 45000, wallet: 'Payme', date: ago(0, 13));
  await addTxn(repo, 'Oziq-ovqat', 236000, wallet: 'Karta', date: ago(1, 19));
  await addTxn(repo, 'Kommunal', 310000, wallet: 'Click', date: ago(2, 11));
  await addTxn(repo, 'Taksi', 24000, date: ago(2, 18));
  await addTxn(repo, 'Qarz berish', 500000, wallet: 'Karta', person: 'Sardor', date: ago(10), due: ago(-1));
  await addTxn(repo, 'Qarz olish', 1200000, wallet: 'Karta', person: 'Akmal aka', date: ago(20), due: ago(-12));
  await addTxn(repo, 'Qarz berish', 150000, person: 'Jasur', date: ago(15), due: ago(2));
  await repo.saveTransfer(
    fromWalletId: await repo.db.walletId('Karta'),
    toWalletId: await repo.db.walletId('Payme'),
    amount: 300000,
    date: ago(3),
  );
  for (var m = 1; m <= 5; m++) {
    await addTxn(repo, 'Maosh', 6000000 + m * 150000, wallet: 'Karta', date: DateTime(now.year, now.month - m, 5));
    await addTxn(repo, 'Oziq-ovqat', 1800000 + (m % 3) * 400000, wallet: 'Karta', date: DateTime(now.year, now.month - m, 12));
    await addTxn(repo, 'Taksi', 400000 + m * 50000, wallet: 'Karta', date: DateTime(now.year, now.month - m, 14));
  }
  await repo.setBudget(await repo.db.typeId('Taksi'), 50000);
  await repo.setBudget(await repo.db.typeId('Oziq-ovqat'), 2000000);
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUpAll(_loadFonts);

  Future<void> boot(WidgetTester tester, {bool dark = false}) async {
    // Testlarda soyalar standart holda o'chiq — haqiqiy ko'rinish uchun yoqamiz.
    // Test oxirida [_restoreShadows] bilan qaytariladi (tekshiruv tearDown'dan oldin ishlaydi).
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    db = memoryDb();
    addTearDown(db.close);
    await tester.runAsync(() async {
      final repo = Repository(db);
      await _seed(repo);
      if (dark) await repo.setSetting(SettingKeys.theme, 'dark');
    });
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const HisobchiApp()));
    for (var i = 0; i < 30 && container.read(ledgerProvider) == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
  }

  Future<void> shot(String name) =>
      expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }

  testWidgets('ekranlar', (tester) async {
    await boot(tester);
    await tester.pump(const Duration(milliseconds: 1100));
    await shot('01_splash');
    await settle(tester);
    await shot('02_bosh');

    for (final (i, name) in [(1, '05_tarix'), (2, '06_qarzlar'), (3, '07_statistika'), (4, '08_sozlamalar')]) {
      container.read(shellIndexProvider.notifier).go(i);
      await settle(tester);
      await shot(name);
    }

    container.read(shellIndexProvider.notifier).go(0);
    await settle(tester);
    final context = tester.element(find.byType(Scaffold).first);
    final ledger = container.read(ledgerProvider)!;
    showTransactionSheet(context, const TransactionDraft(direction: TxDirection.income));
    await settle(tester);
    await shot('03_kirim');
    Navigator.of(context).pop();
    await settle(tester);

    showTransactionSheet(
      context,
      TransactionDraft(
        direction: TxDirection.expense,
        typeId: ledger.types.firstWhere((t) => t.kind == TxKind.debtGive).id,
        walletId: ledger.wallets.firstWhere((w) => w.name == 'Karta').id,
        amount: 200000,
      ),
    );
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Ja');
    await settle(tester);
    await shot('04_chiqim_qarz');
    _restoreShadows();
  });

  testWidgets('tun rejimi', (tester) async {
    await boot(tester, dark: true);
    await settle(tester);
    await shot('09_bosh_tun');
    _restoreShadows();
  });
}

void _restoreShadows() => debugDisableShadows = true;
