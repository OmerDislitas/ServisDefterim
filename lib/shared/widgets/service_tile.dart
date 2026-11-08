import 'package:flutter/material.dart';

import '../../core/db/daos/services_dao.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../formatters.dart';
import 'status_badges.dart';

/// Servis listesi satiri: tarih, tur, kombi/musteri, tutar ve odeme durumu.
class ServiceTile extends StatelessWidget {
  const ServiceTile({super.key, required this.item, this.showCustomer = false, this.showDevice = true, this.onTap});

  final ServiceListItem item;
  final bool showCustomer;
  final bool showDevice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      item.type.label,
      if (showDevice) deviceTitle(item.deviceBrand, item.deviceModel),
      if (showCustomer) item.customerName,
    ].join(' · ');
    return ListTile(
      onTap: onTap,
      leading: const Icon(Icons.build_circle_outlined),
      title: Text(formatDate(item.date)),
      subtitle: Text(subtitle),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatMoney(item.totalAmount)),
          const SizedBox(height: 4),
          PaymentBadge(total: item.totalAmount, paid: item.paidAmount),
        ],
      ),
    );
  }
}
