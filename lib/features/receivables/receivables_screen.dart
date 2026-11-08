import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/daos/services_dao.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../shared/actions.dart';
import '../../shared/widgets/empty_state.dart';
import 'debt_services_list.dart';
import 'receivables_providers.dart';

/// Alacaklar (PLAN 7.9): ustte toplam, musteri bazinda gruplu borclar.
/// Musteriye dokununca borclu servisleri acilir, her biri icin "Odeme al".
class ReceivablesScreen extends ConsumerStatefulWidget {
  const ReceivablesScreen({super.key});

  @override
  ConsumerState<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends ConsumerState<ReceivablesScreen> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(receivablesProvider).value;
    final total = ref.watch(totalReceivableProvider).value ?? 0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(S.tabReceivables)),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const EmptyState(icon: Icons.account_balance_wallet_outlined, message: S.noReceivables)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: items.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Card(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        color: theme.colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          // Buyuk yazida tutar alt satira gecer (tasma olmaz)
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 16,
                            children: [
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      S.totalReceivable,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(color: theme.colorScheme.onErrorContainer),
                                    ),
                                    Text(
                                      S.receivableCustomers(items.length),
                                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                                    ),
                                  ],
                                ),
                              Text(
                                formatMoney(total),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final item = items[i - 1];
                    final expanded = _expanded.contains(item.customerId);
                    return _CustomerDebtCard(
                      item: item,
                      expanded: expanded,
                      onToggle: () => setState(() {
                        expanded ? _expanded.remove(item.customerId) : _expanded.add(item.customerId);
                      }),
                    );
                  },
                ),
    );
  }
}

class _CustomerDebtCard extends StatelessWidget {
  const _CustomerDebtCard({required this.item, required this.expanded, required this.onToggle});

  final ReceivableCustomer item;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: theme.textTheme.titleMedium),
                        Text(
                          formatMoney(item.debt),
                          style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error),
                        ),
                        Text(
                          S.oldestDebt(formatDate(item.oldestDebtAt), relativeDay(item.oldestDebtAt)),
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(S.debtServiceCount(item.serviceCount), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: S.call,
                    icon: const Icon(Icons.call_outlined),
                    onPressed: () => callPhone(context, item.phone),
                  ),
                  IconButton(
                    tooltip: S.whatsapp,
                    icon: const Icon(Icons.chat_outlined),
                    onPressed: () => openWhatsapp(context, item.phone),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            DebtServicesList(customerId: item.customerId),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push(Routes.customer(item.customerId)),
                icon: const Icon(Icons.person_outline),
                label: const Text(S.goToCustomer),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
