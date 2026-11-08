import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/maintenance.dart';
import '../../core/utils/money.dart';
import '../../shared/actions.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_badges.dart';
import '../customers/customers_providers.dart';
import '../devices/devices_providers.dart';
import 'payment_dialog.dart';
import 'services_providers.dart';

/// Servis detayi (PLAN 7.7): tum bilgiler, odeme gecmisi, kalan alacak, "Odeme al".
class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceProvider(serviceId));
    return async.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.error_outline, message: S.loadFailed)),
      data: (s) => s == null
          ? Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, message: S.recordNotFound))
          : _ServiceDetail(service: s),
    );
  }
}

class _ServiceDetail extends ConsumerWidget {
  const _ServiceDetail({required this.service});

  final ServiceRecord service;

  /// Silme onayi; periyodik bakimsa onceki bakima gore sonraki tarihi guncellemeyi teklif eder.
  Future<void> _delete(BuildContext context, WidgetRef ref, Device? device) async {
    final db = ref.read(databaseProvider);
    DateTime? suggested;
    if (service.isPeriodicMaintenance && device != null) {
      final previous = await db.servicesDao.latestPeriodicServiceDate(device.id, excludeId: service.id);
      if (previous != null) suggested = computeNextMaintenance(previous, device.maintenanceIntervalMonths);
    }
    if (!context.mounted) return;

    var updateNext = suggested != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text(S.deleteServiceTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(S.deleteServiceBody),
              if (suggested != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: updateNext,
                  onChanged: (v) => setState(() => updateNext = v ?? false),
                  title: Text(S.updateNextMaintenanceTo(formatDate(suggested))),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(S.delete),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    final previousNext = device?.nextMaintenanceDate;
    final deletedAt = await db.softDelete(EntityKind.service, service.id);
    if (updateNext && device != null) await db.devicesDao.setNextMaintenanceDate(device.id, suggested);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text(S.serviceDeleted),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: S.undo,
          onPressed: () async {
            await db.restore(EntityKind.service, service.id, deletedAt);
            if (updateNext && device != null) await db.devicesDao.setNextMaintenanceDate(device.id, previousNext);
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final device = ref.watch(deviceProvider(service.deviceId)).value;
    final address = device == null ? null : ref.watch(addressProvider(device.addressId)).value;
    final customer = address == null ? null : ref.watch(customerProvider(address.customerId)).value;
    final parts = ref.watch(servicePartsProvider(service.id)).value ?? const <ServicePart>[];
    final payments = ref.watch(servicePaymentsProvider(service.id)).value ?? const <Payment>[];
    final paid = payments.fold<int>(0, (s, p) => s + p.amount);
    final remaining = service.totalAmount - paid;

    return Scaffold(
      appBar: AppBar(
        title: Text(service.type.label),
        actions: [
          IconButton(
            tooltip: S.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.serviceEdit(service.id)),
          ),
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              PopupMenuItem(onTap: () => _delete(context, ref, device), child: const Text(S.delete)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(formatDateLong(service.date), style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(formatTime(service.date)),
          ),

          // Musteri ve kombi
          if (customer != null && device != null && address != null)
            ListTile(
              onTap: () => context.push(Routes.device(device.id)),
              leading: const Icon(Icons.local_fire_department_outlined),
              title: Text('${customer.name} · ${deviceTitle(device.brand, device.model)}'),
              subtitle: Text(addressTitle(address)),
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

          // Ucret ve odeme
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(S.total, style: theme.textTheme.titleMedium)),
                      Text(formatMoney(service.totalAmount), style: theme.textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _AmountRow(label: S.paid, amount: paid),
                  if (remaining > 0) _AmountRow(label: S.remaining, amount: remaining, highlight: true),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PaymentBadge(total: service.totalAmount, paid: paid),
                  ),
                  if (remaining > 0) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => showPaymentDialog(context, ref, serviceId: service.id, remaining: remaining),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text(S.takePayment),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Odeme gecmisi
          const SectionHeader(title: S.payments),
          if (payments.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text(S.noPayments)),
          for (final p in payments)
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(formatMoney(p.amount)),
              subtitle: Text([formatDateTime(p.date), ?p.note].join(' · ')),
              trailing: IconButton(
                tooltip: S.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => confirmAndDelete(
                  context: context,
                  ref: ref,
                  kind: EntityKind.payment,
                  id: p.id,
                  title: S.deletePaymentTitle,
                  body: S.deletePaymentBody,
                  doneMessage: S.paymentDeleted,
                ),
              ),
            ),

          // Ariza bilgisi
          if (service.complaint != null || service.errorCode != null) ...[
            const SectionHeader(title: S.serviceInfo),
            if (service.complaint != null) _InfoRow(label: S.complaint, value: service.complaint!),
            if (service.errorCode != null) _InfoRow(label: S.errorCode, value: service.errorCode!),
          ],

          // Checklist
          if (service.checklistItems.isNotEmpty) ...[
            const SectionHeader(title: S.checklist),
            for (final item in service.checklistItems)
              ListTile(
                dense: true,
                leading: Icon(Icons.check, color: theme.colorScheme.primary),
                title: Text(item),
              ),
          ],

          // Olcumler
          if (service.waterPressureBar != null || service.expansionTankBar != null || service.flueCoPpm != null) ...[
            const SectionHeader(title: S.measurements),
            if (service.waterPressureBar != null)
              _InfoRow(label: S.waterPressure, value: _num(service.waterPressureBar!)),
            if (service.expansionTankBar != null)
              _InfoRow(label: S.expansionTank, value: _num(service.expansionTankBar!)),
            if (service.flueCoPpm != null) _InfoRow(label: S.flueCo, value: '${service.flueCoPpm}'),
          ],

          if (service.workNotes != null) ...[
            const SectionHeader(title: S.workNotes),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(service.workNotes!, style: theme.textTheme.bodyLarge),
            ),
          ],

          // Parcalar ve iscilik
          if (parts.isNotEmpty || service.laborFee > 0) ...[
            const SectionHeader(title: S.parts),
            for (final p in parts)
              ListTile(
                dense: true,
                title: Text(p.name),
                subtitle: Text('${p.quantity} × ${formatMoney(p.unitPrice)}'),
                trailing: Text(formatMoney(p.quantity * p.unitPrice)),
              ),
            ListTile(
              dense: true,
              title: const Text(S.laborFee),
              trailing: Text(formatMoney(service.laborFee)),
            ),
          ],
        ],
      ),
    );
  }

  static String _num(double v) => v.toString().replaceAll('.', ',');
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.amount, this.highlight = false});

  final String label;
  final int amount;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = highlight
        ? theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w600)
        : theme.textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(formatMoney(amount), style: style),
        ],
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
            width: 150,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
