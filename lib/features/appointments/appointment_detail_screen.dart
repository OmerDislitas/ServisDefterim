import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/phone.dart';
import '../../shared/actions.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../customers/customers_providers.dart';
import '../devices/devices_providers.dart';
import 'appointments_providers.dart';

class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appointmentProvider(appointmentId));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.error_outline, message: S.loadFailed),
      ),
      data: (a) => a == null
          ? Scaffold(
              appBar: AppBar(),
              body: const EmptyState(icon: Icons.search_off, message: S.recordNotFound),
            )
          : _AppointmentDetail(appointment: a),
    );
  }
}

class _AppointmentDetail extends ConsumerWidget {
  const _AppointmentDetail({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final a = appointment;
    final customer = ref.watch(customerProvider(a.customerId)).value;
    final device = a.deviceId == null ? null : ref.watch(deviceProvider(a.deviceId!)).value;
    final addresses = ref.watch(addressesProvider(a.customerId)).value ?? const <Address>[];
    final address = device == null
        ? addresses.firstOrNull
        : addresses.where((x) => x.id == device.addressId).firstOrNull ?? addresses.firstOrNull;
    final service = ref.watch(serviceForAppointmentProvider(a.id)).value;
    final dao = ref.read(databaseProvider).appointmentsDao;

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.appointment),
        actions: [
          IconButton(
            tooltip: S.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.appointmentEdit(a.id)),
          ),
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () => confirmAndDelete(
                  context: context,
                  ref: ref,
                  kind: EntityKind.appointment,
                  id: a.id,
                  title: S.deleteAppointmentTitle,
                  body: S.deleteAppointmentBody,
                  doneMessage: S.appointmentDeleted,
                  popAfter: true,
                ),
                child: const Text(S.delete),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDateLong(a.scheduledAt), style: theme.textTheme.titleLarge),
                Text(formatTime(a.scheduledAt), style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(a.type.label)),
                    Chip(label: Text(a.status.label)),
                  ],
                ),
              ],
            ),
          ),
          if (customer != null)
            ListTile(
              onTap: () => context.push(Routes.customer(customer.id)),
              leading: const Icon(Icons.person_outline),
              title: Text(customer.name),
              subtitle: Text(formatPhone(customer.phone)),
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
          if (address != null)
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(addressTitle(address)),
              subtitle: Text([addressDetail(address), ?address.directions].join('\n')),
            ),
          if (device != null)
            ListTile(
              onTap: () => context.push(Routes.device(device.id)),
              leading: const Icon(Icons.local_fire_department_outlined),
              title: Text(deviceTitle(device.brand, device.model)),
              subtitle: Text(device.type.label),
            ),
          if (a.note != null) ListTile(leading: const Icon(Icons.notes), title: Text(a.note!)),
          if (service != null)
            ListTile(
              onTap: () => context.push(Routes.service(service.id)),
              leading: const Icon(Icons.build_circle_outlined),
              title: const Text(S.openServiceRecord),
              trailing: const Icon(Icons.chevron_right),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: switch (a.status) {
            // Iki buton genisligi paylasir; buyuk yazida metin alt satira gecer (tasma olmaz)
            AppointmentStatus.planned => IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () async {
                        await dao.setStatus(a.id, AppointmentStatus.cancelled);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text(S.appointmentCancelled)));
                        }
                      },
                      child: const Text(S.cancelAppointment, textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      onPressed: () => context.push(Routes.newServiceFor(appointmentId: a.id)),
                      icon: const Icon(Icons.build_outlined),
                      label: const Text(S.startServiceFromAppointment),
                    ),
                  ),
                ],
              ),
            ),
            AppointmentStatus.cancelled => FilledButton.tonal(
              onPressed: () => dao.setStatus(a.id, AppointmentStatus.planned),
              child: const Text(S.replanAppointment),
            ),
            AppointmentStatus.done => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}
