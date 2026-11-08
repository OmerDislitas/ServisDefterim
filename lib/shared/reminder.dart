import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/daos/devices_dao.dart';
import '../core/db/daos/settings_dao.dart';
import '../core/db/db_providers.dart';
import '../core/strings.dart';
import '../core/utils/dates.dart';
import '../core/utils/phone.dart';
import 'actions.dart';

/// WhatsApp bakim hatirlatmasi (PLAN 6.5): sablonu doldurur, WhatsApp'i acar,
/// acilabildiyse kombinin `lastReminderSentAt` alanini gunceller.
Future<void> sendMaintenanceReminder(BuildContext context, WidgetRef ref, DueDeviceItem item) async {
  final db = ref.read(databaseProvider);
  final template = await db.settingsDao.getValue(SettingKeys.whatsappTemplate) ?? S.defaultWhatsappTemplate;
  final next = item.device.nextMaintenanceDate;
  final message = fillWhatsappTemplate(
    template,
    name: item.customer.name,
    brand: item.device.brand,
    date: next == null ? null : formatDate(next),
  );
  if (!context.mounted) return;
  final ok = await openWhatsapp(context, item.customer.phone, message: message);
  if (ok) await db.devicesDao.markReminderSent(item.device.id);
}
