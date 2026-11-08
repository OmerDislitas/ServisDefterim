import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/daos/devices_dao.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../actions.dart';
import '../formatters.dart';
import '../reminder.dart';
import 'status_badges.dart';

/// Bakimi gelen kombi satiri + hizli aksiyonlar: Ara, WhatsApp hatirlat,
/// Randevu olustur, Servis baslat (PLAN 7.1).
class DueDeviceTile extends ConsumerWidget {
  const DueDeviceTile({super.key, required this.item});

  final DueDeviceItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final d = item.device;
    final area = areaText(item.address.district, item.address.neighborhood);
    final reminded = d.lastReminderSentAt;

    return InkWell(
      onTap: () => context.push(Routes.device(d.id)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.customer.name, style: theme.textTheme.titleMedium),
                      Text(
                        [deviceTitle(d.brand, d.model), if (area.isNotEmpty) area].join(' · '),
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        [
                          d.nextMaintenanceDate == null ? S.unknownDate : formatDate(d.nextMaintenanceDate!),
                          if (reminded != null) S.remindedAgo(relativeDay(reminded)),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                MaintenanceBadge(nextDate: d.nextMaintenanceDate),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: S.call,
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => callPhone(context, item.customer.phone),
                ),
                IconButton(
                  tooltip: S.remindWhatsapp,
                  icon: const Icon(Icons.chat_outlined),
                  onPressed: () => sendMaintenanceReminder(context, ref, item),
                ),
                IconButton(
                  tooltip: S.createAppointment,
                  icon: const Icon(Icons.event_outlined),
                  onPressed: () =>
                      context.push(Routes.appointmentNew(customerId: item.customer.id, deviceId: d.id)),
                ),
                IconButton(
                  tooltip: S.startService,
                  icon: const Icon(Icons.build_outlined),
                  onPressed: () => context.push(Routes.newServiceFor(deviceId: d.id)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
