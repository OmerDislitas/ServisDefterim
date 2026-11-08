import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/utils/money.dart';

/// TL tutar alani: sayisal klavye, girdi kurusa [parseMoney] ile cevrilir.
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.validator,
    this.suffix,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final Widget? suffix;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(labelText: label, suffixText: '₺', suffixIcon: suffix, helperText: helperText),
      onChanged: onChanged,
      validator: validator ??
          (v) => (v == null || v.trim().isEmpty || parseMoney(v) != null) ? null : S.invalidAmount,
    );
  }
}
