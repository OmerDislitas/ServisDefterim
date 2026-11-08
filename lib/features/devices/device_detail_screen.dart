import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../../shared/actions.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/service_tile.dart';
import '../../shared/widgets/status_badges.dart';
import '../customers/customers_providers.dart';
import 'devices_providers.dart';
import '../photos/photo_strip.dart';

class DeviceDetailScreen extends ConsumerWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deviceProvider(deviceId));
    return async.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.error_outline, message: S.loadFailed)),
      data: (device) => device == null
          ? Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, message: S.recordNotFound))
          : _DeviceDetail(device: device),
    );
  }
}

class _DeviceDetail extends ConsumerWidget {
  const _DeviceDetail({required this.device});

  final Device device;

  Future<void> _changeNextDate(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: device.nextMaintenanceDate ?? today(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: S.nextMaintenance,
    );
    if (picked != null) {
      await ref.read(databaseProvider).devicesDao.setNextMaintenanceDate(device.id, dateOnly(picked));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final address = ref.watch(addressProvider(device.addressId)).value;
    final customer = address == null ? null : ref.watch(customerProvider(address.customerId)).value;
    final services = ref.watch(deviceServicesProvider(device.id)).value;
    final title = deviceTitle(device.brand, device.model);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: S.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.deviceEdit(device.id)),
          ),
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () => confirmAndDelete(
                  context: context,
                  ref: ref,
                  kind: EntityKind.device,
                  id: device.id,
                  title: S.deleteDeviceTitle,
                  body: S.deleteDeviceBody,
                  doneMessage: S.deviceDeleted,
                  popAfter: true,
                ),
                child: const Text(S.delete),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Musteri ve adres
          if (customer != null && address != null)
            ListTile(
              onTap: () => context.push(Routes.customer(customer.id)),
              leading: const Icon(Icons.person_outline),
              title: Text(customer.name),
              subtitle: Text('${addressTitle(address)}\n${addressDetail(address)}'),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: S.call,
                    icon: const Icon(Icons.call_outlined),
                    onPressed: () => callPhone(context, customer.phone),
                  ),
                  IconButton(
                    tooltip: S.whatsapp,
                    icon: const Icon(Icons.chat_outlined),
                    onPressed: () => openWhatsapp(context, customer.phone),
                  ),
                ],
              ),
            ),

          // Bakim karti
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(S.nextMaintenance, style: theme.textTheme.titleMedium)),
                      MaintenanceBadge(nextDate: device.nextMaintenanceDate),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    device.nextMaintenanceDate == null ? S.unknownDate : formatDateLong(device.nextMaintenanceDate!),
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(S.intervalMonths(device.maintenanceIntervalMonths)),
                  if (device.lastReminderSentAt != null)
                    Text(S.reminderSent(relativeDay(device.lastReminderSentAt!))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _changeNextDate(context, ref),
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text(S.changeDate),
                      ),
                      if (device.nextMaintenanceDate != null)
                        TextButton(
                          onPressed: () =>
                              ref.read(databaseProvider).devicesDao.setNextMaintenanceDate(device.id, null),
                          child: const Text(S.clearDate),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bilgiler
          const SectionHeader(title: S.device),
          _InfoRow(label: S.deviceType, value: device.type.label),
          if (device.serialNo != null) _InfoRow(label: S.serialNo, value: device.serialNo!),
          if (device.installYear != null) _InfoRow(label: S.installYear, value: '${device.installYear}'),
          if (device.warrantyEnd != null)
            _InfoRow(
              label: S.warrantyEnd,
              value: '${formatDate(device.warrantyEnd!)} · '
                  '${device.warrantyEnd!.isBefore(today()) ? S.warrantyExpired : S.warrantyActive}',
            ),
          if (device.note != null) _InfoRow(label: S.note, value: device.note!),

          PhotoStrip(ownerType: PhotoOwnerType.device, ownerId: device.id),

          // Servis gecmisi
          const SectionHeader(title: S.serviceHistory),
          if (services != null && services.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text(S.noServices)),
          for (final s in services ?? const []) ServiceTile(item: s, showDevice: false),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: () => context.push(Routes.newServiceFor(deviceId: device.id)),
            icon: const Icon(Icons.build_outlined),
            label: const Text(S.startService),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
