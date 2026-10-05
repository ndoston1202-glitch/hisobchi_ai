import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../data/repository.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/logo.dart';
import 'budgets_screen.dart';
import 'people_screen.dart';
import 'types_screen.dart';
import 'wallets_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final remindDayBefore = ref.watch(remindDayBeforeProvider);
    final repo = ref.read(repositoryProvider);

    void push(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: const Text('Sozlamalar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const SectionTitle("Ma'lumotlar"),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _NavTile(icon: Icons.category_rounded, title: 'Tranzaksiya turlari', subtitle: 'Taksi, Tushlik, o\'zingiznikini qo\'shing', onTap: () => push(const TypesScreen())),
                _NavTile(icon: Icons.account_balance_wallet_rounded, title: 'Hamyonlar', subtitle: 'Naqd, Karta, Payme, Click…', onTap: () => push(const WalletsScreen())),
                _NavTile(icon: Icons.people_alt_rounded, title: 'Odamlar', subtitle: 'Qarz bo\'yicha kontaktlar', onTap: () => push(const PeopleScreen())),
                _NavTile(icon: Icons.savings_rounded, title: 'Byudjetlar', subtitle: 'Oylik chiqim limitlari', onTap: () => push(const BudgetsScreen())),
              ],
            ),
          ),
          const SectionTitle("Ko'rinish"),
          AppCard(
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('Tizim')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Kunduz')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Tun')),
                ],
                selected: {themeMode},
                onSelectionChanged: (s) => repo.setSetting(SettingKeys.theme, switch (s.first) {
                  ThemeMode.light => 'light',
                  ThemeMode.dark => 'dark',
                  ThemeMode.system => 'system',
                }),
              ),
            ),
          ),
          const SectionTitle('Eslatmalar'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_rounded),
                  title: const Text('1 kun oldin ham eslatish'),
                  subtitle: const Text('Qarz muddati kuni 09:00 da doim eslatiladi'),
                  value: remindDayBefore,
                  onChanged: (v) => repo.setSetting(SettingKeys.remindDayBefore, v ? '1' : '0'),
                ),
                _NavTile(
                  icon: Icons.notifications_rounded,
                  title: 'Bildirishnomaga ruxsat',
                  subtitle: 'Eslatmalar kelmasa — shu yerni bosing',
                  onTap: () async {
                    final granted = await ref.read(reminderServiceProvider).requestPermission();
                    if (context.mounted) {
                      showSnack(context, granted ? 'Ruxsat berilgan' : 'Telefon sozlamalaridan Hisobchi uchun bildirishnomani yoqing');
                    }
                  },
                ),
              ],
            ),
          ),
          const SectionTitle('Zaxira nusxa'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.upload_file_rounded,
                  title: 'Eksport (JSON)',
                  subtitle: 'Faylni Telegram, Drive va h.k. ga saqlang',
                  onTap: () => _export(context, ref),
                ),
                _NavTile(
                  icon: Icons.download_rounded,
                  title: 'Import',
                  subtitle: 'Joriy ma\'lumot fayldagisi bilan almashtiriladi',
                  onTap: () => _import(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Center(child: HisobchiLogo(size: 48)),
          const SizedBox(height: 8),
          Center(
            child: Text('Hisobchi v1.0.0', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final data = await ref.read(repositoryProvider).exportBackup();
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final file = File(p.join(dir.path, 'hisobchi-$stamp.json'));
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], title: 'Hisobchi zaxira nusxasi'));
    } catch (e) {
      if (context.mounted) showSnack(context, 'Eksport qilib bo\'lmadi: $e', error: true);
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Import',
      message: 'Hozirgi barcha ma\'lumotlar fayldagi ma\'lumot bilan almashtiriladi. Davom etasizmi?',
      action: 'Davom etish',
    );
    if (!ok) return;
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
      if (file == null) return;
      final Object? json;
      try {
        json = jsonDecode(utf8.decode(await file.readAsBytes()));
      } on FormatException {
        throw const AppException('Fayl formati noto\'g\'ri');
      }
      await ref.read(repositoryProvider).importBackup(json);
      if (context.mounted) showSnack(context, 'Ma\'lumotlar tiklandi');
    } on AppException catch (e) {
      if (context.mounted) showSnack(context, e.message, error: true);
    } catch (e) {
      if (context.mounted) showSnack(context, 'Import qilib bo\'lmadi: $e', error: true);
    }
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconBadge(icon: icon, color: brandColor, size: 38),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
