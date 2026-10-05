import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisobchi/data/database.dart';
import 'package:hisobchi/data/repository.dart';
import 'package:hisobchi/domain/enums.dart';

import '../helpers.dart';

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = memoryDb();
    repo = Repository(db);
  });
  tearDown(() => db.close());

  test('standart hamyonlar va turlar yaratiladi', () async {
    final wallets = await db.select(db.wallets).get();
    expect(wallets.map((w) => w.name), ['Naqd', 'Karta', 'Payme', 'Click', 'Hisob raqam']);

    final types = await db.select(db.txTypes).get();
    final income = types.where((t) => t.direction == TxDirection.income).map((t) => t.name);
    final expense = types.where((t) => t.direction == TxDirection.expense).map((t) => t.name);
    expect(income, ['Maosh', 'Boshqa kirim', 'Qarz olish', 'Qarzni qaytarib olish']);
    expect(expense, [
      'Taksi', 'Tushlik', 'Oziq-ovqat', 'Kommunal', 'Boshqa chiqim', 'Qarz berish', 'Qarzni qaytarish',
    ]);
    expect(types.where((t) => t.isSystem).map((t) => t.kind).toSet(), {
      TxKind.debtTake, TxKind.debtCollect, TxKind.debtGive, TxKind.debtRepay,
    });
  });

  group('tranzaksiya', () {
    test('qarz turida odam majburiy', () async {
      expect(
        () => addTxn(repo, 'Qarz berish', 1000),
        throwsA(isA<AppException>().having((e) => e.message, 'message', 'Kimligini kiriting')),
      );
    });

    test('summa musbat bo\'lishi kerak', () async {
      expect(() => addTxn(repo, 'Taksi', 0), throwsA(isA<AppException>()));
    });

    test('oddiy turda odam va muddat saqlanmaydi', () async {
      final id = await addTxn(repo, 'Taksi', 1000, person: 'Ali', due: DateTime(2026, 11, 1));
      final txn = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
      expect(txn.personId, isNull);
      expect(txn.dueDate, isNull);
      expect(await db.select(db.people).get(), isEmpty);
    });

    test('qaytarish turida muddat saqlanmaydi', () async {
      final id = await addTxn(repo, 'Qarzni qaytarish', 1000, person: 'Ali', due: DateTime(2026, 11, 1));
      final txn = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
      expect(txn.personId, isNotNull);
      expect(txn.dueDate, isNull);
    });

    test('tahrirlash', () async {
      final id = await addTxn(repo, 'Taksi', 1000);
      await repo.saveTransaction(
        id: id,
        typeId: await db.typeId('Tushlik'),
        walletId: await db.walletId('Karta'),
        amount: 35000,
        date: DateTime(2026, 10, 6),
        note: '  ofis  ',
      );
      final txn = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
      expect(txn.amount, 35000);
      expect(txn.note, 'ofis');
      expect(txn.typeId, await db.typeId('Tushlik'));
    });
  });

  group('turlar', () {
    test('foydalanuvchi yangi tur qo\'shadi, ishlatilmagani o\'chadi', () async {
      final id = await repo.saveType(name: 'Sport zal', icon: 'sport', color: 0xFF000000, direction: TxDirection.expense);
      final type = await (db.select(db.txTypes)..where((t) => t.id.equals(id))).getSingle();
      expect(type.kind, TxKind.normal);
      expect(type.isSystem, isFalse);
      expect(await repo.removeType(id), Removal.deleted);
    });

    test('ishlatilgan tur arxivlanadi va byudjeti olib tashlanadi', () async {
      final taksi = await db.typeId('Taksi');
      await repo.setBudget(taksi, 100000);
      await addTxn(repo, 'Taksi', 1000);
      expect(await repo.removeType(taksi), Removal.archived);
      expect(await db.select(db.budgets).get(), isEmpty);
      await repo.restoreType(taksi);
      final type = await (db.select(db.txTypes)..where((t) => t.id.equals(taksi))).getSingle();
      expect(type.archived, isFalse);
    });

    test('tizim turini o\'chirib bo\'lmaydi, faqat ikonka/rang o\'zgaradi', () async {
      final id = await db.kindTypeId(TxKind.debtGive);
      expect(() => repo.removeType(id), throwsA(isA<AppException>()));

      await repo.saveType(id: id, name: 'Boshqa nom', icon: 'gift', color: 0xFF123456, direction: TxDirection.expense);
      final type = await (db.select(db.txTypes)..where((t) => t.id.equals(id))).getSingle();
      expect(type.name, 'Qarz berish');
      expect(type.icon, 'gift');
      expect(type.color, 0xFF123456);
    });
  });

  group('hamyon va odam', () {
    test('ishlatilmagan hamyon o\'chadi', () async {
      expect(await repo.removeWallet(await db.walletId('Payme')), Removal.deleted);
    });

    test('qarzi bor odamni o\'chirib bo\'lmaydi', () async {
      await addTxn(repo, 'Qarz berish', 1000, person: 'Ali');
      final ali = (await db.select(db.people).get()).single;
      expect(() => repo.deletePerson(ali.id), throwsA(isA<AppException>()));
    });

    test('kirill ism ham katta-kichik harfsiz bitta odam', () async {
      await addTxn(repo, 'Qarz berish', 1000, person: 'Алишер');
      await addTxn(repo, 'Qarz berish', 2000, person: 'алишер');
      expect(await db.select(db.people).get(), hasLength(1));
      expect(() => repo.savePerson(name: 'АЛИШЕР'), throwsA(isA<AppException>()));
    });

    test('takroriy ism rad etiladi', () async {
      await repo.savePerson(name: 'Ali');
      expect(() => repo.savePerson(name: ' ALI '), throwsA(isA<AppException>()));
    });
  });

  group('zaxira nusxa', () {
    test('eksport → import aylanmasi ma\'lumotni to\'liq tiklaydi', () async {
      final customType = await repo.saveType(name: 'Kitob', icon: 'book', color: 0xFF0000FF, direction: TxDirection.expense);
      await addTxn(repo, 'Maosh', 2000000, wallet: 'Karta');
      await addTxn(repo, 'Qarz berish', 100000, person: 'Ali', due: DateTime(2026, 10, 20));
      await repo.saveTransfer(
        fromWalletId: await db.walletId('Karta'),
        toWalletId: await db.walletId('Naqd'),
        amount: 300000,
        date: DateTime(2026, 10, 5, 8),
        note: 'bankomat',
      );
      await repo.setBudget(customType, 50000);
      await repo.setSetting(SettingKeys.theme, 'dark');

      final json = jsonDecode(jsonEncode(await repo.exportBackup()));
      final before = await loadLedger(db);

      final other = memoryDb();
      addTearDown(other.close);
      await Repository(other).importBackup(json);
      final after = await loadLedger(other);

      expect(after.wallets, before.wallets);
      expect(after.types, before.types);
      expect(after.people, before.people);
      expect(after.txns, before.txns);
      expect(after.transfers, before.transfers);
      expect(after.budgets, before.budgets);
      expect(after.walletBalances(), before.walletBalances());
      expect(await other.select(other.settings).get(), await db.select(db.settings).get());
    });

    test('noto\'g\'ri fayl mavjud ma\'lumotni o\'zgartirmaydi', () async {
      await addTxn(repo, 'Maosh', 1000);
      final message = isA<AppException>().having((e) => e.message, 'message', "Fayl formati noto'g'ri");

      await expectLater(repo.importBackup({'format': 'boshqa'}), throwsA(message));
      await expectLater(
        repo.importBackup({
          'format': Repository.backupFormat,
          'version': Repository.backupVersion,
          'wallets': [
            {'id': 1, 'name': 'X', 'icon': 'cash', 'initialBalance': 0, 'archived': false, 'sortOrder': 0},
          ],
          'txTypes': 'buzilgan',
        }),
        throwsA(message),
      );

      expect(await db.select(db.transactions).get(), hasLength(1));
      expect(await db.select(db.wallets).get(), hasLength(5));
    });
  });
}
