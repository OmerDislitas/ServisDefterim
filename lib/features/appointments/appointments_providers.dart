import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/appointments_dao.dart';
import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';

final appointmentProvider = StreamProvider.autoDispose.family<Appointment?, String>(
  (ref, id) => ref.watch(databaseProvider).appointmentsDao.watchAppointment(id),
);

final devicesForCustomerProvider = StreamProvider.autoDispose.family<List<Device>, String>(
  (ref, customerId) => ref.watch(databaseProvider).devicesDao.watchDevicesForCustomer(customerId),
);

final serviceForAppointmentProvider = StreamProvider.autoDispose.family<ServiceRecord?, String>(
  (ref, appointmentId) => ref.watch(databaseProvider).servicesDao.watchServiceForAppointment(appointmentId),
);

/// [from, to) araligindaki randevular.
final appointmentsInRangeProvider =
    StreamProvider.autoDispose.family<List<AppointmentListItem>, ({DateTime from, DateTime to})>(
  (ref, r) => ref.watch(databaseProvider).appointmentsDao.watchAppointments(from: r.from, to: r.to),
);
