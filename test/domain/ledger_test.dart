import 'package:flutter_test/flutter_test.dart';
import 'package:hisobchi/data/database.dart';
import 'package:hisobchi/data/repository.dart';
import 'package:hisobchi/domain/enums.dart';
import 'package:hisobchi/domain/ledger.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = memoryDb();
    repo = Repository(db);
  });
  tearDown(() => db.close());

  group('balans', () {
    test('boshlang\'ich + kirim − chiqim ± o\'tkazma', () async {
      final naqd = await db.walletId('Naqd');
      final karta = await db.walletId('Karta');
      await repo.saveWallet(id: naqd, name: 'Naqd', icon: 'cash', initialBalance: 100000);

      await addTxn(repo, 'Maosh', 500000, wallet: 'Karta');
      await addTxn(repo, 'Taksi', 20000);
      await repo.saveTransfer(
        fromWalletId: karta,
        toWalletId: naqd,
        amount: 150000,
        date: DateTime(2026, 10, 5),
      );

      final ledger = await loadLedger(db);
      final balances = ledger.walletBalances();
      expect(balances[naqd], 100000 - 20000 + 150000);
      expect(balances[karta], 500000 - 150000);
      expect(ledger.totalBalance(), 100000 + 500000 - 20000);
    });

    test('arxivlangan hamyon umumiy balansga kirmaydi', () async {
      await addTxn(repo, 'Maosh', 300000, wallet: 'Click');
      await addTxn(repo, 'Maosh', 100000, wallet: 'Naqd');
      expect(await repo.removeWallet(await db.walletId('Click')), Removal.archived);

      final ledger = await loadLedger(db);
      expect(ledger.totalBalance(), 100000);
    });
  });

  group('statistika', () {
    test('qarz va o\'tkazmalar daromad/xarajatga kirmaydi', () async {
      await addTxn(repo, 'Maosh', 1000000);
      await addTxn(repo, 'Tushlik', 45000);
      await addTxn(repo, 'Qarz olish', 200000, person: 'Ali');
      await addTxn(repo, 'Qarz berish', 50000, person: 'Vali');
      await repo.saveTransfer(
        fromWalletId: await db.walletId('Naqd'),
        toWalletId: await db.walletId('Karta'),
        amount: 10000,
        date: DateTime(2026, 10, 5),
      );

      final totals = (await loadLedger(db)).monthTotals(DateTime(2026, 10));
      expect(totals.income, 1000000);
      expect(totals.expense, 45000);
    });

    test('boshqa oy hisoblanmaydi, 6 oylik qator eng eskisidan', () async {
      await addTxn(repo, 'Taksi', 15000, date: DateTime(2026, 9, 30));
      await addTxn(repo, 'Taksi', 25000, date: DateTime(2026, 10, 1));

      final ledger = await loadLedger(db);
      expect(ledger.monthTotals(DateTime(2026, 10)).expense, 25000);
      final months = ledger.lastMonths(DateTime(2026, 10));
      expect(months, hasLength(6));
      expect(months.first.month, DateTime(2026, 5));
      expect(months.last.month, DateTime(2026, 10));
      expect(months[4].expense, 15000);
    });

    test('expenseByType kamayish tartibida', () async {
      await addTxn(repo, 'Taksi', 15000);
      await addTxn(repo, 'Tushlik', 40000);
      await addTxn(repo, 'Taksi', 10000);

      final byType = (await loadLedger(db)).expenseByType(DateTime(2026, 10));
      expect([for (final (t, sum) in byType) '${t.name}:$sum'], ['Tushlik:40000', 'Taksi:25000']);
    });
  });

  group('qarz', () {
    test('qisman qaytarish FIFO bo\'yicha eng eski qarzni yopadi', () async {
      await addTxn(repo, 'Qarz berish', 100000, person: 'Ali', date: DateTime(2026, 9, 1), due: DateTime(2026, 9, 10));
      await addTxn(repo, 'Qarz berish', 50000, person: 'ali ', date: DateTime(2026, 9, 5), due: DateTime(2026, 10, 10));
      await addTxn(repo, 'Qarzni qaytarib olish', 120000, person: 'Ali', date: DateTime(2026, 9, 20));

      final ledger = await loadLedger(db);
      expect(ledger.people, hasLength(1), reason: 'ism katta-kichik harfdan qat\'i nazar bitta odam');
      final debt = ledger.personDebts().single;
      expect(debt.owedToMe, 30000);
      expect(debt.iOwe, 0);
      expect(debt.open, hasLength(1));
      expect(debt.open.single.remaining, 30000);
      expect(debt.open.single.dueDate, DateTime(2026, 10, 10));
      expect(debt.nearestDue(owedToMe: true), DateTime(2026, 10, 10));
    });

    test('menga qarzdor va men qarzdorman alohida', () async {
      await addTxn(repo, 'Qarz berish', 70000, person: 'Sardor');
      await addTxn(repo, 'Qarz olish', 300000, person: 'Sardor');
      await addTxn(repo, 'Qarzni qaytarish', 100000, person: 'Sardor');

      final debt = (await loadLedger(db)).personDebts().single;
      expect(debt.owedToMe, 70000);
      expect(debt.iOwe, 200000);
      expect(debt.open.map((d) => (d.kind, d.remaining)), [
        (TxKind.debtGive, 70000),
        (TxKind.debtTake, 200000),
      ]);
    });

    test('to\'liq qaytarilgan qarz ochiq emas', () async {
      await addTxn(repo, 'Qarz olish', 50000, person: 'Aziz');
      await addTxn(repo, 'Qarzni qaytarish', 50000, person: 'Aziz');
      expect((await loadLedger(db)).openDebts(), isEmpty);
    });

    test('muddat holati', () {
      final now = DateTime(2026, 10, 5, 15);
      OpenDebt due(DateTime? d) => OpenDebt(
            txn: Txn(id: 1, typeId: 1, walletId: 1, amount: 1, date: now, note: '', dueDate: d),
            person: const Person(id: 1, name: 'A'),
            kind: TxKind.debtGive,
            remaining: 1,
          );
      expect(due(DateTime(2026, 10, 4)).isOverdue(now), isTrue);
      expect(due(DateTime(2026, 10, 5)).isOverdue(now), isFalse);
      expect(due(DateTime(2026, 10, 8)).isDueWithin(now, 3), isTrue);
      expect(due(DateTime(2026, 10, 9)).isDueWithin(now, 3), isFalse);
      expect(due(null).isDueWithin(now, 3), isFalse);
    });
  });

  group('byudjet', () {
    test('80% — ogohlantirish, 100% — oshgan', () async {
      final taksi = await db.typeId('Taksi');
      await repo.setBudget(taksi, 100000);
      await addTxn(repo, 'Taksi', 80000);

      var status = (await loadLedger(db)).budgetStatuses(DateTime(2026, 10)).single;
      expect(status.ratio, 0.8);
      expect(status.level, BudgetLevel.warning);

      await addTxn(repo, 'Taksi', 20000);
      status = (await loadLedger(db)).budgetStatuses(DateTime(2026, 10)).single;
      expect(status.level, BudgetLevel.over);

      await repo.setBudget(taksi, 500000);
      status = (await loadLedger(db)).budgetStatuses(DateTime(2026, 10)).single;
      expect(status.level, BudgetLevel.ok);
      expect(status.limit, 500000);
    });
  });

  test('tarix: yangisi birinchi, filtrlar ishlaydi', () async {
    await addTxn(repo, 'Taksi', 1000, date: DateTime(2026, 10, 1));
    await addTxn(repo, 'Tushlik', 2000, date: DateTime(2026, 10, 3), wallet: 'Karta');
    await repo.saveTransfer(
      fromWalletId: await db.walletId('Naqd'),
      toWalletId: await db.walletId('Karta'),
      amount: 500,
      date: DateTime(2026, 10, 2),
    );

    final ledger = await loadLedger(db);
    final all = ledger.history(month: DateTime(2026, 10));
    expect(all.map((h) => h.txn?.amount ?? h.transfer!.amount), [2000, 500, 1000]);

    final karta = ledger.history(walletId: await db.walletId('Karta'));
    expect(karta.map((h) => h.txn?.amount ?? h.transfer!.amount), [2000, 500]);

    final taksi = ledger.history(typeId: await db.typeId('Taksi'));
    expect(taksi.single.txn!.amount, 1000);
  });
}
