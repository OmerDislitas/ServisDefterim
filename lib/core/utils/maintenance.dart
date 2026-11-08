/// Periyodik bakim kurallari (PLAN 6.1, 6.2).
library;

import '../strings.dart';
import 'dates.dart';

enum MaintenanceStatus {
  overdue,
  thisWeek,
  upcoming,
  later,
  unknown;

  String get label => switch (this) {
        overdue => S.maintOverdue,
        thisWeek => S.maintThisWeek,
        upcoming => S.maintUpcoming,
        later => S.maintLater,
        unknown => S.maintUnknown,
      };
}

/// Gecikmis: tarih < bugun. Bu hafta: 7 gun icinde. Yaklasan: 30 gun icinde.
MaintenanceStatus maintenanceStatus(DateTime? next, DateTime today) {
  if (next == null) return MaintenanceStatus.unknown;
  final d = daysBetween(today, next);
  if (d < 0) return MaintenanceStatus.overdue;
  if (d <= 7) return MaintenanceStatus.thisWeek;
  if (d <= 30) return MaintenanceStatus.upcoming;
  return MaintenanceStatus.later;
}

/// Periyodik bakim servisinden sonra onerilen sonraki bakim tarihi.
DateTime computeNextMaintenance(DateTime serviceDate, int intervalMonths) =>
    addMonths(dateOnly(serviceDate), intervalMonths);

/// Bakimi Gelenler listesi filtreleri.
enum DueFilter { overdue, thisWeek, upcoming, thisMonth, nextMonth, unknown }

/// Filtrenin `yyyy-MM-dd` araligi (iki uc dahil). [DueFilter.unknown] icin ikisi de null.
({String? from, String? to}) dueRange(DueFilter filter, DateTime today) {
  final t = dateOnly(today);
  return switch (filter) {
    DueFilter.overdue => (from: null, to: toDateKey(addDays(t, -1))),
    DueFilter.thisWeek => (from: toDateKey(t), to: toDateKey(addDays(t, 7))),
    DueFilter.upcoming => (from: toDateKey(t), to: toDateKey(addDays(t, 30))),
    DueFilter.thisMonth => (from: toDateKey(t), to: toDateKey(DateTime(t.year, t.month + 1, 0))),
    DueFilter.nextMonth => (
        from: toDateKey(DateTime(t.year, t.month + 1, 1)),
        to: toDateKey(DateTime(t.year, t.month + 2, 0)),
      ),
    DueFilter.unknown => (from: null, to: null),
  };
}
