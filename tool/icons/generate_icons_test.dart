// Android ikonkalarini logodan (LogoPainter) yaratadi.
//
//   flutter test tool/icons/generate_icons_test.dart
//
// Natija android/app/src/main/res/mipmap-*/ ga yoziladi.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisobchi/widgets/logo.dart';

const _res = 'android/app/src/main/res';
const _densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

Future<void> _render(WidgetTester tester, Widget child, double size, String path) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(key: key, child: SizedBox.square(dimension: size, child: child)),
      ),
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

void main() {
  testWidgets('ikonkalar', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final MapEntry(key: density, value: scale) in _densities.entries) {
      // Eski launcherlar uchun: yashil doira ichida logo (48dp).
      final legacy = 48 * scale;
      await _render(tester, HisobchiLogo(size: legacy), legacy, '$_res/mipmap-$density/ic_launcher.png');

      // Adaptiv ikonka old qatlami: 108dp maydon, logo 66dp xavfsiz zonada (fon — brend rangi).
      final adaptive = 108 * scale;
      await _render(
        tester,
        Center(child: HisobchiLogo(size: 72 * scale, onBrand: true)),
        adaptive,
        '$_res/mipmap-$density/ic_launcher_foreground.png',
      );
    }
  });
}
