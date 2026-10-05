// Drift ustun tekshiruvlari (check) getter ichida o'z ustuniga murojaat qiladi.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/enums.dart';
import 'seed.dart';

part 'database.g.dart';

class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get icon => text()();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('TxType')
class TxTypes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  TextColumn get direction => textEnum<TxDirection>()();
  TextColumn get kind => textEnum<TxKind>()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('Person')
class People extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get phone => text().nullable()();
}

@DataClassName('Txn')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get typeId => integer().references(TxTypes, #id)();
  IntColumn get walletId => integer().references(Wallets, #id)();
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get personId => integer().nullable().references(People, #id)();
  DateTimeColumn get dueDate => dateTime().nullable()();
}

class Transfers extends Table {
  IntColumn get id => integer().autoIncrement()();
  @ReferenceName('outgoingTransfers')
  IntColumn get fromWalletId => integer().references(Wallets, #id)();
  @ReferenceName('incomingTransfers')
  IntColumn get toWalletId => integer().references(Wallets, #id)();
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get typeId => integer().unique().references(TxTypes, #id)();
  IntColumn get monthlyLimit => integer().check(monthlyLimit.isBiggerThanValue(0))();
}

@DataClassName('SettingEntry')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [Wallets, TxTypes, People, Transactions, Transfers, Budgets, Settings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'hisobchi'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDefaults(this);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
