import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/new_service_fab.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.tabCustomers)),
      body: const EmptyState(icon: Icons.people_outline, message: S.customersEmpty),
      floatingActionButton: const NewServiceFab(),
    );
  }
}
