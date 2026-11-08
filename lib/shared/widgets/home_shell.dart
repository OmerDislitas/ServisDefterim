import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/daos/settings_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../features/photos/photo_actions.dart';
import '../../features/settings/backup_actions.dart';

/// Alt menulu ana iskelet. Sekmeler [StatefulNavigationShell] ile canli tutulur.
/// Acilista yarim kalan servis taslagi varsa devam edilip edilmeyecegini sorar (PLAN 7.6).
/// Bildirimleri planli tutar ve bildirime dokununca ilgili ekrani acar (PLAN 9).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    final scheduler = ref.read(notificationSchedulerProvider);
    _taps = scheduler.taps.listen(_openRoute);
    // Ilk kare cizildikten sonra (acilisi yavaslatmamak icin, PLAN 11)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      String? launched;
      try {
        launched = await scheduler.launchPayload();
      } catch (_) {
        launched = null;
      }
      if (!mounted) return;
      // Bildirimle acildiysa dogrudan ilgili ekran; taslak sorusu sonraki acilisa kalir
      if (launched != null) {
        _openRoute(launched);
      } else {
        await _checkDraft();
      }
      // Kamera acikken Android uygulamayi kapattiysa cekilen fotografi kaydet
      final recovered = await recoverLostPhotos(ref);
      if (recovered > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.photosRecovered(recovered))));
      }
      if (mounted) runAutoBackupIfNeeded(ref);
    });
    _lifecycle = AppLifecycleListener(
      onResume: () {
        // On plana gelince firsatci Drive yedegi (PLAN 8.4) ve gun degismis olabilir: bildirimleri tazele
        runAutoBackupIfNeeded(ref);
        ref.read(notificationSyncProvider).resync();
      },
    );
  }

  void _openRoute(String location) {
    if (!mounted) return;
    GoRouter.of(context).push(location);
  }

  @override
  void dispose() {
    _taps?.cancel();
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
    // Izlendigi surece veri degistikce bildirimler yeniden planlanir
    ref.watch(notificationSyncProvider);
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
