# Hisobchi v1 — dizayn spetsifikatsiyasi

Sana: 2026-10-05 · Holat: tasdiqlash kutilmoqda

## 1. Maqsad

Doston uchun shaxsiy moliya Android ilovasi (APK). Faqat bitta foydalanuvchi, faqat telefonda,
server/hosting/akkaunt yo'q. v1 da AI yo'q — AI (matn, ovoz, chek, tahlil) v2 da qo'shiladi.

**Muvaffaqiyat mezoni:** Doston har kungi kirim/chiqim va qarzlarini 10 soniyadan kam vaqtda
kiritadi, hamyonlar balansi real holatga mos keladi, qarz muddati kelganda eslatma oladi.

## 2. Cheklovlar

- Platforma: Android (APK, sideload). Minimal Android 7.0 (API 24).
- To'liq oflayn. Internet umuman kerak emas.
- Til: o'zbek (lotin). Valyuta: so'm, butun son (tiyinsiz). Raqam formati: `117 200 so'm`.
- Texnologiya: Flutter (Dart), Material 3.

## 3. Asosiy tushunchalar

### 3.1 Hamyon (wallet)
Standart: Naqd, Karta, Payme, Click, Hisob raqam. Foydalanuvchi qo'shadi/tahrirlaydi/arxivlaydi.
Maydonlar: nom, ikonka, boshlang'ich balans. **Joriy balans saqlanmaydi — har doim
`boshlang'ich + kirimlar − chiqimlar ± o'tkazmalar` sifatida hisoblanadi.**
Tranzaksiyasi bor hamyonni o'chirib bo'lmaydi, faqat arxivlanadi.

### 3.2 Tranzaksiya turi (tx_type)
Kirim va chiqim **faqat** tranzaksiya turi orqali kiritiladi.
Maydonlar: nom, ikonka, rang, yo'nalish (`income` | `expense`), `kind`
(`normal` | `debt_take` | `debt_collect` | `debt_give` | `debt_repay`), `is_system`.

Standart turlar:

| Kirim | Chiqim |
|---|---|
| Maosh | Taksi |
| Boshqa kirim | Tushlik |
| Qarz olish (`debt_take`, tizim) | Oziq-ovqat |
| Qarzni qaytarib olish (`debt_collect`, tizim) | Kommunal |
| | Boshqa chiqim |
| | Qarz berish (`debt_give`, tizim) |
| | Qarzni qaytarish (`debt_repay`, tizim) |

Foydalanuvchi `normal` turlarni qo'shadi/tahrirlaydi/o'chiradi (ishlatilgan bo'lsa — arxivlanadi).
Tizim (qarz) turlarini o'chirib/arxivlab bo'lmaydi, faqat ikonka/rang o'zgaradi.

### 3.3 Odam (person)
Qarz bo'yicha kontragent. Maydonlar: ism, telefon (ixtiyoriy). Qarz formasida ro'yxatdan
tanlanadi yoki yangi ism yozib darhol yaratiladi.

### 3.4 Tranzaksiya
Maydonlar: tur, hamyon, summa (>0), sana-vaqt, izoh (ixtiyoriy), odam (faqat qarz turlarida —
majburiy), qaytarish sanasi (faqat `debt_take`/`debt_give` — ixtiyoriy).

### 3.5 O'tkazma
Bir hamyondan boshqasiga. Bitta `transfers` yozuvi: qayerdan, qayerga, summa, sana, izoh.
Statistikada kirim/chiqim hisoblanmaydi.

### 3.6 Qarz qoldig'i
Har bir odam uchun: `menga_qarzdor = Σ debt_give − Σ debt_collect`,
`men_qarzdorman = Σ debt_take − Σ debt_repay`. Ikkalasi alohida ko'rsatiladi.

### 3.7 Byudjet
Chiqim turi (`normal`) uchun oylik limit. Joriy oy sarfi ≥80% — sariq, ≥100% — qizil.
Limitdan oshganda saqlashdan keyin snackbar ogohlantirish.

## 4. Statistika qoidasi
Qarz turlari va o'tkazmalar **daromad/xarajat statistikasiga kirmaydi**; ular faqat hamyon
balansiga ta'sir qiladi. Bosh sahifadagi "Shu oy kirim/chiqim" ham faqat `normal` turlar.

## 5. Ekranlar

1. **Splash** — zumrad fon, logo (doira ichida "H" + o'suvchi chiziq) chiziladi/kattalashadi,
   "Hisobchi" yozuvi paydo bo'ladi (~1.5 s), keyin Bosh sahifa.
2. **Bosh sahifa** — umumiy balans (barcha faol hamyonlar), hamyon kartochkalari (gorizontal),
   shu oy kirim/chiqim, ikki katta tugma **+ Kirim** / **− Chiqim**, o'tkazma tugmasi,
   muddati yaqin/o'tgan qarzlar ogohlantirishi, oxirgi 10 yozuv.
3. **Kirim/Chiqim oynasi** (bottom sheet, namunaviy rasmdagi kabi):
   tur (dropdown/chip) → [qarz bo'lsa: Kim? + qaytarish sanasi] → hamyon kartochkalari
   (balans bilan, 2 ustunli grid) → summa (raqamli, `117 200` formatlash) → sana → izoh → Saqlash.
   Chiqim hamyon balansidan katta bo'lsa — ogohlantirish (lekin saqlashga ruxsat beriladi).
4. **O'tkazma oynasi** — qayerdan/qayerga hamyon, summa, sana, izoh.
5. **Tarix** — kunlar bo'yicha guruhlangan; filtr: oy, tur, hamyon. Bosib tahrirlash, surib o'chirish
   (tasdiq bilan).
6. **Qarzlar** — ikki tab: "Menga qarzdor" / "Men qarzdorman". Odam kartochkasi: qoldiq, eng yaqin
   muddat; muddati o'tgan — qizil. Odamni bosish → shu odam tarixi + "Qaytarildi" tezkor tugmasi.
7. **Statistika** — oy tanlash; chiqim turlari donut diagrammasi; 6 oylik kirim/chiqim ustunli
   grafigi; byudjetlar progress barlari.
8. **Sozlamalar** — tranzaksiya turlari, hamyonlar, odamlar, byudjetlar, mavzu (tizim/kunduz/tun),
   eslatmalar (1 kun oldin eslatish: yoq/o'chiq), zaxira nusxa (JSON eksport — ulashish; import —
   fayl tanlash, joriy ma'lumotni almashtirish tasdiq bilan).

Pastki navigatsiya: Bosh · Tarix · Qarzlar · Statistika · Sozlamalar.

## 6. Eslatmalar (bildirishnomalar)
`flutter_local_notifications` + `timezone`, Asia/Tashkent.
Qaytarish sanasi bor har bir ochiq qarz tranzaksiyasi uchun:
- muddat kuni 09:00 — `debt_give`: "Bugun {ism}dan {qoldiq} so'm qarzni undirish kuni";
  `debt_take`: "Bugun {ism}ga {qoldiq} so'm qarzingizni qaytarish kuni".
- muddatdan 1 kun oldin 09:00 — "Ertaga ..." (sozlamada o'chirsa bo'ladi).
Eslatmalar har ilova ochilganda va har qarz o'zgarishida qayta rejalashtiriladi
(odam bo'yicha qoldiq 0 bo'lsa — bekor qilinadi). Telefon qayta yoqilganda saqlanadi.
Android 13+ da bildirishnoma ruxsati so'raladi; aniq vaqt uchun `inexact` rejim yetarli.

## 7. Arxitektura

- `lib/data/` — drift baza (`wallets`, `tx_types`, `people`, `transactions`, `transfers`,
  `budgets`, `settings`), repozitoriylar, birinchi ishga tushirishda standart ma'lumot (seed).
- `lib/domain/` — sof hisob-kitob funksiyalari: balans, qarz qoldig'i, byudjet holati, statistika.
  Flutter'ga bog'liq emas → unit testlar.
- `lib/features/<home|history|debts|stats|settings|transaction_form|transfer|splash>/` — UI.
- `lib/core/` — mavzu, formatlash (`117 200 so'm`), ikonka ro'yxati, eslatma servisi.
- Holat: `flutter_riverpod`; drift `watch` oqimlari orqali UI avtomatik yangilanadi.
- Kutubxonalar: drift, sqlite3_flutter_libs, flutter_riverpod, fl_chart, flutter_animate,
  flutter_local_notifications, timezone, share_plus, file_picker, intl.
- **v2 AI uchun ulanish nuqtasi:** `TransactionDraft` (tur, summa, hamyon, odam, izoh, sana) —
  forma shu obyekt bilan ochiladi; AI keyin faqat draft yaratadi.

## 8. Dizayn
Material 3, asosiy rang `#10B981`. Kunduz foni `#F8FAFC`, tun `#0F172A`. Kirim — yashil,
chiqim — marjon-qizil `#F43F5E`. Kartochkalar 20px radius, yumshoq soya. Ekranlar orasida
yumshoq o'tish animatsiyalari, ro'yxat elementlari ketma-ket paydo bo'ladi.
Ilova nomi: **Hisobchi**, paket: `uz.hisobchi.app`.

## 9. Xatolar
- Summa bo'sh/0 — saqlash tugmasi faol emas. Qarz turida odam tanlanmagan — xato matni.
- Import fayli noto'g'ri — "Fayl formati noto'g'ri", mavjud ma'lumot o'zgarmaydi (tranzaksiya ichida).
- Baza xatosi — snackbar, ilova yiqilmaydi.

## 10. Sinov
- Unit: balans hisobi (o'tkazmalar bilan), qarz qoldig'i (qisman qaytarish), byudjet foizi,
  statistikadan qarz/o'tkazmalarni chiqarib tashlash, summa formatlash, JSON eksport→import aylanma.
- Widget: tranzaksiya formasi (qarz turida "Kim?" ko'rinishi, validatsiya).
- Qo'lda: APK emulyatorda/telefonda — asosiy oqimlar.

## 11. Yetkazish
APK sessiyada quriladi va foydalanuvchiga yuboriladi. Repoga `.github/workflows/build-apk.yml`
qo'shiladi (push ruxsati ochilgach APK avtomatik artifact sifatida chiqadi).

## 12. v1 ga kirmaydi
AI (matn/ovoz/chek/tahlil), bulut sinxronizatsiya, bir nechta valyuta, iOS, parol/PIN, eksport Excel.
