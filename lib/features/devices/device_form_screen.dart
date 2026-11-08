import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/daos/settings_dao.dart';
import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/maintenance.dart';
import '../../core/utils/text_normalize.dart';
import '../../shared/widgets/date_field.dart';
import '../../shared/widgets/form_scaffold.dart';
import 'devices_providers.dart';

/// Yeni kombi ([addressId]) ya da kombi duzenleme ([deviceId]).
class DeviceFormScreen extends ConsumerStatefulWidget {
  const DeviceFormScreen({super.key, this.addressId, this.deviceId})
      : assert(addressId != null || deviceId != null);

  final String? addressId;
  final String? deviceId;

  @override
  ConsumerState<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends ConsumerState<DeviceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brand = TextEditingController();
  final _brandFocus = FocusNode();
  final _model = TextEditingController();
  final _serial = TextEditingController();
  final _year = TextEditingController();
  final _interval = TextEditingController();
  final _note = TextEditingController();
  DeviceType _type = DeviceType.condensing;
  DateTime? _warrantyEnd;
  DateTime? _nextMaintenance;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.deviceId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    if (_isEdit) {
      final d = await db.devicesDao.getDevice(widget.deviceId!);
      if (d != null) {
        _brand.text = d.brand;
        _model.text = d.model ?? '';
        _serial.text = d.serialNo ?? '';
        _year.text = d.installYear?.toString() ?? '';
        _interval.text = '${d.maintenanceIntervalMonths}';
        _note.text = d.note ?? '';
        _type = d.type;
        _warrantyEnd = d.warrantyEnd;
        _nextMaintenance = d.nextMaintenanceDate;
      }
    } else {
      _interval.text = '${await db.settingsDao.getInt(SettingKeys.defaultIntervalMonths)}';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_brand, _model, _serial, _year, _interval, _note]) {
      c.dispose();
    }
    _brandFocus.dispose();
    super.dispose();
  }

  int get _intervalMonths => int.tryParse(_interval.text) ?? 12;

  Future<void> _pickLastMaintenance() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: today(),
      firstDate: DateTime(2000),
      lastDate: today(),
      helpText: S.fromLastMaintenance,
    );
    if (picked != null) setState(() => _nextMaintenance = computeNextMaintenance(picked, _intervalMonths));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final dao = ref.read(databaseProvider).devicesDao;
    final year = int.tryParse(_year.text.trim());
    if (_isEdit) {
      await dao.updateDevice(
        widget.deviceId!,
        brand: _brand.text,
        model: _model.text,
        serialNo: _serial.text,
        type: _type,
        installYear: year,
        warrantyEnd: _warrantyEnd,
        maintenanceIntervalMonths: _intervalMonths,
        nextMaintenanceDate: _nextMaintenance,
        note: _note.text,
      );
    } else {
      await dao.insertDevice(
        addressId: widget.addressId!,
        brand: _brand.text,
        model: _model.text,
        serialNo: _serial.text,
        type: _type,
        installYear: year,
        warrantyEnd: _warrantyEnd,
        maintenanceIntervalMonths: _intervalMonths,
        nextMaintenanceDate: _nextMaintenance,
        note: _note.text,
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final brands = ref.watch(brandSuggestionsProvider).value ?? S.brandSuggestions;
    final digitsOnly = [FilteringTextInputFormatter.digitsOnly];

    return FormScaffold(
      title: _isEdit ? S.editDevice : S.newDevice,
      formKey: _formKey,
      loading: _loading,
      saving: _saving,
      onSave: _save,
      children: [
        _BrandField(controller: _brand, focusNode: _brandFocus, options: brands),
        const SizedBox(height: 12),
        TextFormField(
          controller: _model,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: S.model),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _serial,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: S.serialNo),
        ),
        const SizedBox(height: 16),
        Text(S.deviceType, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in DeviceType.values)
              ChoiceChip(
                label: Text(t.label),
                selected: _type == t,
                onSelected: (_) => setState(() => _type = t),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _year,
                keyboardType: TextInputType.number,
                inputFormatters: digitsOnly,
                decoration: const InputDecoration(labelText: S.installYear),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final y = int.tryParse(v);
                  return (y == null || y < 1970 || y > DateTime.now().year + 1) ? S.invalidYear : null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _interval,
                keyboardType: TextInputType.number,
                inputFormatters: digitsOnly,
                decoration: const InputDecoration(labelText: S.maintenanceInterval),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 1 || n > 60) ? S.invalidNumber : null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DateField(
          label: S.warrantyEnd,
          value: _warrantyEnd,
          onChanged: (d) => setState(() => _warrantyEnd = d),
        ),
        const SizedBox(height: 12),
        DateField(
          label: S.nextMaintenance,
          value: _nextMaintenance,
          onChanged: (d) => setState(() => _nextMaintenance = d),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _pickLastMaintenance,
            icon: const Icon(Icons.history),
            label: const Text(S.fromLastMaintenance),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: S.note),
          minLines: 1,
          maxLines: 4,
        ),
      ],
    );
  }
}

/// Marka: serbest metin + oneriler (Turkce normalize edilerek eslestirilir).
class _BrandField extends StatelessWidget {
  const _BrandField({required this.controller, required this.focusNode, required this.options});

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (value) {
        final q = normalizeForSearch(value.text);
        if (q.isEmpty) return options;
        return options.where((o) => normalizeForSearch(o).contains(q) && o != value.text);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextFormField(
        controller: controller,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: S.brand),
        validator: (v) => (v == null || v.trim().isEmpty) ? S.requiredField : null,
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
