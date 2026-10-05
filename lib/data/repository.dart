import 'package:drift/drift.dart';

import '../domain/enums.dart';
import 'database.dart';

/// Foydalanuvchiga ko'rsatiladigan xato (matni o'zbekcha).
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Turni, hamyonni yoki odamni olib tashlash natijasi.
enum Removal { deleted, archived }

class SettingKeys {
  static const theme = 'theme';
  static const remindDayBefore = 'remindDayBefore';
}

class Repository {
  Repository(this.db);

  final AppDatabase db;

  static const backupFormat = 'hisobchi-backup';
  static const backupVersion = 1;

  // ------------------------------------------------------------- oqimlar

  Stream<List<Wallet>> watchWallets() => (db.select(db.wallets)
        ..orderBy([(w) => OrderingTerm(expression: w.sortOrder), (w) => OrderingTerm(expression: w.id)]))
      .watch();

  Stream<List<TxType>> watchTypes() => (db.select(db.txTypes)
        ..orderBy([(t) => OrderingTerm(expression: t.sortOrder), (t) => OrderingTerm(expression: t.id)]))
      .watch();

  Stream<List<Person>> watchPeople() =>
      (db.select(db.people)..orderBy([(p) => OrderingTerm(expression: p.name.lower())])).watch();

  Stream<List<Txn>> watchTransactions() => db.select(db.transactions).watch();

  Stream<List<Transfer>> watchTransfers() => db.select(db.transfers).watch();

  Stream<List<Budget>> watchBudgets() => db.select(db.budgets).watch();

  Stream<Map<String, String>> watchSettings() => db
      .select(db.settings)
      .watch()
      .map((rows) => {for (final r in rows) r.key: r.value});

  // -------------------------------------------------------- tranzaksiya

  Future<int> saveTransaction({
    int? id,
    required int typeId,
    required int walletId,
    required int amount,
    required DateTime date,
    String note = '',
    String? personName,
    DateTime? dueDate,
  }) {
    return db.transaction(() async {
      if (amount <= 0) throw const AppException('Summani kiriting');
      final type = await (db.select(db.txTypes)..where((t) => t.id.equals(typeId))).getSingleOrNull();
      if (type == null) throw const AppException('Tranzaksiya turi topilmadi');

      int? personId;
      if (type.kind.isDebt) {
        final name = personName?.trim() ?? '';
        if (name.isEmpty) throw const AppException('Kimligini kiriting');
        personId = await _findOrCreatePerson(name);
      }
      final row = TransactionsCompanion(
        typeId: Value(typeId),
        walletId: Value(walletId),
        amount: Value(amount),
        date: Value(date),
        note: Value(note.trim()),
        personId: Value(personId),
        dueDate: Value(type.kind.hasDueDate ? dueDate : null),
      );
      if (id == null) return db.into(db.transactions).insert(row);
      await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(row);
      return id;
    });
  }

  Future<void> deleteTransaction(int id) =>
      (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();

  Future<int> _findOrCreatePerson(String name) async {
    final existing = await _peopleNamed(name);
    if (existing.isNotEmpty) return existing.first.id;
    return db.into(db.people).insert(PeopleCompanion.insert(name: name));
  }

  /// Ism bo'yicha (katta-kichik harfsiz) qidirish. SQLite `lower()` faqat ASCII ni
  /// kichraytiradi, shuning uchun kirill ismlar uchun solishtirish Dart'da qilinadi.
  Future<List<Person>> _peopleNamed(String name) async {
    final key = name.trim().toLowerCase();
    final all = await db.select(db.people).get();
    return all.where((p) => p.name.toLowerCase() == key).toList();
  }

  // ----------------------------------------------------------- o'tkazma

  Future<int> saveTransfer({
    int? id,
    required int fromWalletId,
    required int toWalletId,
    required int amount,
    required DateTime date,
    String note = '',
  }) async {
    if (amount <= 0) throw const AppException('Summani kiriting');
    if (fromWalletId == toWalletId) throw const AppException('Hamyonlar bir xil bo\'lmasligi kerak');
    final row = TransfersCompanion(
      fromWalletId: Value(fromWalletId),
      toWalletId: Value(toWalletId),
      amount: Value(amount),
      date: Value(date),
      note: Value(note.trim()),
    );
    if (id == null) return db.into(db.transfers).insert(row);
    await (db.update(db.transfers)..where((t) => t.id.equals(id))).write(row);
    return id;
  }

  Future<void> deleteTransfer(int id) => (db.delete(db.transfers)..where((t) => t.id.equals(id))).go();

  // ---------------------------------------------------- tranzaksiya turi

  /// Yangi `normal` tur qo'shadi yoki mavjudini tahrirlaydi.
  /// Tizim (qarz) turlarida faqat ikonka va rang o'zgaradi.
  Future<int> saveType({
    int? id,
    required String name,
    required String icon,
    required int color,
    required TxDirection direction,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const AppException('Nomini kiriting');
    if (id == null) {
      final count = await _countWhere(db.txTypes, db.txTypes.direction.equalsValue(direction));
      return db.into(db.txTypes).insert(TxTypesCompanion.insert(
            name: trimmed,
            icon: icon,
            color: color,
            direction: direction,
            kind: TxKind.normal,
            sortOrder: Value(100 + count),
          ));
    }
    final type = await (db.select(db.txTypes)..where((t) => t.id.equals(id))).getSingle();
    await (db.update(db.txTypes)..where((t) => t.id.equals(id))).write(TxTypesCompanion(
          name: type.isSystem ? const Value.absent() : Value(trimmed),
          icon: Value(icon),
          color: Value(color),
        ));
    return id;
  }

  /// Ishlatilgan tur arxivlanadi, ishlatilmagani o'chiriladi. Tizim turlari tegilmaydi.
  Future<Removal> removeType(int id) => db.transaction(() async {
        final type = await (db.select(db.txTypes)..where((t) => t.id.equals(id))).getSingle();
        if (type.isSystem) throw const AppException('Qarz turlarini o\'chirib bo\'lmaydi');
        await (db.delete(db.budgets)..where((b) => b.typeId.equals(id))).go();
        if (await _countWhere(db.transactions, db.transactions.typeId.equals(id)) > 0) {
          await (db.update(db.txTypes)..where((t) => t.id.equals(id)))
              .write(const TxTypesCompanion(archived: Value(true)));
          return Removal.archived;
        }
        await (db.delete(db.txTypes)..where((t) => t.id.equals(id))).go();
        return Removal.deleted;
      });

  Future<void> restoreType(int id) => (db.update(db.txTypes)..where((t) => t.id.equals(id)))
      .write(const TxTypesCompanion(archived: Value(false)));

  // -------------------------------------------------------------- hamyon

  Future<int> saveWallet({
    int? id,
    required String name,
    required String icon,
    required int initialBalance,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const AppException('Nomini kiriting');
    final row = WalletsCompanion(
      name: Value(trimmed),
      icon: Value(icon),
      initialBalance: Value(initialBalance),
    );
    if (id == null) {
      final count = await _countWhere(db.wallets, const Constant(true));
      return db.into(db.wallets).insert(row.copyWith(sortOrder: Value(count)));
    }
    await (db.update(db.wallets)..where((w) => w.id.equals(id))).write(row);
    return id;
  }

  Future<Removal> removeWallet(int id) => db.transaction(() async {
        final used = await _countWhere(db.transactions, db.transactions.walletId.equals(id)) +
            await _countWhere(
              db.transfers,
              db.transfers.fromWalletId.equals(id) | db.transfers.toWalletId.equals(id),
            );
        if (used > 0) {
          await (db.update(db.wallets)..where((w) => w.id.equals(id)))
              .write(const WalletsCompanion(archived: Value(true)));
          return Removal.archived;
        }
        final active = await _countWhere(db.wallets, db.wallets.archived.equals(false));
        if (active <= 1) throw const AppException('Kamida bitta hamyon bo\'lishi kerak');
        await (db.delete(db.wallets)..where((w) => w.id.equals(id))).go();
        return Removal.deleted;
      });

  Future<void> restoreWallet(int id) => (db.update(db.wallets)..where((w) => w.id.equals(id)))
      .write(const WalletsCompanion(archived: Value(false)));

  // --------------------------------------------------------------- odam

  Future<int> savePerson({int? id, required String name, String? phone}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const AppException('Ismni kiriting');
    final clash = await _peopleNamed(trimmed);
    if (clash.any((p) => p.id != id)) throw const AppException('Bu ism allaqachon bor');
    final phoneValue = (phone?.trim().isEmpty ?? true) ? null : phone!.trim();
    final row = PeopleCompanion(name: Value(trimmed), phone: Value(phoneValue));
    if (id == null) return db.into(db.people).insert(row);
    await (db.update(db.people)..where((p) => p.id.equals(id))).write(row);
    return id;
  }

  Future<void> deletePerson(int id) async {
    if (await _countWhere(db.transactions, db.transactions.personId.equals(id)) > 0) {
      throw const AppException('Bu odam bilan qarz yozuvlari bor — avval ularni o\'chiring');
    }
    await (db.delete(db.people)..where((p) => p.id.equals(id))).go();
  }

  // ------------------------------------------------------------ byudjet

  /// [limit] null yoki 0 bo'lsa byudjet olib tashlanadi.
  Future<void> setBudget(int typeId, int? limit) async {
    if (limit == null || limit <= 0) {
      await (db.delete(db.budgets)..where((b) => b.typeId.equals(typeId))).go();
      return;
    }
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(typeId: typeId, monthlyLimit: limit),
          onConflict: DoUpdate(
            (_) => BudgetsCompanion(monthlyLimit: Value(limit)),
            target: [db.budgets.typeId],
          ),
        );
  }

  // --------------------------------------------------------- sozlamalar

  Future<void> setSetting(String key, String value) => db
      .into(db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  // ------------------------------------------------------- zaxira nusxa

  Future<Map<String, dynamic>> exportBackup() async => {
        'format': backupFormat,
        'version': backupVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'wallets': [for (final r in await db.select(db.wallets).get()) r.toJson()],
        'txTypes': [for (final r in await db.select(db.txTypes).get()) r.toJson()],
        'people': [for (final r in await db.select(db.people).get()) r.toJson()],
        'transactions': [for (final r in await db.select(db.transactions).get()) r.toJson()],
        'transfers': [for (final r in await db.select(db.transfers).get()) r.toJson()],
        'budgets': [for (final r in await db.select(db.budgets).get()) r.toJson()],
        'settings': [for (final r in await db.select(db.settings).get()) r.toJson()],
      };

  /// Joriy ma'lumotni zaxira nusxa bilan to'liq almashtiradi. Xato bo'lsa
  /// hech narsa o'zgarmaydi (hammasi bitta SQL tranzaksiya ichida).
  Future<void> importBackup(Object? json) async {
    const invalid = AppException('Fayl formati noto\'g\'ri');
    if (json is! Map<String, dynamic> || json['format'] != backupFormat || json['version'] != backupVersion) {
      throw invalid;
    }
    List<Map<String, dynamic>> rows(String key) {
      final list = json[key];
      if (list is! List) throw invalid;
      return list.cast<Map<String, dynamic>>();
    }

    try {
      await db.transaction(() async {
        await db.customStatement('PRAGMA defer_foreign_keys = ON');
        for (final table in <TableInfo>[db.budgets, db.transactions, db.transfers, db.people, db.txTypes, db.wallets, db.settings]) {
          await db.delete(table).go();
        }
        await db.batch((b) {
          b.insertAll(db.wallets, rows('wallets').map(Wallet.fromJson));
          b.insertAll(db.txTypes, rows('txTypes').map(TxType.fromJson));
          b.insertAll(db.people, rows('people').map(Person.fromJson));
          b.insertAll(db.transactions, rows('transactions').map(Txn.fromJson));
          b.insertAll(db.transfers, rows('transfers').map(Transfer.fromJson));
          b.insertAll(db.budgets, rows('budgets').map(Budget.fromJson));
          b.insertAll(db.settings, rows('settings').map(SettingEntry.fromJson));
        });
      });
    } on AppException {
      rethrow;
    } catch (_) {
      throw invalid;
    }
  }

  Future<int> _countWhere(TableInfo table, Expression<bool> where) async {
    final count = countAll();
    final query = db.selectOnly(table)
      ..addColumns([count])
      ..where(where);
    return (await query.getSingle()).read(count)!;
  }
}
