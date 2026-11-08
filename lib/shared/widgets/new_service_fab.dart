import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/strings.dart';

/// Bugun, Takvim ve Musteriler sekmelerindeki buyuk "Yeni Servis" butonu.
class NewServiceFab extends StatelessWidget {
  const NewServiceFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: null,
      onPressed: () => context.push(Routes.newService),
      icon: const Icon(Icons.add),
      label: const Text(S.newService),
    );
  }
}
