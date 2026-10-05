import '../data/database.dart';
import 'enums.dart';

/// Bazaning bir lahzalik to'liq ko'rinishi. Barcha hisob-kitoblar shu ustida —
/// Flutter'ga bog'liq emas, shuning uchun unit testlarda bevosita sinaladi.
class Ledger {
  Ledger({
    required this.wallets,
    required this.types,
    required this.people,
    required this.txns,
    required this.transfers,
    required this.budgets,
  })  : walletById = {for (final w in wallets) w.id: w},
        typeById = {for (final t in types) t.id: t},
        personById = {for (final p in people) p.id: p};

  final List<Wallet> wallets;
  final List<TxType> types;
  final List<Person> people;
  final List<Txn> txns;
  final List<Transfer> transfers;
  final List<Budget> budgets;

  final Map<int, Wallet> walletById;
  final Map<int, TxType> typeById;
  final Map<int, Person> personById;

  List<Wallet> get activeWallets => wallets.where((w) => !w.archived).toList();

  List<TxType> activeTypes(TxDirection direction) =>
      types.where((t) => t.direction == direction && !t.archived).toList();

  TxKind kindOf(Txn t) => typeById[t.typeId]!.kind;
  TxDirection directionOf(Txn t) => typeById[t.typeId]!.direction;

  // ---------------------------------------------------------------- balans

  /// Hamyon balansi: boshlang'ich + kirimlar − chiqimlar ± o'tkazmalar.
  Map<int, int> walletBalances() {
    final result = {for (final w in wallets) w.id: w.initialBalance};
    for (final t in txns) {
      final sign = directionOf(t) == TxDirection.income ? 1 : -1;
      result[t.walletId] = (result[t.walletId] ?? 0) + sign * t.amount;
    }
    for (final tr in transfers) {
      result[tr.fromWalletId] = (result[tr.fromWalletId] ?? 0) - tr.amount;
      result[tr.toWalletId] = (result[tr.toWalletId] ?? 0) + tr.amount;
    }
    return result;
  }

  int totalBalance() {
    final balances = walletBalances();
    return activeWallets.fold(0, (sum, w) => sum + (balances[w.id] ?? 0));
  }

  // ---------------------------------------------------------- statistika

  /// Faqat `normal` turlar: qarz va o'tkazmalar daromad/xarajat hisoblanmaydi.
  MonthTotals monthTotals(DateTime month) {
    var income = 0;
    var expense = 0;
    for (final t in txns) {
      if (!_sameMonth(t.date, month) || kindOf(t) != TxKind.normal) continue;
      if (directionOf(t) == TxDirection.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return MonthTotals(month: DateTime(month.year, month.month), income: income, expense: expense);
  }

  /// Oxirgi [count] oy (eng eskisi birinchi), [month] ham kiradi.
  List<MonthTotals> lastMonths(DateTime month, {int count = 6}) => [
        for (var i = count - 1; i >= 0; i--)
          monthTotals(DateTime(month.year, month.month - i)),
      ];

  /// Oy bo'yicha `normal` chiqim turlari kesimida sarf, kamayish tartibida.
  List<(TxType, int)> expenseByType(DateTime month) {
    final sums = <int, int>{};
    for (final t in txns) {
      if (!_sameMonth(t.date, month)) continue;
      final type = typeById[t.typeId]!;
      if (type.kind != TxKind.normal || type.direction != TxDirection.expense) continue;
      sums[type.id] = (sums[type.id] ?? 0) + t.amount;
    }
    final list = [for (final e in sums.entries) (typeById[e.key]!, e.value)];
    list.sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }

  // ------------------------------------------------------------ byudjet

  List<BudgetStatus> budgetStatuses(DateTime month) {
    final spentByType = {for (final (type, sum) in expenseByType(month)) type.id: sum};
    return [
      for (final b in budgets)
        if (typeById[b.typeId] case final type? when !type.archived)
          BudgetStatus(type: type, limit: b.monthlyLimit, spent: spentByType[type.id] ?? 0),
    ];
  }

  // --------------------------------------------------------------- qarz

  /// Har bir qarz yozuvining qolgan qismi. Qaytarishlar eng eski qarzdan
  /// boshlab (FIFO) yopiladi, shuning uchun qisman qaytarish ham to'g'ri hisoblanadi.
  List<OpenDebt> openDebts() {
    final result = <OpenDebt>[];
    for (final person in people) {
      result
        ..addAll(_fifo(person, TxKind.debtGive, TxKind.debtCollect))
        ..addAll(_fifo(person, TxKind.debtTake, TxKind.debtRepay));
    }
    return result;
  }

  List<OpenDebt> _fifo(Person person, TxKind debtKind, TxKind payKind) {
    final debts = <Txn>[];
    var paid = 0;
    for (final t in txns) {
      if (t.personId != person.id) continue;
      final kind = kindOf(t);
      if (kind == debtKind) debts.add(t);
      if (kind == payKind) paid += t.amount;
    }
    debts.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    final open = <OpenDebt>[];
    for (final d in debts) {
      final covered = paid >= d.amount ? d.amount : paid;
      paid -= covered;
      final remaining = d.amount - covered;
      if (remaining > 0) {
        open.add(OpenDebt(txn: d, person: person, kind: debtKind, remaining: remaining));
      }
    }
    return open;
  }

  /// Odamlar bo'yicha qarz qoldig'i. Qoldig'i yo'q odamlar ham qaytariladi
  /// (tarixini ko'rish uchun), UI o'zi filtrlaydi.
  List<PersonDebt> personDebts() {
    final open = openDebts();
    return [
      for (final person in people)
        PersonDebt(
          person: person,
          owedToMe: _sum(person, TxKind.debtGive) - _sum(person, TxKind.debtCollect),
          iOwe: _sum(person, TxKind.debtTake) - _sum(person, TxKind.debtRepay),
          open: open.where((d) => d.person.id == person.id).toList(),
        ),
    ];
  }

  PersonDebt debtOf(Person person) =>
      personDebts().firstWhere((d) => d.person.id == person.id);

  int _sum(Person person, TxKind kind) => txns
      .where((t) => t.personId == person.id && kindOf(t) == kind)
      .fold(0, (sum, t) => sum + t.amount);

  // -------------------------------------------------------------- tarix

  /// Tranzaksiya va o'tkazmalar, yangisi birinchi.
  List<HistoryItem> history({DateTime? month, int? typeId, int? walletId}) {
    final items = <HistoryItem>[
      for (final t in txns)
        if ((month == null || _sameMonth(t.date, month)) &&
            (typeId == null || t.typeId == typeId) &&
            (walletId == null || t.walletId == walletId))
          HistoryItem.txn(t),
      if (typeId == null)
        for (final tr in transfers)
          if ((month == null || _sameMonth(tr.date, month)) &&
              (walletId == null || tr.fromWalletId == walletId || tr.toWalletId == walletId))
            HistoryItem.transfer(tr),
    ];
    items.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
    return items;
  }

  static bool _sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
}

class MonthTotals {
  const MonthTotals({required this.month, required this.income, required this.expense});

  final DateTime month;
  final int income;
  final int expense;
}

enum BudgetLevel { ok, warning, over }

class BudgetStatus {
  const BudgetStatus({required this.type, required this.limit, required this.spent});

  final TxType type;
  final int limit;
  final int spent;

  double get ratio => spent / limit;

  BudgetLevel get level => ratio >= 1
      ? BudgetLevel.over
      : ratio >= 0.8
          ? BudgetLevel.warning
          : BudgetLevel.ok;
}

class OpenDebt {
  const OpenDebt({
    required this.txn,
    required this.person,
    required this.kind,
    required this.remaining,
  });

  final Txn txn;
  final Person person;

  /// [TxKind.debtGive] (menga qarzdor) yoki [TxKind.debtTake] (men qarzdorman).
  final TxKind kind;
  final int remaining;

  DateTime? get dueDate => txn.dueDate;
  bool get owedToMe => kind == TxKind.debtGive;

  bool isOverdue(DateTime now) => dueDate != null && dueDate!.isBefore(_day(now));

  /// Bugundan boshlab [days] kun ichida muddati keladimi (o'tganlari ham kiradi).
  bool isDueWithin(DateTime now, int days) =>
      dueDate != null && !dueDate!.isAfter(_day(now).add(Duration(days: days)));
}

class PersonDebt {
  const PersonDebt({
    required this.person,
    required this.owedToMe,
    required this.iOwe,
    required this.open,
  });

  final Person person;

  /// Σ qarz berish − Σ qaytarib olish.
  final int owedToMe;

  /// Σ qarz olish − Σ qaytarish.
  final int iOwe;
  final List<OpenDebt> open;

  DateTime? nearestDue({required bool owedToMe}) {
    DateTime? best;
    for (final d in open) {
      if (d.owedToMe != owedToMe || d.dueDate == null) continue;
      if (best == null || d.dueDate!.isBefore(best)) best = d.dueDate;
    }
    return best;
  }
}

class HistoryItem {
  HistoryItem.txn(Txn this.txn) : transfer = null;
  HistoryItem.transfer(Transfer this.transfer) : txn = null;

  final Txn? txn;
  final Transfer? transfer;

  int get id => txn?.id ?? transfer!.id;
  DateTime get date => txn?.date ?? transfer!.date;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
