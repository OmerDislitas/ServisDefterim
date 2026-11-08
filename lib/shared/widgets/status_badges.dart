import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/maintenance.dart';
import '../../core/utils/payment.dart';

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Bakim durumu rozeti: Gecikmis (kirmizi), Bu hafta (turuncu), Yaklasan, Ileride, Bilinmiyor.
class MaintenanceBadge extends StatelessWidget {
  const MaintenanceBadge({super.key, required this.nextDate});

  final DateTime? nextDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = maintenanceStatus(nextDate, today());
    final (bg, fg) = switch (status) {
      MaintenanceStatus.overdue => (scheme.error, scheme.onError),
      MaintenanceStatus.thisWeek => (const Color(0xFFE65100), Colors.white),
      MaintenanceStatus.upcoming => (const Color(0xFFFFE0B2), const Color(0xFF5D2E00)),
      MaintenanceStatus.later => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      MaintenanceStatus.unknown => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return _Badge(label: status.label, background: bg, foreground: fg);
  }
}

/// Odeme durumu rozeti: Odendi (yesil), Kismi (turuncu), Veresiye (kirmizi).
class PaymentBadge extends StatelessWidget {
  const PaymentBadge({super.key, required this.total, required this.paid});

  final int total;
  final int paid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = paymentStatus(total: total, paid: paid);
    final (bg, fg) = switch (status) {
      PaymentStatus.paid => (const Color(0xFFC8E6C9), const Color(0xFF1B5E20)),
      PaymentStatus.partial => (const Color(0xFFFFE0B2), const Color(0xFF5D2E00)),
      PaymentStatus.unpaid => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return _Badge(label: status.label, background: bg, foreground: fg);
  }
}
