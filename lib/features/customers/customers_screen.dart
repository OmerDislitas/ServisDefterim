import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/daos/customers_dao.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../core/utils/phone.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/new_service_fab.dart';
import 'customers_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  CustomerSort _sort = CustomerSort.lastService;

  /// Yeni sorgu yuklenirken liste bosalip titremesin diye son sonuc.
  List<CustomerListItem>? _lastItems;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(customerListProvider((query: _query, sort: _sort)));
    if (async.hasValue) _lastItems = async.value;
    final items = async.value ?? _lastItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.tabCustomers),
        actions: [
          PopupMenuButton<CustomerSort>(
            tooltip: S.sort,
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => const [
              PopupMenuItem(value: CustomerSort.lastService, child: Text(S.sortByLastService)),
              PopupMenuItem(value: CustomerSort.name, child: Text(S.sortByName)),
            ],
          ),
          IconButton(
            tooltip: S.newCustomer,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => context.push(Routes.customerNew),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: S.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ListenableBuilder(
                  listenable: _search,
                  builder: (context, _) => _search.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch),
                ),
              ),
            ),
          ),
          Expanded(child: _buildList(items)),
        ],
      ),
      floatingActionButton: const NewServiceFab(),
    );
  }

  Widget _buildList(List<CustomerListItem>? items) {
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      if (_query.isNotEmpty) {
        return const EmptyState(icon: Icons.search_off, message: S.noSearchResults);
      }
      return EmptyState(
        icon: Icons.people_outline,
        message: S.customersEmpty,
        action: FilledButton.icon(
          onPressed: () => context.push(Routes.customerNew),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text(S.newCustomer),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: items.length,
      itemBuilder: (context, i) => _CustomerTile(item: items[i]),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.item});

  final CustomerListItem item;

  @override
  Widget build(BuildContext context) {
    final area = areaText(item.district, item.neighborhood);
    return ListTile(
      onTap: () => context.push(Routes.customer(item.id)),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [formatPhone(item.phone), if (area.isNotEmpty) area].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: item.deviceCount == 0
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_outlined, size: 20),
                const SizedBox(width: 2),
                Text('${item.deviceCount}'),
              ],
            ),
    );
  }
}
