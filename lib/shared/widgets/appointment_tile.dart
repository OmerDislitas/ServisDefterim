import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/daos/appointments_dao.dart';
import '../../core/db/database.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../actions.dart';
import '../formatters.dart';

/// Randevu satiri: saat, musteri, bolge; Ara ve Servisi baslat kisayollari.
class AppointmentTile extends StatelessWidget {
  const AppointmentTile({super.key, required this.item, this.showDate = false});

  final AppointmentListItem item;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final area = areaText(item.district, item.neighborhood);
    final cancelled = item.status == AppointmentStatus.cancelled;
    final done = item.status == AppointmentStatus.done;
    final subtitle = [
      item.type.label,
      if (item.deviceBrand != null) deviceTitle(item.deviceBrand!, item.deviceModel),
      if (area.isNotEmpty) area,
      if (!item.status.isPlanned) item.status.label,
    ].join(' · ');

    return ListTile(
      onTap: () => context.push(Routes.appointment(item.id)),
      leading: CircleAvatar(
        backgroundColor: cancelled ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.primaryContainer,
        child: Text(
          formatTime(item.scheduledAt),
          style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(
        showDate ? '${formatDate(item.scheduledAt)} · ${item.customerName}' : item.customerName,
        style: cancelled ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
      ),
      subtitle: Text(subtitle),
      trailing: done || cancelled
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: S.call,
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => callPhone(context, item.customerPhone),
                ),
                IconButton(
                  tooltip: S.startServiceFromAppointment,
                  icon: const Icon(Icons.build_outlined),
                  onPressed: () => context.push(Routes.newServiceFor(appointmentId: item.id)),
                ),
              ],
            ),
    );
  }
}

extension on AppointmentStatus {
  bool get isPlanned => this == AppointmentStatus.planned;
}
