// Ilova ikonkalari va skrinshotlarni yaratadi:
//
//   flutter test tool/assets_test.dart --update-goldens
//
// Ikonkalar android/app/src/main/res/mipmap-*/ ga, skrinshotlar tool/out/ ga yoziladi.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fonar/main.dart';

const _res = 'android/app/src/main/res';
const _densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

Future<void> _loadFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold', 'Black']) {
    roboto.addFont(Future.value(ByteData.sublistView(File('$dir/Roboto-$w.ttf').readAsBytesSync())));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File('$dir/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

class _NoTorch extends Torch {
  @override
  Future<bool> get available async => true;

  @override
  Future<void> set(bool on) async {}
}

Future<void> _renderPng(WidgetTester tester, Widget child, double size, String path) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: RepaintBoundary(key: key, child: SizedBox.square(dimension: size, child: child))),
    ),
  );
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Widget _legacyIcon(double size) => Container(
  decoration: const BoxDecoration(
    shape: BoxShape.circle,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFE08A), amber, Color(0xFFFF9F43)],
    ),
  ),
  child: Icon(Icons.flashlight_on_rounded, size: size * 0.56, color: const Color(0xFF3A2500)),
);

void main() {
  setUpAll(_loadFonts);

  testWidgets('ikonkalar', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final MapEntry(key: density, value: scale) in _densities.entries) {
      await _renderPng(tester, _legacyIcon(48 * scale), 48 * scale, '$_res/mipmap-$density/ic_launcher.png');
      // Adaptiv ikonka old qatlami: 108dp, ikonka xavfsiz zonada; fon — @color/brand.
      await _renderPng(
        tester,
        Icon(Icons.flashlight_on_rounded, size: 56 * scale, color: const Color(0xFF3A2500)),
        108 * scale,
        '$_res/mipmap-$density/ic_launcher_foreground.png',
      );
    }
  });

  testWidgets('skrinshotlar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    debugDisableShadows = false;

    Future<void> shot(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    await tester.pumpWidget(FonarApp(torch: _NoTorch()));
    await settle();
    await shot('1_fonar');

    await tester.tap(find.byIcon(Icons.power_settings_new_rounded));
    await settle();
    await shot('2_tolov');

    await tester.tap(find.text("To'lash"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await shot('3_kutish');

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await shot('4_hazil');

    await tester.tap(find.text('Fonarni yoqish'));
    await settle();
    await shot('5_yoniq');

    await tester.pumpWidget(const SizedBox());
    debugDisableShadows = true;
  });
}
