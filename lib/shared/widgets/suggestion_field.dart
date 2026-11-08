import 'package:flutter/material.dart';

import '../../core/utils/text_normalize.dart';

/// Serbest metin + oneri listesi (Turkce normalize edilerek eslestirilir).
/// Marka ve parca adi alanlarinda kullanilir.
class SuggestionField extends StatefulWidget {
  const SuggestionField({
    super.key,
    required this.controller,
    required this.options,
    required this.label,
    this.validator,
    this.onChanged,
    this.showAllWhenEmpty = true,
  });

  final TextEditingController controller;
  final List<String> options;
  final String label;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool showAllWhenEmpty;

  @override
  State<SuggestionField> createState() => _SuggestionFieldState();
}

class _SuggestionFieldState extends State<SuggestionField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (value) {
        final q = normalizeForSearch(value.text);
        if (q.isEmpty) return widget.showAllWhenEmpty ? widget.options : const <String>[];
        return widget.options.where((o) => o != value.text && normalizeForSearch(o).contains(q));
      },
      onSelected: (v) => widget.onChanged?.call(v),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextFormField(
        controller: controller,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: widget.label),
        validator: widget.validator,
        onChanged: widget.onChanged,
        onFieldSubmitted: (_) => onSubmitted(),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 360),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in options) ListTile(title: Text(o), onTap: () => onSelected(o)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
