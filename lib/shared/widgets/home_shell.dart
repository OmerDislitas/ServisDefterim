import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/daos/settings_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../features/settings/backup_actions.dart';

/// Alt menulu ana iskelet. Sekmeler [StatefulNavigationShell] ile canli tutulur.
/// Acilista yarim kalan servis taslagi varsa devam edilip edilmeyecegini sorar (PLAN 7.6).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Ilk kare cizildikten sonra (acilisi yavaslatmamak icin, PLAN 11)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkDraft();
      if (mounted) runAutoBackupIfNeeded(ref);
    });
    // On plana gelince firsatci Drive yedegi (PLAN 8.4)
    _lifecycle = AppLifecycleListener(onResume: () => runAutoBackupIfNeeded(ref));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _checkDraft() async {
    final settings = ref.read(databaseProvider).settingsDao;
    final draft = await settings.getValue(SettingKeys.serviceDraft);
    if (draft == null || !mounted) return;
    final resume = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.draftTitle),
        content: const Text(S.draftResumeBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.draftDiscard)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(S.draftContinue)),
        ],
      ),
    );
    if (!mounted) return;
    if (resume == true) {
      context.push(Routes.resumeServiceDraft);
    } else if (resume == false) {
      await settings.setValue(SettingKeys.serviceDraft, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          // Ayni sekmeye tekrar dokununca sekmenin baslangicina don.
          initialLocation: index == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: S.tabToday,
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: S.tabCalendar,
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: S.tabCustomers,
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: S.tabReceivables,
          ),
        ],
      ),
    );
  }
}
