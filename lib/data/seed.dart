import 'package:drift/drift.dart';

import '../domain/enums.dart';
import 'database.dart';

/// Birinchi ishga tushirishda yaratiladigan standart hamyonlar va turlar.
Future<void> seedDefaults(AppDatabase db) async {
  const wallets = [
    ('Naqd', 'cash'),
    ('Karta', 'card'),
    ('Payme', 'phone'),
    ('Click', 'phone'),
    ('Hisob raqam', 'bank'),
  ];
  for (final (i, (name, icon)) in wallets.indexed) {
    await db.into(db.wallets).insert(
          WalletsCompanion.insert(name: name, icon: icon, sortOrder: Value(i)),
        );
  }

  const types = <(String, String, int, TxDirection, TxKind)>[
    ('Maosh', 'salary', 0xFF10B981, TxDirection.income, TxKind.normal),
    ('Boshqa kirim', 'plus', 0xFF14B8A6, TxDirection.income, TxKind.normal),
    ('Qarz olish', 'debt_in', 0xFF6366F1, TxDirection.income, TxKind.debtTake),
    ('Qarzni qaytarib olish', 'handshake', 0xFF0EA5E9, TxDirection.income, TxKind.debtCollect),
    ('Taksi', 'taxi', 0xFFF59E0B, TxDirection.expense, TxKind.normal),
    ('Tushlik', 'lunch', 0xFFF97316, TxDirection.expense, TxKind.normal),
    ('Oziq-ovqat', 'basket', 0xFF84CC16, TxDirection.expense, TxKind.normal),
    ('Kommunal', 'bolt', 0xFFEAB308, TxDirection.expense, TxKind.normal),
    ('Boshqa chiqim', 'more', 0xFF94A3B8, TxDirection.expense, TxKind.normal),
    ('Qarz berish', 'debt_out', 0xFF8B5CF6, TxDirection.expense, TxKind.debtGive),
    ('Qarzni qaytarish', 'handshake', 0xFFEC4899, TxDirection.expense, TxKind.debtRepay),
  ];
  for (final (i, (name, icon, color, direction, kind)) in types.indexed) {
    await db.into(db.txTypes).insert(
          TxTypesCompanion.insert(
            name: name,
            icon: icon,
            color: color,
            direction: direction,
            kind: kind,
            isSystem: Value(kind.isDebt),
            sortOrder: Value(i),
          ),
        );
  }
}
