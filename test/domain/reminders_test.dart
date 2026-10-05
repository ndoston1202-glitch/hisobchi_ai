import 'package:flutter_test/flutter_test.dart';
import 'package:hisobchi/data/database.dart';
import 'package:hisobchi/data/repository.dart';
import 'package:hisobchi/domain/reminders.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = memoryDb();
    repo = Repository(db);
  });
  tearDown(() => db.close());

  test('qarz berishda muddat kuni va bir kun oldin undirish eslatmasi', () async {
    final id = await addTxn(repo, 'Qarz berish', 150000, person: 'Ali', due: DateTime(2026, 10, 10));
    await addTxn(repo, 'Qarzni qaytarib olish', 50000, person: 'Ali');

    final reminders = planReminders(
      (await loadLedger(db)).openDebts(),
      now: DateTime(2026, 10, 5, 12),
      remindDayBefore: true,
    );

    expect(reminders, hasLength(2));
    final onDay = reminders.firstWhere((r) => r.id == id * 2);
    expect(onDay.when, DateTime(2026, 10, 10, 9));
    expect(onDay.title, 'Qarzni undiring');
    expect(onDay.body, "Bugun Alidan 100 000 so'm qarzni undirish kuni");

    final before = reminders.firstWhere((r) => r.id == id * 2 + 1);
    expect(before.when, DateTime(2026, 10, 9, 9));
    expect(before.body, "Ertaga Alidan 100 000 so'm qarzni undirish kuni");
  });

  test('qarz olishda qaytarish eslatmasi, bir kun oldingisi o\'chirilgan', () async {
    await addTxn(repo, 'Qarz olish', 300000, person: 'Vali', due: DateTime(2026, 11, 1));

    final reminders = planReminders(
      (await loadLedger(db)).openDebts(),
      now: DateTime(2026, 10, 5),
      remindDayBefore: false,
    );

    expect(reminders.single.title, 'Qarzingizni qaytaring');
    expect(reminders.single.body, "Bugun Valiga 300 000 so'm qarzingizni qaytarish kuni");
  });

  test('o\'tib ketgan vaqt, muddatsiz va yopilgan qarzlar uchun eslatma yo\'q', () async {
    await addTxn(repo, 'Qarz berish', 10000, person: 'A', due: DateTime(2026, 10, 5));
    await addTxn(repo, 'Qarz berish', 10000, person: 'B');
    await addTxn(repo, 'Qarz olish', 10000, person: 'C', due: DateTime(2026, 12, 1));
    await addTxn(repo, 'Qarzni qaytarish', 10000, person: 'C');

    final reminders = planReminders(
      (await loadLedger(db)).openDebts(),
      now: DateTime(2026, 10, 5, 10),
      remindDayBefore: true,
    );
    expect(reminders, isEmpty);
  });
}
