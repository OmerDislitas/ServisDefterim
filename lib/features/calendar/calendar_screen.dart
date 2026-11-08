import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart' hide isSameDay;

import '../../core/db/daos/appointments_dao.dart';
import '../../core/db/daos/devices_dao.dart';
import '../../core/db/daos/services_dao.dart';
import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../../shared/widgets/appointment_tile.dart';
import '../../shared/widgets/due_device_tile.dart';
import '../../shared/widgets/new_service_fab.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/service_tile.dart';
import '../appointments/appointments_providers.dart';

typedef _Range = ({DateTime from, DateTime to});

final _maintenanceInRangeProvider = StreamProvider.autoDispose.family<List<DueDeviceItem>, _Range>(
  (ref, r) => ref
      .watch(databaseProvider)
      .devicesDao
      .watchDueDevicesInRange(from: toDateKey(r.from), to: toDateKey(addDays(r.to, -1))),
);

final _servicesInRangeProvider = StreamProvider.autoDispose.family<List<ServiceListItem>, _Range>(
  (ref, r) => ref.watch(databaseProvider).servicesDao.watchServiceList(from: r.from, to: r.to),
);

enum _Marker { maintenance, overdue, appointment, service }

const _markerColors = {
  _Marker.maintenance: Color(0xFFF57C00),
  _Marker.overdue: Color(0xFFD32F2F),
  _Marker.appointment: Color(0xFF1976D2),
  _Marker.service: Color(0xFF388E3C),
};

String _markerLabel(_Marker m) => switch (m) {
      _Marker.maintenance => S.legendMaintenance,
      _Marker.overdue => S.legendOverdue,
      _Marker.appointment => S.legendAppointment,
      _Marker.service => S.legendService,
    };

/// Takvim (PLAN 7.2): aylik/haftalik gorunum, hafta pazartesi baslar.
/// Turuncu = bakim zamani, kirmizi = gecikmis, mavi = randevu, yesil = yapilmis servis.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focused = today();
  DateTime _selected = today();
  CalendarFormat _format = CalendarFormat.month;

  /// Odaklanan ayin gorunen haftalarini da kapsayan aralik [from, to).
  _Range get _range {
    final first = DateTime(_focused.year, _focused.month, 1);
    return (from: addDays(first, -7), to: addDays(DateTime(_focused.year, _focused.month + 1, 1), 7));
  }

  static String _key(DateTime d) => toDateKey(d);

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final maintenance = ref.watch(_maintenanceInRangeProvider(range)).value ?? const <DueDeviceItem>[];
    final appointments = ref.watch(appointmentsInRangeProvider(range)).value ?? const <AppointmentListItem>[];
    final services = ref.watch(_servicesInRangeProvider(range)).value ?? const <ServiceListItem>[];
    final todayDate = today();

    // Gun bazinda grupla
    final dueByDay = <String, List<DueDeviceItem>>{};
    for (final m in maintenance) {
      dueByDay.putIfAbsent(_key(m.device.nextMaintenanceDate!), () => []).add(m);
    }
    final apptByDay = <String, List<AppointmentListItem>>{};
    for (final a in appointments) {
      apptByDay.putIfAbsent(_key(a.scheduledAt), () => []).add(a);
    }
    final svcByDay = <String, List<ServiceListItem>>{};
    for (final s in services) {
      svcByDay.putIfAbsent(_key(s.date), () => []).add(s);
    }

    List<_Marker> markersFor(DateTime day) {
      final k = _key(day);
      return [
        if (dueByDay.containsKey(k)) day.isBefore(todayDate) ? _Marker.overdue : _Marker.maintenance,
        if (apptByDay[k]?.any((a) => a.status != AppointmentStatus.cancelled) ?? false) _Marker.appointment,
        if (svcByDay.containsKey(k)) _Marker.service,
      ];
    }

    final selKey = _key(_selected);
    final dayAppointments = apptByDay[selKey] ?? const [];
    final dayDue = dueByDay[selKey] ?? const [];
    final dayServices = svcByDay[selKey] ?? const [];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(S.tabCalendar)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          TableCalendar<_Marker>(
            locale: 'tr_TR',
            firstDay: DateTime(2015),
            lastDay: DateTime(2100),
            focusedDay: _focused,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarFormat: _format,
            availableCalendarFormats: const {CalendarFormat.month: S.formatMonth, CalendarFormat.week: S.formatWeek},
            headerStyle: const HeaderStyle(formatButtonShowsNext: false, titleCentered: true),
            selectedDayPredicate: (d) => isSameDay(d, _selected),
            eventLoader: markersFor,
            onDaySelected: (selected, focused) => setState(() {
              _selected = dateOnly(selected);
              _focused = dateOnly(focused);
            }),
            onFormatChanged: (f) => setState(() => _format = f),
            onPageChanged: (focused) => setState(() => _focused = dateOnly(focused)),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
              todayTextStyle: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              selectedDecoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, markers) => markers.isEmpty
                  ? null
                  : Positioned(
                      bottom: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final m in markers)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(color: _markerColors[m], shape: BoxShape.circle),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          // Renk aciklamasi
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final m in _Marker.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: _markerColors[m], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(_markerLabel(m), style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 24),

          // Secilen gun
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Text(formatDateLong(_selected), style: theme.textTheme.titleMedium)),
                TextButton.icon(
                  onPressed: () => context.push(Routes.appointmentNew(date: _selected)),
                  icon: const Icon(Icons.event_outlined),
                  label: const Text(S.addAppointmentForDay),
                ),
              ],
            ),
          ),
          if (dayAppointments.isEmpty && dayDue.isEmpty && dayServices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(S.dayEmpty, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
          if (dayAppointments.isNotEmpty) ...[
            const SectionHeader(title: S.legendAppointment),
            for (final a in dayAppointments) AppointmentTile(item: a),
          ],
          if (dayDue.isNotEmpty) ...[
            const SectionHeader(title: S.maintenanceDue),
            for (final d in dayDue) DueDeviceTile(item: d),
          ],
          if (dayServices.isNotEmpty) ...[
            const SectionHeader(title: S.servicesDone),
            for (final s in dayServices) ServiceTile(item: s, showCustomer: true),
          ],
        ],
      ),
      floatingActionButton: const NewServiceFab(),
    );
  }
}
