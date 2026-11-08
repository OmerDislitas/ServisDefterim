import 'package:intl/intl.dart';

import '../router/app_router.dart';
import '../strings.dart';
import 'maintenance.dart';

/// Bildirim planlamasi (PLAN 9). Saf hesap: veritabani ve eklentiden bagimsiz, test edilir.

enum NotificationKind { maintenance, appointment }

/// Kullanicinin bildirim tercihleri.
class NotificationPrefs {
  const NotificationPrefs({
    this.enabled = true,
    this.maintenance = true,
    this.appointment = true,
    this.hour = 9,
    this.daysBefore = 3,
  });

  final bool enabled;
  final bool maintenance;
  final bool appointment;
  final int hour;
  final int daysBefore;
}

/// Bakimi yaklasan bir kombi.
class MaintenanceReminderInput {
  const MaintenanceReminderInput({
    required this.deviceId,
    required this.customerName,
    required this.brand,
    required this.dueDate,
  });

  final String deviceId;
  final String customerName;
  final String brand;
  final DateTime dueDate;
}

/// Planlanmis (durumu "planlandi") bir randevu.
class AppointmentReminderInput {
  const AppointmentReminderInput({
    required this.id,
    required this.scheduledAt,
    required this.customerName,
    required this.typeLabel,
    this.place,
  });

  final String id;
  final DateTime scheduledAt;
  final String customerName;
  final String typeLabel;
  final String? place;
}

class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final NotificationKind kind;
  final DateTime at;
  final String title;
  final String body;

  /// Bildirime dokununca acilacak rota.
  final String payload;

  @override
  String toString() => 'PlannedNotification($id, $kind, $at, $title, $body, $payload)';
}

/// Onumuzdeki [horizonDays] gun icin bildirimleri hesaplar; en yakin [max] tanesi doner.
/// - Bakim: bakim tarihinden `daysBefore` gun once, `hour` saatinde. Ayni gune dusenler tek bildirimde.
/// - Randevu: randevudan 1 saat once.
/// Zamani gecmis bildirimler planlanmaz (Bugun ekrani zaten gosterir).
List<PlannedNotification> planNotifications({
  required DateTime now,
  required NotificationPrefs prefs,
  List<MaintenanceReminderInput> devices = const [],
  List<AppointmentReminderInput> appointments = const [],
  int horizonDays = 60,
  int max = 100,
}) {
  if (!prefs.enabled) return const [];
  final horizon = now.add(Duration(days: horizonDays));
  bool inWindow(DateTime t) => t.isAfter(now) && !t.isAfter(horizon);

  final drafts = <({NotificationKind kind, DateTime at, String title, String body, String payload})>[];

  if (prefs.maintenance) {
    final byDay = <DateTime, List<MaintenanceReminderInput>>{};
    for (final d in devices) {
      final due = DateTime(d.dueDate.year, d.dueDate.month, d.dueDate.day);
      byDay.putIfAbsent(due, () => []).add(d);
    }
    for (final MapEntry(key: due, value: items) in byDay.entries) {
      final at = DateTime(due.year, due.month, due.day - prefs.daysBefore, prefs.hour);
      if (!inWindow(at)) continue;
      final when = S.maintenanceWhen(prefs.daysBefore, DateFormat('d MMMM', 'tr_TR').format(due));
      if (items.length == 1) {
        final d = items.single;
        drafts.add((
          kind: NotificationKind.maintenance,
          at: at,
          title: S.maintenanceReminderTitle,
          body: S.maintenanceSingle(d.customerName, d.brand, when),
          payload: Routes.device(d.deviceId),
        ));
      } else {
        final names = <String>{for (final d in items) d.customerName}.toList();
        final shown = names.take(3).join(', ') + (names.length > 3 ? '…' : '');
        drafts.add((
          kind: NotificationKind.maintenance,
          at: at,
          title: S.maintenanceGroupTitle(items.length),
          body: S.maintenanceGroup(when, items.length, shown),
          payload: Routes.dueMaintenance(DueFilter.upcoming),
        ));
      }
    }
  }

  if (prefs.appointment) {
    for (final a in appointments) {
      final at = a.scheduledAt.subtract(const Duration(hours: 1));
      if (!inWindow(at)) continue;
      drafts.add((
        kind: NotificationKind.appointment,
        at: at,
        title: S.appointmentReminderTitle(DateFormat('HH:mm', 'tr_TR').format(a.scheduledAt)),
        body: [a.customerName, if (a.place != null) a.place!, a.typeLabel].join(' · '),
        payload: Routes.appointment(a.id),
      ));
    }
  }

  drafts.sort((a, b) => a.at.compareTo(b.at));
  return [
    for (final (i, d) in drafts.take(max).indexed)
      PlannedNotification(id: i + 1, kind: d.kind, at: d.at, title: d.title, body: d.body, payload: d.payload),
  ];
}
