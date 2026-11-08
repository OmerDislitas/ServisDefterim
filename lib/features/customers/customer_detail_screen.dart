import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/utils/phone.dart';
import '../../shared/actions.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/service_tile.dart';
import '../../shared/widgets/status_badges.dart';
import '../receivables/debt_services_list.dart';
import 'customers_providers.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerProvider(customerId));
    return async.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.error_outline, message: S.loadFailed)),
      data: (customer) => customer == null
          ? Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.person_off_outlined, message: S.recordNotFound))
          : _CustomerDetail(customer: customer),
    );
  }
}

class _CustomerDetail extends ConsumerWidget {
  const _CustomerDetail({required this.customer});

  final Customer customer;

  void _delete(BuildContext context, WidgetRef ref) => confirmAndDelete(
        context: context,
        ref: ref,
        kind: EntityKind.customer,
        id: customer.id,
        title: S.deleteCustomerTitle(customer.name),
        body: S.deleteCustomerBody,
        doneMessage: S.customerDeleted,
        popAfter: true,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final addresses = ref.watch(addressesProvider(customer.id)).value ?? const <Address>[];
    final services = ref.watch(customerServicesProvider(customer.id)).value;
    final debt = ref.watch(customerDebtProvider(customer.id)).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            tooltip: S.createAppointment,
            icon: const Icon(Icons.event_outlined),
            onPressed: () => context.push(Routes.appointmentNew(customerId: customer.id)),
          ),
          IconButton(
            tooltip: S.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.customerEdit(customer.id)),
          ),
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              PopupMenuItem(onTap: () => _delete(context, ref), child: const Text(S.delete)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Iletisim
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatPhone(customer.phone), style: theme.textTheme.titleLarge),
                if (customer.phone2 != null)
                  InkWell(
                    onTap: () => callPhone(context, customer.phone2!),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('${S.phone2}: ${formatPhone(customer.phone2!)}'),
                    ),
                  ),
                if (customer.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(customer.note!, style: theme.textTheme.bodyMedium),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => callPhone(context, customer.phone),
                        icon: const Icon(Icons.call),
                        label: const Text(S.call),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => openWhatsapp(context, customer.phone),
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text(S.whatsapp),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (debt > 0)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                onTap: () => showDebtServicesSheet(context, customer.id),
                leading: Icon(Icons.account_balance_wallet_outlined, color: theme.colorScheme.onErrorContainer),
                title: Text(
                  '${S.receivable}: ${formatMoney(debt)}',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
                ),
                trailing: Text(S.takePayment, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
              ),
            ),

          // Adresler ve kombiler
          SectionHeader(
            title: S.addresses,
            action: TextButton.icon(
              onPressed: () => context.push(Routes.addressNew(customer.id)),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text(S.addAddress),
            ),
          ),
          if (addresses.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text(S.noAddresses)),
          for (final a in addresses) _AddressCard(address: a),

          // Servis gecmisi
          const SectionHeader(title: S.serviceHistory),
          if (services != null && services.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text(S.noServices)),
          for (final s in services ?? const []) ServiceTile(item: s),
        ],
      ),
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.address});

  final Address address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final devices = ref.watch(devicesForAddressProvider(address.id)).value ?? const <Device>[];

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(addressTitle(address)),
            subtitle: Text([addressDetail(address), ?address.directions].join('\n')),
            trailing: PopupMenuButton<void>(
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () => context.push(Routes.addressEdit(address.id)),
                  child: const Text(S.edit),
                ),
                PopupMenuItem(
                  onTap: () => confirmAndDelete(
                    context: context,
                    ref: ref,
                    kind: EntityKind.address,
                    id: address.id,
                    title: S.deleteAddressTitle,
                    body: S.deleteAddressBody,
                    doneMessage: S.addressDeleted,
                  ),
                  child: const Text(S.delete),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(S.noDevicesAtAddress, style: theme.textTheme.bodyMedium),
            ),
          for (final d in devices)
            ListTile(
              onTap: () => context.push(Routes.device(d.id)),
              leading: const Icon(Icons.local_fire_department_outlined),
              title: Text(deviceTitle(d.brand, d.model)),
              subtitle: Text(
                '${d.type.label} · ${S.nextMaintenance}: '
                '${d.nextMaintenanceDate == null ? S.unknownDate : formatDate(d.nextMaintenanceDate!)}',
              ),
              trailing: MaintenanceBadge(nextDate: d.nextMaintenanceDate),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: TextButton.icon(
                onPressed: () => context.push(Routes.deviceNew(address.id)),
                icon: const Icon(Icons.add),
                label: const Text(S.addDevice),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
