import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/db_providers.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../shared/widgets/date_field.dart';
import '../../shared/widgets/money_field.dart';

/// "Odeme al": tutar (varsayilan kalan), tarih, not -> payments kaydi (PLAN 7.7, 7.9).
Future<void> showPaymentDialog(
  BuildContext context,
  WidgetRef ref, {
  required String serviceId,
  required int remaining,
}) async {
  final db = ref.read(databaseProvider);
  final messenger = ScaffoldMessenger.of(context);
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => _PaymentDialog(
      remaining: remaining,
      onSave: (amount, date, note) =>
          db.servicesDao.addPayment(serviceId: serviceId, amount: amount, date: date, note: note),
    ),
  );
  if (saved == true) messenger.showSnackBar(const SnackBar(content: Text(S.paymentSaved)));
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.remaining, required this.onSave});

  final int remaining;
  final Future<void> Function(int amount, DateTime date, String? note) onSave;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.remaining > 0 ? kurusToInput(widget.remaining) : '');
  final _note = TextEditingController();
  DateTime _date = today();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    // Bugun secildiyse simdiki saat, degilse secilen gun
    final date = isSameDay(_date, now) ? now : DateTime(_date.year, _date.month, _date.day, 12);
    await widget.onSave(parseMoney(_amount.text)!, date, _note.text.trim().isEmpty ? null : _note.text);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(S.takePayment),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MoneyField(
                controller: _amount,
                label: S.paymentAmount,
                validator: (v) {
                  final a = parseMoney(v ?? '');
                  return (a == null || a <= 0) ? S.invalidAmount : null;
                },
              ),
              const SizedBox(height: 12),
              DateField(
                label: S.paymentDate,
                value: _date,
                lastDate: DateTime.now(),
                onChanged: (d) => setState(() => _date = d ?? today()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: S.note),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.cancel)),
        FilledButton(onPressed: _saving ? null : _save, child: const Text(S.save)),
      ],
    );
  }
}
