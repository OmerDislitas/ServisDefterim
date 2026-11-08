import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../shared/widgets/empty_state.dart';

/// Yeni servis kaydi formu. M3'te doldurulacak.
class ServiceFormScreen extends StatelessWidget {
  const ServiceFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.newService)),
      body: const EmptyState(icon: Icons.build_outlined, message: S.newServiceEmpty),
    );
  }
}
