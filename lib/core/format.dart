/// O'zbekcha formatlash yordamchilari (lotin yozuvi).
library;

const _months = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
];

/// `117200` → `117 200`.
String formatAmount(int value) {
  final digits = value.abs().toString();
  final buf = StringBuffer(value < 0 ? '−' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// `117200` → `117 200 so'm`.
String formatMoney(int value) => "${formatAmount(value)} so'm";

/// Foydalanuvchi kiritgan matndan summa: raqamdan boshqa belgilar tashlanadi.
int parseAmount(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}

String monthName(int month) => _months[month - 1];

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// `Oktabr 2026`.
String formatMonth(DateTime d) => '${capitalize(monthName(d.month))} ${d.year}';

/// `5-oktabr, 2026`.
String formatDate(DateTime d) => '${d.day}-${monthName(d.month)}, ${d.year}';

/// `5-oktabr` (joriy yil bo'lsa) yoki `5-oktabr, 2025`.
String formatShortDate(DateTime d, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  return d.year == ref.year ? '${d.day}-${monthName(d.month)}' : formatDate(d);
}

/// `09:05`.
String formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Tarix guruh sarlavhasi: `Bugun`, `Kecha` yoki sana.
String formatDayHeader(DateTime d, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final today = DateTime(ref.year, ref.month, ref.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Bugun';
  if (diff == 1) return 'Kecha';
  return formatShortDate(d, now: ref);
}

/// Qarz muddati haqida qisqa matn: `bugun`, `ertaga`, `3 kun qoldi`, `2 kun o'tdi`.
String formatDueRelative(DateTime due, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final day = DateTime(due.year, due.month, due.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'bugun';
  if (diff == 1) return 'ertaga';
  if (diff > 1) return '$diff kun qoldi';
  return "${-diff} kun o'tdi";
}
