import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../domain/ledger.dart';
import '../../state/providers.dart';
import '../debts/debts_screen.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../transaction_form/transaction_sheet.dart';
import '../transfer/transfer_sheet.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _pages = [HomeScreen(), HistoryScreen(), DebtsScreen(), StatsScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    // Android 13+ da bildirishnoma ruxsati (qarz eslatmalari uchun).
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(reminderServiceProvider).requestPermission());
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(shellIndexProvider);
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(index), child: _pages[index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: ref.read(shellIndexProvider.notifier).go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Bosh'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Tarix'),
          NavigationDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake_rounded), label: 'Qarzlar'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline_rounded), selectedIcon: Icon(Icons.pie_chart_rounded), label: 'Statistika'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Sozlamalar'),
        ],
      ),
    );
  }
}

/// Tarix elementini bosganda tegishli tahrirlash oynasini ochadi.
void openHistoryItem(BuildContext context, HistoryItem item, Ledger ledger) {
  if (item.txn case final Txn t) {
    showTransactionSheet(context, draftFromTxn(t, ledger));
  } else {
    showTransferSheet(context, transfer: item.transfer);
  }
}
