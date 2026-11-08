import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../shared/widgets/empty_state.dart';

class ReceivablesScreen extends StatelessWidget {
  const ReceivablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.tabReceivables)),
      body: const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        message: S.receivablesEmpty,
      ),
    );
  }
}
