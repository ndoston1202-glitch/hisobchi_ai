import '../core/format.dart';
import 'ledger.dart';

/// Rejalashtiriladigan bitta eslatma (vaqt Asia/Tashkent bo'yicha talqin qilinadi).
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime when;
  final String title;
  final String body;

  @override
  String toString() => 'PlannedReminder($id, $when, $title, $body)';
}

const reminderHour = 9;

/// Ochiq qarzlar bo'yicha eslatmalar ro'yxati: muddat kuni 09:00 da va
/// (agar yoqilgan bo'lsa) bir kun oldin 09:00 da. O'tib ketgan vaqtlar tashlanadi.
List<PlannedReminder> planReminders(
  List<OpenDebt> debts, {
  required DateTime now,
  required bool remindDayBefore,
}) {
  final result = <PlannedReminder>[];
  for (final debt in debts) {
    final due = debt.dueDate;
    if (due == null) continue;
    final onDay = DateTime(due.year, due.month, due.day, reminderHour);
    final dayBefore = DateTime(due.year, due.month, due.day - 1, reminderHour);

    if (onDay.isAfter(now)) {
      result.add(_reminder(debt, onDay, 'Bugun', id: debt.txn.id * 2));
    }
    if (remindDayBefore && dayBefore.isAfter(now)) {
      result.add(_reminder(debt, dayBefore, 'Ertaga', id: debt.txn.id * 2 + 1));
    }
  }
  return result;
}

PlannedReminder _reminder(OpenDebt debt, DateTime when, String day, {required int id}) {
  final name = debt.person.name;
  final amount = formatMoney(debt.remaining);
  return debt.owedToMe
      ? PlannedReminder(
          id: id,
          when: when,
          title: 'Qarzni undiring',
          body: "$day ${name}dan $amount qarzni undirish kuni",
        )
      : PlannedReminder(
          id: id,
          when: when,
          title: 'Qarzingizni qaytaring',
          body: "$day ${name}ga $amount qarzingizni qaytarish kuni",
        );
}
