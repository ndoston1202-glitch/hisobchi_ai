import 'package:flutter_test/flutter_test.dart';
import 'package:hisobchi/core/format.dart';

void main() {
  group('formatAmount', () {
    test('minglik guruhlarini bo\'sh joy bilan ajratadi', () {
      expect(formatAmount(0), '0');
      expect(formatAmount(999), '999');
      expect(formatAmount(1000), '1 000');
      expect(formatAmount(117200), '117 200');
      expect(formatAmount(1234567), '1 234 567');
    });

    test('manfiy son', () {
      expect(formatAmount(-25000), '−25 000');
    });
  });

  test('formatMoney', () {
    expect(formatMoney(117200), "117 200 so'm");
  });

  test('parseAmount raqam bo\'lmagan belgilarni tashlaydi', () {
    expect(parseAmount('117 200'), 117200);
    expect(parseAmount(''), 0);
    expect(parseAmount("50 000 so'm"), 50000);
  });

  test('sana formatlari', () {
    final d = DateTime(2026, 10, 5, 9, 7);
    expect(formatDate(d), '5-oktabr, 2026');
    expect(formatMonth(d), 'Oktabr 2026');
    expect(formatTime(d), '09:07');
    expect(formatShortDate(d, now: DateTime(2026, 1, 1)), '5-oktabr');
    expect(formatShortDate(d, now: DateTime(2027, 1, 1)), '5-oktabr, 2026');
  });

  test('formatDayHeader', () {
    final now = DateTime(2026, 10, 5, 20);
    expect(formatDayHeader(DateTime(2026, 10, 5, 1), now: now), 'Bugun');
    expect(formatDayHeader(DateTime(2026, 10, 4, 23), now: now), 'Kecha');
    expect(formatDayHeader(DateTime(2026, 10, 1), now: now), '1-oktabr');
  });

  test('formatDueRelative', () {
    final now = DateTime(2026, 10, 5, 20);
    expect(formatDueRelative(DateTime(2026, 10, 5), now: now), 'bugun');
    expect(formatDueRelative(DateTime(2026, 10, 6), now: now), 'ertaga');
    expect(formatDueRelative(DateTime(2026, 10, 8), now: now), '3 kun qoldi');
    expect(formatDueRelative(DateTime(2026, 10, 3), now: now), "2 kun o'tdi");
  });
}
