import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/daos/settings_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/db/sample_data.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../../shared/widgets/section_header.dart';
import 'backup_actions.dart';

final _defaultIntervalProvider = StreamProvider.autoDispose<int>(
  (ref) => ref
      .watch(databaseProvider)
      .settingsDao
      .watchValue(SettingKeys.defaultIntervalMonths)
      .map((v) => int.tryParse(v ?? '') ?? 12),
);

final _lastBackupProvider = StreamProvider.autoDispose<DateTime?>(
  (ref) => ref
      .watch(databaseProvider)
      .settingsDao
      .watchValue(SettingKeys.lastBackupAt)
      .map((v) => v == null ? null : DateTime.tryParse(v)),
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _editInterval(BuildContext context, WidgetRef ref, int current) async {
    final controller = TextEditingController(text: '$current');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.defaultInterval),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: S.maintenanceInterval),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(S.cancel)),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              if (n != null && n >= 1 && n <= 60) Navigator.pop(context, n);
            },
            child: const Text(S.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      await ref.read(databaseProvider).settingsDao.setInt(SettingKeys.defaultIntervalMonths, value);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interval = ref.watch(_defaultIntervalProvider).value ?? 12;
    final lastBackup = ref.watch(_lastBackupProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text(S.settings)),
      body: ListView(
        children: [
          const SectionHeader(title: S.backup),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              lastBackup == null ? S.backupNone : S.backupLast(formatDateTime(lastBackup)),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text(S.exportBackup),
            subtitle: const Text(S.exportBackupHint),
            onTap: () => exportAndShareBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text(S.restoreFromFile),
            subtitle: const Text(S.restoreFromFileHint),
            onTap: () => restoreFromFile(context, ref),
          ),
          const _DriveSection(),
          const SectionHeader(title: S.settingsMaintenance),
          ListTile(
            leading: const Icon(Icons.event_repeat_outlined),
            title: const Text(S.defaultInterval),
            subtitle: Text(S.monthsValue(interval)),
            onTap: () => _editInterval(context, ref, interval),
          ),
          ListTile(
            leading: const Icon(Icons.checklist),
            title: const Text(S.checklistItems),
            subtitle: const Text(S.checklistItemsHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.checklistSettings),
          ),
          const SectionHeader(title: S.settingsMessages),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text(S.whatsappTemplate),
            subtitle: const Text(S.whatsappTemplateHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.whatsappTemplateSettings),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text(S.otherSettingsLater),
          ),
          const _About(),
          if (kDebugMode) const _DebugTools(),
        ],
      ),
    );
  }
}

/// Google Drive: bagla / bagli hesap / baglantiyi kes, simdi yedekle, otomatik yedek,
/// Drive'dan geri yukle (PLAN 7.10, 8.4).
class _DriveSection extends ConsumerWidget {
  const _DriveSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final drive = ref.watch(driveServiceProvider);
    if (!drive.isConfigured) {
      return const ListTile(
        leading: Icon(Icons.cloud_off_outlined),
        title: Text(S.driveNotConfigured),
        subtitle: Text(S.driveNotConfiguredHint),
      );
    }

    final email = ref.watch(settingValueProvider(SettingKeys.driveAccountEmail)).value;
    final auto = ref.watch(settingValueProvider(SettingKeys.driveAutoBackup)).value == 'true';
    final lastDrive = DateTime.tryParse(ref.watch(settingValueProvider(SettingKeys.lastDriveBackupAt)).value ?? '');
    final error = ref.watch(settingValueProvider(SettingKeys.driveLastError)).value;

    if (email == null) {
      return ListTile(
        leading: const Icon(Icons.add_to_drive_outlined),
        title: const Text(S.driveConnect),
        subtitle: const Text(S.driveConnectHint),
        onTap: () => connectDrive(context, ref),
      );
    }

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_done_outlined),
          title: const Text(S.googleDrive),
          subtitle: Text(S.driveConnectedAs(email)),
          trailing: TextButton(onPressed: () => disconnectDrive(context, ref), child: const Text(S.driveDisconnect)),
        ),
        if (error != null)
          ListTile(
            leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
            title: Text(error, style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => connectDrive(context, ref),
          ),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text(S.driveBackupNow),
          subtitle: Text(lastDrive == null ? S.driveNoBackupYet : S.driveLastBackup(formatDateTime(lastDrive))),
          onTap: () => backupToDriveNow(context, ref),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.autorenew),
          title: const Text(S.driveAutoBackup),
          subtitle: const Text(S.driveAutoBackupHint),
          value: auto,
          onChanged: (v) => ref.read(databaseProvider).settingsDao.setBool(SettingKeys.driveAutoBackup, v),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_download_outlined),
          title: const Text(S.driveRestore),
          subtitle: const Text(S.driveRestoreHint),
          onTap: () => restoreFromDrive(context, ref),
        ),
      ],
    );
  }
}

/// Hakkinda: uygulama surumu, sema surumu, kayit sayilari (PLAN 7.10).
class _About extends ConsumerWidget {
  const _About();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider).value;
    final counts = ref.watch(recordCountsProvider).value;
    final schema = ref.watch(databaseProvider).schemaVersion;
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: S.about),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info != null) Text(S.appVersion('${info.version}+${info.buildNumber}'), style: style),
                Text(S.schemaVersion(schema), style: style),
                if (counts != null)
                  Text(
                    S.recordCounts(counts.customers, counts.devices, counts.services, counts.appointments),
                    style: style,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sadece debug build'de: ornek veri olusturma ve tum veriyi silme (PLAN 7.10, 11).
class _DebugTools extends ConsumerStatefulWidget {
  const _DebugTools();

  @override
  ConsumerState<_DebugTools> createState() => _DebugToolsState();
}

class _DebugToolsState extends ConsumerState<_DebugTools> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String doneMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(doneMessage)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmWipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.debugWipeConfirmTitle),
        content: const Text(S.debugWipeConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(S.delete)),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => ref.read(databaseProvider).wipeAllData(), S.debugWipeDone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = ref.watch(recordCountsProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(S.debugSection, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error)),
        ),
        if (counts != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(S.recordCounts(counts.customers, counts.devices, counts.services, counts.appointments)),
          ),
        if (_busy) const LinearProgressIndicator(),
        ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.dataset_outlined),
          title: const Text(S.debugGenerateSample),
          subtitle: const Text(S.debugGenerateSampleHint),
          onTap: () => _run(
            () => SampleDataGenerator(ref.read(databaseProvider), seed: DateTime.now().millisecondsSinceEpoch)
                .generate(),
            S.debugSampleDone,
          ),
        ),
        ListTile(
          enabled: !_busy,
          leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
          title: const Text(S.debugWipeAll),
          subtitle: const Text(S.debugWipeAllHint),
          onTap: _confirmWipe,
        ),
      ],
    );
  }
}
