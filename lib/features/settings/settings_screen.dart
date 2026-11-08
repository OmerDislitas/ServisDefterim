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
import '../../shared/widgets/section_header.dart';

final _defaultIntervalProvider = StreamProvider.autoDispose<int>(
  (ref) => ref
      .watch(databaseProvider)
      .settingsDao
      .watchValue(SettingKeys.defaultIntervalMonths)
      .map((v) => int.tryParse(v ?? '') ?? 12),
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
    return Scaffold(
      appBar: AppBar(title: const Text(S.settings)),
      body: ListView(
        children: [
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
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text(S.otherSettingsLater),
          ),
          if (kDebugMode) const _DebugTools(),
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
