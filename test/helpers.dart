import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:hisobchi/data/database.dart';
import 'package:hisobchi/data/repository.dart';
import 'package:hisobchi/domain/enums.dart';
import 'package:hisobchi/domain/ledger.dart';

/// Zaxira nusxa testida ikkita baza bir vaqtda ochiladi — bu ataylab.
AppDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
  );
}

Future<Ledger> loadLedger(AppDatabase db) async => Ledger(
      wallets: await db.select(db.wallets).get(),
      types: await db.select(db.txTypes).get(),
      people: await db.select(db.people).get(),
      txns: await db.select(db.transactions).get(),
      transfers: await db.select(db.transfers).get(),
      budgets: await db.select(db.budgets).get(),
    );

extension TestLookups on AppDatabase {
  Future<int> walletId(String name) async =>
      (await (select(wallets)..where((w) => w.name.equals(name))).getSingle()).id;

  Future<int> typeId(String name) async =>
      (await (select(txTypes)..where((t) => t.name.equals(name))).getSingle()).id;

  Future<int> kindTypeId(TxKind kind) async =>
      (await (select(txTypes)..where((t) => t.kind.equalsValue(kind))).getSingle()).id;
}

/// Qisqa yozuv uchun: tur nomi bo'yicha tranzaksiya qo'shadi.
Future<int> addTxn(
  Repository repo,
  String typeName,
  int amount, {
  String wallet = 'Naqd',
  DateTime? date,
  String? person,
  DateTime? due,
}) async =>
    repo.saveTransaction(
      typeId: await repo.db.typeId(typeName),
      walletId: await repo.db.walletId(wallet),
      amount: amount,
      date: date ?? DateTime(2026, 10, 5, 12),
      personName: person,
      dueDate: due,
    );
