import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/splash/splash_screen.dart';
import 'state/providers.dart';

class HisobchiApp extends ConsumerWidget {
  const HisobchiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Qarzlar yoki sozlama o'zgarganda eslatmalar qayta rejalashtiriladi.
    ref.listen(reminderPlanProvider, (_, plan) {
      if (plan != null) ref.read(reminderServiceProvider).reschedule(plan);
    });

    return MaterialApp(
      title: 'Hisobchi',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('uz'),
      supportedLocales: const [Locale('uz')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const SplashScreen(),
    );
  }
}
