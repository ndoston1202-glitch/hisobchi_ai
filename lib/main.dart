import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/notifications.dart';
import 'data/database.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final reminders = ReminderService();
  await reminders.init();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(AppDatabase()),
        reminderServiceProvider.overrideWithValue(reminders),
      ],
      child: const HisobchiApp(),
    ),
  );
}
