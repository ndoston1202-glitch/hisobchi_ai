import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminders.dart';

/// Qarz muddati eslatmalarini rejalashtiradi. Xatolar ilovani yiqitmaydi.
class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  late final tz.Location _location;
  bool _ready = false;
  String? _lastSignature;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'debt_reminders',
      'Qarz eslatmalari',
      channelDescription: 'Qarzni qaytarish va undirish kuni haqida eslatmalar',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      _location = tz.getLocation('Asia/Tashkent');
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Eslatmalarni ishga tushirib bo\'lmadi: $e');
    }
  }

  /// Android 13+ da bildirishnoma ruxsatini so'raydi.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Barcha rejalashtirilgan eslatmalarni [plan] bilan almashtiradi.
  /// Reja o'zgarmagan bo'lsa hech narsa qilmaydi.
  Future<void> reschedule(List<PlannedReminder> plan) async {
    if (!_ready) return;
    final signature = plan.map((r) => '${r.id}|${r.when}|${r.body}').join('\n');
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    try {
      await _plugin.cancelAllPendingNotifications();
      for (final r in plan) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime(_location, r.when.year, r.when.month, r.when.day, r.when.hour, r.when.minute),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      _lastSignature = null;
      debugPrint('Eslatmalarni rejalashtirib bo\'lmadi: $e');
    }
  }
}
