/// Tranzaksiya yo'nalishi.
enum TxDirection { income, expense }

/// Tranzaksiya turi xili. Qarz turlari tizim turlari bo'lib, odam talab qiladi.
enum TxKind {
  normal,

  /// Qarz olish — menga pul keldi, men qarzdorman.
  debtTake,

  /// Qarzni qaytarib olish — menga qarzdor odam qaytardi.
  debtCollect,

  /// Qarz berish — men pul berdim, u menga qarzdor.
  debtGive,

  /// Qarzni qaytarish — men olgan qarzimni qaytardim.
  debtRepay;

  bool get isDebt => this != TxKind.normal;

  /// Qaytarish sanasi faqat yangi qarz yaratadigan turlarda bo'ladi.
  bool get hasDueDate => this == TxKind.debtTake || this == TxKind.debtGive;

  TxDirection get direction => switch (this) {
        TxKind.debtTake || TxKind.debtCollect => TxDirection.income,
        TxKind.debtGive || TxKind.debtRepay => TxDirection.expense,
        TxKind.normal => throw StateError('normal tur yo\'nalishi o\'zida saqlanadi'),
      };
}
