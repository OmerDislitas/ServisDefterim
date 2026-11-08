import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/strings.dart';

/// Adres formu alanlarinin controller'lari.
class AddressControllers {
  final label = TextEditingController();
  final district = TextEditingController();
  final neighborhood = TextEditingController();
  final addressLine = TextEditingController();
  final floor = TextEditingController();
  final apartmentNo = TextEditingController();
  final directions = TextEditingController();

  List<TextEditingController> get _all =>
      [label, district, neighborhood, addressLine, floor, apartmentNo, directions];

  /// Herhangi bir alan dolu mu?
  bool get hasAny => _all.any((c) => c.text.trim().isNotEmpty);

  void fill(Address a) {
    label.text = a.label ?? '';
    district.text = a.district ?? '';
    neighborhood.text = a.neighborhood ?? '';
    addressLine.text = a.addressLine;
    floor.text = a.floor ?? '';
    apartmentNo.text = a.apartmentNo ?? '';
    directions.text = a.directions ?? '';
  }

  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
  }
}

/// Adres alanlari. [addressLineRequired] false ise acik adres sadece baska bir alan
/// doluysa zorunludur (yeni musteri formunda adres istege bagli).
class AddressFields extends StatelessWidget {
  const AddressFields({super.key, required this.controllers, this.addressLineRequired = true});

  final AddressControllers controllers;
  final bool addressLineRequired;

  @override
  Widget build(BuildContext context) {
    final c = controllers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: c.label,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: S.addressLabel),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (final l in S.addressLabels)
              ActionChip(label: Text(l), onPressed: () => c.label.text = l),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.district,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: S.district),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: c.neighborhood,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: S.neighborhood),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: c.addressLine,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: S.addressLine, hintText: S.addressLineHint),
          validator: (v) {
            final empty = v == null || v.trim().isEmpty;
            if (empty && (addressLineRequired || c.hasAny)) return S.requiredField;
            return null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.floor,
                decoration: const InputDecoration(labelText: S.floor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: c.apartmentNo,
                decoration: const InputDecoration(labelText: S.apartmentNo),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: c.directions,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: S.directions, hintText: S.directionsHint),
          maxLines: 2,
          minLines: 1,
        ),
      ],
    );
  }
}
