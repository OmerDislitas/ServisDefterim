import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/status_badges.dart';
import '../services/payment_dialog.dart';
import 'receivables_providers.dart';

/// Musterinin borclu servisleri; her biri icin kalan tutar ve "Odeme al" (PLAN 7.9).
class DebtServicesList extends ConsumerWidget {
  const DebtServicesList({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final items = ref.watch(debtServicesProvider(customerId)).value;
    if (items == null) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    }
    return Column(
      children: [
        for (final s in items)
          ListTile(
            onTap: () => context.push(Routes.service(s.id)),
            title: Text('${formatDate(s.date)} · ${s.type.label}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deviceTitle(s.deviceBrand, s.deviceModel)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    PaymentBadge(total: s.totalAmount, paid: s.paidAmount),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${S.total}: ${formatMoney(s.totalAmount)}',
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(s.remaining),
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error),
                ),
                SizedBox(
                  height: 36,
                  child: TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(48, 36)),
                    onPressed: () => showPaymentDialog(context, ref, serviceId: s.id, remaining: s.remaining),
                    child: const Text(S.takePayment),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Musteri detayindan: borclu servisleri alt sayfada gosterir.
Future<void> showDebtServicesSheet(BuildContext context, String customerId) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(S.debtServices, style: Theme.of(context).textTheme.titleMedium),
            ),
            DebtServicesList(customerId: customerId),
          ],
        ),
      ),
    );
