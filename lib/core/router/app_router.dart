import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/appointment_detail_screen.dart';
import '../../features/appointments/appointment_form_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/due_maintenance/due_maintenance_screen.dart';
import '../../features/settings/whatsapp_template_screen.dart';
import '../utils/dates.dart';
import '../utils/maintenance.dart';
import '../../features/customers/address_form_screen.dart';
import '../../features/customers/customer_detail_screen.dart';
import '../../features/customers/customer_form_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/devices/device_detail_screen.dart';
import '../../features/devices/device_form_screen.dart';
import '../../features/receivables/receivables_screen.dart';
import '../../features/services/service_detail_screen.dart';
import '../../features/services/service_form_screen.dart';
import '../../features/settings/checklist_settings_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/today/today_screen.dart';
import '../../shared/widgets/home_shell.dart';

abstract final class Routes {
  // Alt menu sekmeleri
  static const today = '/today';
  static const calendar = '/calendar';
  static const customers = '/customers';
  static const receivables = '/receivables';

  // Alt menu olmadan tam ekran acilan sayfalar (her sekmeden acilabilir)
  static const settings = '/settings';
  static const newService = '/services/new';
  static const customerNew = '/customer/new';
  static String customer(String id) => '/customer/$id';
  static String customerEdit(String id) => '/customer/$id/edit';
  static String addressNew(String customerId) => '/customer/$customerId/address/new';
  static String addressEdit(String id) => '/address/$id/edit';
  static String deviceNew(String addressId) => '/address/$addressId/device/new';
  static String device(String id) => '/device/$id';
  static String deviceEdit(String id) => '/device/$id/edit';
  static String newServiceFor({String? deviceId, String? appointmentId}) {
    final q = {'deviceId': ?deviceId, 'appointmentId': ?appointmentId};
    return q.isEmpty ? newService : Uri(path: newService, queryParameters: q).toString();
  }
  static const resumeServiceDraft = '$newService?draft=1';
  static String service(String id) => '/service/$id';
  static String serviceEdit(String id) => '/service/$id/edit';
  static const checklistSettings = '/settings/checklist';
  static const whatsappTemplateSettings = '/settings/whatsapp';
  static String dueMaintenance([DueFilter filter = DueFilter.overdue]) => '/due?filter=${filter.name}';
  static String appointmentNew({String? customerId, String? deviceId, DateTime? date}) {
    final q = {'customerId': ?customerId, 'deviceId': ?deviceId, if (date != null) 'date': toDateKey(date)};
    return q.isEmpty ? '/appointment/new' : Uri(path: '/appointment/new', queryParameters: q).toString();
  }

  static String appointment(String id) => '/appointment/$id';
  static String appointmentEdit(String id) => '/appointment/$id/edit';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.today,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.today, builder: (_, _) => const TodayScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.calendar, builder: (_, _) => const CalendarScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.customers, builder: (_, _) => const CustomersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.receivables, builder: (_, _) => const ReceivablesScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(path: 'checklist', builder: (_, _) => const ChecklistSettingsScreen()),
          GoRoute(path: 'whatsapp', builder: (_, _) => const WhatsappTemplateScreen()),
        ],
      ),
      GoRoute(
        path: '/due',
        builder: (_, state) => DueMaintenanceScreen(
          initialFilter: DueFilter.values.asNameMap()[state.uri.queryParameters['filter']] ?? DueFilter.overdue,
        ),
      ),
      GoRoute(
        path: '/appointment/new',
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return AppointmentFormScreen(
            customerId: q['customerId'],
            deviceId: q['deviceId'],
            date: q['date'] == null ? null : parseDateKey(q['date']!),
          );
        },
      ),
      GoRoute(
        path: '/appointment/:id',
        builder: (_, state) => AppointmentDetailScreen(appointmentId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) => AppointmentFormScreen(appointmentId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: Routes.newService,
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return ServiceFormScreen(
            deviceId: q['deviceId'],
            appointmentId: q['appointmentId'],
            resumeDraft: q['draft'] == '1',
          );
        },
      ),
      GoRoute(
        path: '/service/:id',
        builder: (_, state) => ServiceDetailScreen(serviceId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) => ServiceFormScreen(serviceId: state.pathParameters['id']!),
          ),
        ],
      ),
      // 'new' rotasi ':id' rotasindan once tanimlanmali
      GoRoute(path: Routes.customerNew, builder: (_, _) => const CustomerFormScreen()),
      GoRoute(
        path: '/customer/:id',
        builder: (_, state) => CustomerDetailScreen(customerId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) => CustomerFormScreen(customerId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'address/new',
            builder: (_, state) => AddressFormScreen(customerId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/address/:id/edit',
        builder: (_, state) => AddressFormScreen(addressId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/address/:id/device/new',
        builder: (_, state) => DeviceFormScreen(addressId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/device/:id',
        builder: (_, state) => DeviceDetailScreen(deviceId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) => DeviceFormScreen(deviceId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
