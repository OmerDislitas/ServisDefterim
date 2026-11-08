import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/devices_dao.dart';
import '../../core/db/db_providers.dart';
import '../../core/strings.dart';
import '../../core/utils/maintenance.dart';
import '../../shared/widgets/due_device_tile.dart';
import '../../shared/widgets/empty_state.dart';

final dueDevicesProvider = StreamProvider.autoDispose.family<List<DueDeviceItem>, DueFilter>(
  (ref, filter) => ref.watch(databaseProvider).devicesDao.watchDueDevices(filter),
);

extension DueFilterLabel on DueFilter {
  String get label => switch (this) {
        DueFilter.overdue => S.filterOverdue,
        DueFilter.thisWeek => S.filterThisWeek,
        DueFilter.upcoming => S.maintUpcoming,
        DueFilter.thisMonth => S.filterThisMonth,
        DueFilter.nextMonth => S.filterNextMonth,
        DueFilter.unknown => S.filterUnknown,
      };
}

/// Bakimi Gelenler (PLAN 7.1): Gecikmis / Bu hafta / Bu ay / Gelecek ay / Tarihi bilinmeyen.
class DueMaintenanceScreen extends ConsumerStatefulWidget {
  const DueMaintenanceScreen({super.key, this.initialFilter = DueFilter.overdue});

  final DueFilter initialFilter;

  @override
  ConsumerState<DueMaintenanceScreen> createState() => _DueMaintenanceScreenState();
}

class _DueMaintenanceScreenState extends ConsumerState<DueMaintenanceScreen> {
  static const _filters = [
    DueFilter.overdue,
    DueFilter.thisWeek,
    DueFilter.thisMonth,
    DueFilter.nextMonth,
    DueFilter.unknown,
  ];

  late DueFilter _filter = widget.initialFilter;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dueDevicesProvider(_filter));
    final items = async.value;

    return Scaffold(
      appBar: AppBar(title: const Text(S.dueMaintenance)),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items == null
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? const EmptyState(icon: Icons.event_available_outlined, message: S.noDueDevices)
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) => DueDeviceTile(item: items[i]),
                      ),
          ),
        ],
      ),
    );
  }
}
