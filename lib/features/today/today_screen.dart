import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/daos/appointments_dao.dart';
import '../../core/db/daos/devices_dao.dart';
import '../../core/db/daos/services_dao.dart';
import '../../core/db/daos/settings_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/maintenance.dart';
import '../../shared/widgets/appointment_tile.dart';
import '../../shared/widgets/due_device_tile.dart';
import '../../shared/widgets/new_service_fab.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/service_tile.dart';
import '../settings/backup_actions.dart';

final _todayAppointmentsProvider = StreamProvider.autoDispose<List<AppointmentListItem>>((ref) {
  final t = today();
  return ref.watch(databaseProvider).appointmentsDao.watchAppointments(from: t, to: addDays(t, 1));
});

final _recentServicesProvider = StreamProvider.autoDispose<List<ServiceListItem>>(
  (ref) => ref.watch(databaseProvider).servicesDao.watchServiceList(limit: 5),
);

/// Bugun ekrani bakim listelerinin sadece ilk satirlarini ve sayisini okur;
/// tam liste "Tumunu gor" ile acilan ekranda (PLAN 11: acilista sadece gereken sorgular).
final _duePreviewProvider = StreamProvider.autoDispose.family<List<DueDeviceItem>, DueFilter>(
  (ref, filter) => ref.watch(databaseProvider).devicesDao.watchDueDevices(filter, limit: TodayScreen._maxRows),
);

final _dueCountProvider = StreamProvider.autoDispose.family<int, DueFilter>(
  (ref, filter) => ref.watch(databaseProvider).devicesDao.watchDueCount(filter),
);

final _lastBackupProvider = StreamProvider.autoDispose<DateTime?>(
  (ref) => ref
      .watch(databaseProvider)
      .settingsDao
      .watchValue(SettingKeys.lastBackupAt)
      .map((v) => v == null ? null : DateTime.tryParse(v)),
);

/// Bugun (ana ekran, PLAN 7.1): yedek uyarisi, bugunku randevular, gecikmis bakimlar,
/// bu hafta bakimi gelenler, son servisler.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  static const _maxRows = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(_todayAppointmentsProvider).value;
    final overdue = ref.watch(_duePreviewProvider(DueFilter.overdue)).value;
    final overdueCount = ref.watch(_dueCountProvider(DueFilter.overdue)).value ?? overdue?.length ?? 0;
    final thisWeek = ref.watch(_duePreviewProvider(DueFilter.thisWeek)).value;
    final thisWeekCount = ref.watch(_dueCountProvider(DueFilter.thisWeek)).value ?? thisWeek?.length ?? 0;
    final recent = ref.watch(_recentServicesProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(formatDateLong(today())),
        actions: [
          IconButton(
            tooltip: S.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const _BackupCard(),

          // Bugunku randevular
          const SectionHeader(title: S.todayAppointments),
          if (appointments != null && appointments.isEmpty)
            const _Hint(text: S.noAppointmentsToday),
          for (final a in appointments ?? const <AppointmentListItem>[]) AppointmentTile(item: a),

          // Gecikmis bakimlar
          if (overdue != null && overdue.isNotEmpty) ...[
            SectionHeader(
              title: S.overdueMaintenance,
              action: _CountBadge(count: overdueCount),
            ),
            ..._dueRows(overdue),
            _SeeAll(onTap: () => context.push(Routes.dueMaintenance(DueFilter.overdue)), total: overdueCount),
          ],

          // Bu hafta
          SectionHeader(title: S.thisWeekMaintenance, action: _CountBadge(count: thisWeekCount, neutral: true)),
          if (thisWeek != null && thisWeek.isEmpty) const _Hint(text: S.nothingDue),
          if (thisWeek != null && thisWeek.isNotEmpty) ...[
            ..._dueRows(thisWeek),
            _SeeAll(onTap: () => context.push(Routes.dueMaintenance(DueFilter.thisWeek)), total: thisWeekCount),
          ],

          // Son servisler
          if (recent != null && recent.isNotEmpty) ...[
            const SectionHeader(title: S.recentServices),
            for (final s in recent) ServiceTile(item: s, showCustomer: true),
          ],
        ],
      ),
      floatingActionButton: const NewServiceFab(),
    );
  }

  List<Widget> _dueRows(List<DueDeviceItem> items) => [
        for (final (i, item) in items.take(_maxRows).indexed) ...[
          if (i > 0) const Divider(height: 1, indent: 16),
          DueDeviceTile(item: item),
        ],
      ];
}

class _BackupCard extends ConsumerWidget {
  const _BackupCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_lastBackupProvider);
    if (!async.hasValue) return const SizedBox.shrink();
    final last = async.value;
    final theme = Theme.of(context);
    final days = last == null ? null : daysBetween(last, DateTime.now());
    final driveError = ref.watch(settingValueProvider(SettingKeys.driveLastError)).value;

    // Drive hatasi kullaniciyi engellemez, burada gosterilir (PLAN 8.4)
    if (driveError != null) {
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        color: theme.colorScheme.errorContainer,
        child: _WarningCardBody(
          icon: Icons.cloud_off_outlined,
          title: driveError,
          subtitle: last == null ? null : S.backupLast('${relativeDay(last)} ${formatTime(last)}'),
          actionLabel: S.goToSettings,
          onAction: () => context.push(Routes.settings),
        ),
      );
    }

    // Son yedek 7 gunden yeniyse kucuk bir satir yeter
    if (days != null && days < 7) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            Icon(Icons.cloud_done_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(S.backupLast('${relativeDay(last!)} ${formatTime(last)}'), style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: theme.colorScheme.errorContainer,
      child: _WarningCardBody(
        icon: Icons.warning_amber_rounded,
        title: days == null ? S.backupNone : S.backupOld(days),
        bold: true,
        subtitle: S.backupNowHint,
        actionLabel: S.backupNow,
        onAction: () => exportAndShareBackup(context, ref),
      ),
    );
  }
}

/// Uyari kartinin icerigi: ikon, baslik, aciklama ve sagda alta hizali buton.
/// ListTile'in `trailing` butonu buyuk yazida tasiyordu; burada buton metnin altina gecer.
class _WarningCardBody extends StatelessWidget {
  const _WarningCardBody({
    required this.icon,
    required this.title,
    this.subtitle,
    this.bold = false,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool bold;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onErrorContainer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: bold ? FontWeight.w600 : null)),
                if (subtitle != null) Text(subtitle!, style: TextStyle(color: color)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: onAction, child: Text(actionLabel)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, this.neutral = false});

  final int count;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Badge(
        label: Text('$count'),
        backgroundColor: neutral ? scheme.secondary : scheme.error,
        textColor: neutral ? scheme.onSecondary : scheme.onError,
        largeSize: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

class _SeeAll extends StatelessWidget {
  const _SeeAll({required this.onTap, required this.total});

  final VoidCallback onTap;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TextButton(
          onPressed: onTap,
          child: Text(total > TodayScreen._maxRows ? '${S.seeAll} (${S.moreItems(total - TodayScreen._maxRows)})' : S.seeAll),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}
