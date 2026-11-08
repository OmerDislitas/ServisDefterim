import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/calendar_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/receivables/receivables_screen.dart';
import '../../features/services/service_form_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/today/today_screen.dart';
import '../../shared/widgets/home_shell.dart';

abstract final class Routes {
  static const today = '/today';
  static const calendar = '/calendar';
  static const customers = '/customers';
  static const receivables = '/receivables';
  static const settings = '/settings';
  static const newService = '/services/new';
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
      // Alt menu olmadan tam ekran acilan sayfalar
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.newService,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const ServiceFormScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
