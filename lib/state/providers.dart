import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications.dart';
import '../data/database.dart';
import '../data/repository.dart';
import '../domain/ledger.dart';
import '../domain/reminders.dart';

final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('main() da beriladi'));

final reminderServiceProvider = Provider<ReminderService>((ref) => ReminderService());

final repositoryProvider = Provider<Repository>((ref) => Repository(ref.watch(databaseProvider)));

final _walletsProvider = StreamProvider((ref) => ref.watch(repositoryProvider).watchWallets());
final _typesProvider = StreamProvider((ref) => ref.watch(repositoryProvider).watchTypes());
final _peopleProvider = StreamProvider((ref) => ref.watch(repositoryProvider).watchPeople());
final _txnsProvider = StreamProvider((ref) => ref.watch(repositoryProvider).watchTransactions());
final _transfersProvider = StreamProvider((ref) => ref.watch(repositoryProvider).watchTransfers());
final _budgetsProvider = StreamProvider((ref) => ref.watch(repositoryProvider).watchBudgets());
final _settingsProvider = StreamProvider((ref) => ref.watch(repositoryProvider).watchSettings());

/// Barcha ma'lumot yuklanguncha `null`.
final ledgerProvider = Provider<Ledger?>((ref) {
  final wallets = ref.watch(_walletsProvider).value;
  final types = ref.watch(_typesProvider).value;
  final people = ref.watch(_peopleProvider).value;
  final txns = ref.watch(_txnsProvider).value;
  final transfers = ref.watch(_transfersProvider).value;
  final budgets = ref.watch(_budgetsProvider).value;
  if (wallets == null ||
      types == null ||
      people == null ||
      txns == null ||
      transfers == null ||
      budgets == null) {
    return null;
  }
  return Ledger(
    wallets: wallets,
    types: types,
    people: people,
    txns: txns,
    transfers: transfers,
    budgets: budgets,
  );
});

final settingsProvider = Provider<Map<String, String>>(
  (ref) => ref.watch(_settingsProvider).value ?? const {},
);

final themeModeProvider = Provider<ThemeMode>((ref) {
  return switch (ref.watch(settingsProvider)[SettingKeys.theme]) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
});

final remindDayBeforeProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider)[SettingKeys.remindDayBefore] != '0',
);

final reminderPlanProvider = Provider<List<PlannedReminder>?>((ref) {
  final ledger = ref.watch(ledgerProvider);
  if (ledger == null) return null;
  return planReminders(
    ledger.openDebts(),
    now: DateTime.now(),
    remindDayBefore: ref.watch(remindDayBeforeProvider),
  );
});

// ------------------------------------------------------------ navigatsiya

class ShellIndex extends Notifier<int> {
  @override
  int build() => 0;

  void go(int index) => state = index;
}

final shellIndexProvider = NotifierProvider<ShellIndex, int>(ShellIndex.new);

class HistoryFilter {
  const HistoryFilter({required this.month, this.typeId, this.walletId});

  final DateTime month;
  final int? typeId;
  final int? walletId;

  HistoryFilter copyWith({DateTime? month, int? Function()? typeId, int? Function()? walletId}) =>
      HistoryFilter(
        month: month ?? this.month,
        typeId: typeId != null ? typeId() : this.typeId,
        walletId: walletId != null ? walletId() : this.walletId,
      );
}

class HistoryFilterNotifier extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() {
    final now = DateTime.now();
    return HistoryFilter(month: DateTime(now.year, now.month));
  }

  void shiftMonth(int delta) =>
      state = state.copyWith(month: DateTime(state.month.year, state.month.month + delta));

  void setType(int? id) => state = state.copyWith(typeId: () => id);

  void setWallet(int? id) => state = state.copyWith(walletId: () => id);

  void showWallet(int id) {
    final now = DateTime.now();
    state = HistoryFilter(month: DateTime(now.year, now.month), walletId: id);
  }
}

final historyFilterProvider = NotifierProvider<HistoryFilterNotifier, HistoryFilter>(HistoryFilterNotifier.new);
