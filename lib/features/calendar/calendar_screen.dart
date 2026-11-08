import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/new_service_fab.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.tabCalendar)),
      body: const EmptyState(icon: Icons.calendar_month_outlined, message: S.calendarEmpty),
      floatingActionButton: const NewServiceFab(),
    );
  }
}
