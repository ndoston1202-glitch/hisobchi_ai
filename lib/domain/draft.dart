import 'enums.dart';

/// Tranzaksiya formasini ochish uchun boshlang'ich qiymatlar.
///
/// v2 da AI (matn, ovoz, chek) aynan shu obyektni yaratadi — forma o'zgarmaydi.
class TransactionDraft {
  const TransactionDraft({
    required this.direction,
    this.id,
    this.typeId,
    this.walletId,
    this.amount,
    this.personName,
    this.note,
    this.date,
    this.dueDate,
  });

  final TxDirection direction;

  /// Mavjud tranzaksiyani tahrirlashda uning id si.
  final int? id;
  final int? typeId;
  final int? walletId;
  final int? amount;
  final String? personName;
  final String? note;
  final DateTime? date;
  final DateTime? dueDate;
}
