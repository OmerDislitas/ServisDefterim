import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/new_service_fab.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.tabToday),
        actions: [
          IconButton(
            tooltip: S.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: const EmptyState(icon: Icons.today_outlined, message: S.todayEmpty),
      floatingActionButton: const NewServiceFab(),
    );
  }
}
