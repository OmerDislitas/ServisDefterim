import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/customers_dao.dart';
import '../../core/db/database.dart';
import '../../core/strings.dart';
import '../../core/utils/phone.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/status_badges.dart';
import '../customers/customers_providers.dart';

// Servis formunda musteri / adres / kombi secimi (PLAN 7.6, bolum 1-3).

/// Secimi tamamlanmis bolumun tek satirlik ozeti; dokununca degistirilir.
class SelectionSummary extends StatelessWidget {
  const SelectionSummary({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onChange,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onChange,
        leading: Icon(icon),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: trailing ?? const Text(S.change),
      ),
    );
  }
}

/// Musteri arama: bos iken son servis yapilan musteriler, yazinca arama sonuclari.
class CustomerSearch extends ConsumerStatefulWidget {
  const CustomerSearch({super.key, required this.onSelect, required this.onNew, this.errorText});

  final ValueChanged<String> onSelect;
  final VoidCallback onNew;
  final String? errorText;

  @override
  ConsumerState<CustomerSearch> createState() => _CustomerSearchState();
}

class _CustomerSearchState extends ConsumerState<CustomerSearch> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<CustomerListItem>? _last;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(customerListProvider((query: _query, sort: CustomerSort.lastService)));
    if (async.hasValue) _last = async.value;
    final items = (async.value ?? _last ?? const []).take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: S.searchCustomerHint,
            prefixIcon: const Icon(Icons.search),
            errorText: widget.errorText,
          ),
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 150), () {
              if (mounted) setState(() => _query = v.trim());
            });
          },
        ),
        for (final c in items)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(Icons.person_outline),
            title: Text(c.name),
            subtitle: Text(
              [formatPhone(c.phone), areaText(c.district, c.neighborhood)].where((s) => s.isNotEmpty).join(' · '),
            ),
            onTap: () => widget.onSelect(c.id),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onNew,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text(S.addNewCustomer),
          ),
        ),
      ],
    );
  }
}

/// Musterinin adreslerinden secim.
class AddressPicker extends ConsumerWidget {
  const AddressPicker({
    super.key,
    required this.customerId,
    required this.onSelect,
    required this.onNew,
    this.errorText,
  });

  final String customerId;
  final ValueChanged<Address> onSelect;
  final VoidCallback onNew;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider(customerId)).value ?? const <Address>[];
    return _PickerCard(
      title: S.selectAddress,
      errorText: errorText,
      newLabel: S.addNewAddress,
      onNew: onNew,
      children: [
        for (final a in addresses)
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(addressTitle(a)),
            subtitle: Text(addressDetail(a)),
            onTap: () => onSelect(a),
          ),
      ],
    );
  }
}

/// Adresteki kombilerden secim.
class DevicePicker extends ConsumerWidget {
  const DevicePicker({
    super.key,
    required this.addressId,
    required this.onSelect,
    required this.onNew,
    this.errorText,
  });

  final String addressId;
  final ValueChanged<Device> onSelect;
  final VoidCallback onNew;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesForAddressProvider(addressId)).value ?? const <Device>[];
    return _PickerCard(
      title: S.selectDevice,
      errorText: errorText,
      newLabel: S.addNewDevice,
      onNew: onNew,
      children: [
        for (final d in devices)
          ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: Text(deviceTitle(d.brand, d.model)),
            subtitle: Text(d.type.label),
            trailing: MaintenanceBadge(nextDate: d.nextMaintenanceDate),
            onTap: () => onSelect(d),
          ),
      ],
    );
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.title,
    required this.children,
    required this.newLabel,
    required this.onNew,
    this.errorText,
  });

  final String title;
  final List<Widget> children;
  final String newLabel;
  final VoidCallback onNew;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: errorText == null
          ? null
          : RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.error),
              borderRadius: BorderRadius.circular(12),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              errorText ?? title,
              style: theme.textTheme.labelLarge?.copyWith(color: errorText == null ? null : theme.colorScheme.error),
            ),
          ),
          ...children,
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: TextButton.icon(onPressed: onNew, icon: const Icon(Icons.add), label: Text(newLabel)),
            ),
          ),
        ],
      ),
    );
  }
}
