import 'package:fonar/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTorch extends Torch {
  FakeTorch();

  final calls = <bool>[];

  @override
  Future<bool> get available async => true;

  @override
  Future<void> set(bool on) async => calls.add(on);
}

void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

/// Fonar tugmasi doimiy pulsatsiya qiladi, shuning uchun pumpAndSettle tugamaydi.
/// Birinchi pump animatsiyani boshlaydi, ikkinchisi oxiriga yetkazadi.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('yoqishda pul so\'raydi, "To\'lash" — hazil, keyin fonar yonadi', (tester) async {
    phoneSize(tester);
    final torch = FakeTorch();
    await tester.pumpWidget(FonarApp(torch: torch));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
    await settle(tester);
    expect(find.text('Fonar Premium'), findsOneWidget);
    expect(find.text("9 900 so'm"), findsOneWidget);
    expect(torch.calls, isEmpty, reason: 'to\'lovsiz yonmaydi');

    await tester.tap(find.text("To'lash"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("To'lov amalga oshirilmoqda..."), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(find.text('HAZIL!'), findsOneWidget);
    expect(find.textContaining("Hech qanday to'lov olinmadi"), findsOneWidget);

    await tester.tap(find.text('Fonarni yoqish'));
    await settle(tester);
    expect(find.text('Yoniq'), findsOneWidget);
    expect(torch.calls, [true]);

    // Hazil bir marta: o'chirib qayta yoqqanda pul so'ramaydi.
    await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
    await settle(tester);
    expect(find.text('Fonar Premium'), findsNothing);
    expect(torch.calls, [true, false, true]);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('"Keyinroq" bosilsa fonar yonmaydi va keyingi safar yana so\'raydi', (tester) async {
    phoneSize(tester);
    final torch = FakeTorch();
    await tester.pumpWidget(FonarApp(torch: torch));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
    await settle(tester);
    await tester.tap(find.text('Keyinroq'));
    await settle(tester);
    expect(find.text('Yoqish uchun bosing'), findsOneWidget);
    expect(torch.calls, isEmpty);

    await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
    await settle(tester);
    expect(find.text('Fonar Premium'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
