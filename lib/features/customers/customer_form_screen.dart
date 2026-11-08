import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../core/utils/phone.dart';
import '../../shared/widgets/form_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import 'address_fields.dart';

String? _orNull(String s) => s.trim().isEmpty ? null : s;

/// Telefon dogrulamasi: en az 7 rakam (sabit hatlar dahil).
String? validatePhone(String? v, {bool required = true}) {
  if (v == null || v.trim().isEmpty) return required ? S.requiredField : null;
  return normalizePhone(v).length < 7 ? S.invalidPhone : null;
}

/// Yeni musteri ya da duzenleme. Yeni musteride istege bagli ilk adres de girilebilir.
class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customerId});

  final String? customerId;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _phone2 = TextEditingController();
  final _note = TextEditingController();
  final _address = AddressControllers();

  bool get _isEdit => widget.customerId != null;
  bool _loading = false;
  bool _saving = false;
  Customer? _duplicate;
  Timer? _phoneDebounce;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final c = await ref.read(databaseProvider).customersDao.getCustomer(widget.customerId!);
    if (!mounted) return;
    if (c != null) {
      _name.text = c.name;
      _phone.text = formatPhone(c.phone);
      _phone2.text = c.phone2 == null ? '' : formatPhone(c.phone2!);
      _note.text = c.note ?? '';
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _phoneDebounce?.cancel();
    for (final c in [_name, _phone, _phone2, _note]) {
      c.dispose();
    }
    _address.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    _phoneDebounce?.cancel();
    _phoneDebounce = Timer(const Duration(milliseconds: 300), () async {
      final matches = normalizePhone(value).length < 7
          ? const <Customer>[]
          : await ref.read(databaseProvider).customersDao.findByPhone(value);
      final other = matches.where((c) => c.id != widget.customerId).firstOrNull;
      if (mounted && other?.id != _duplicate?.id) setState(() => _duplicate = other);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final dao = db.customersDao;

    if (_isEdit) {
      await dao.updateCustomer(
        widget.customerId!,
        name: _name.text,
        phone: _phone.text,
        phone2: _orNull(_phone2.text),
        note: _orNull(_note.text),
      );
      if (mounted) context.pop();
      return;
    }

    final id = await db.transaction(() async {
      final id = await dao.insertCustomer(
        name: _name.text,
        phone: _phone.text,
        phone2: _orNull(_phone2.text),
        note: _orNull(_note.text),
      );
      final a = _address;
      if (a.addressLine.text.trim().isNotEmpty) {
        await dao.insertAddress(
          customerId: id,
          label: a.label.text,
          district: a.district.text,
          neighborhood: a.neighborhood.text,
          addressLine: a.addressLine.text,
          floor: a.floor.text,
          apartmentNo: a.apartmentNo.text,
          directions: a.directions.text,
        );
      }
      return id;
    });
    if (mounted) context.pushReplacement(Routes.customer(id));
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: _isEdit ? S.editCustomer : S.newCustomer,
      formKey: _formKey,
      loading: _loading,
      saving: _saving,
      onSave: _save,
      children: [
        TextFormField(
          controller: _name,
          autofocus: !_isEdit,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: S.customerName),
          validator: (v) => (v == null || v.trim().isEmpty) ? S.requiredField : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: S.phone, prefixIcon: Icon(Icons.phone_outlined)),
          onChanged: _onPhoneChanged,
          validator: validatePhone,
        ),
        if (_duplicate != null) _DuplicateWarning(customer: _duplicate!),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phone2,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: S.phone2, prefixIcon: Icon(Icons.phone_outlined)),
          validator: (v) => validatePhone(v, required: false),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: S.note),
          minLines: 1,
          maxLines: 4,
        ),
        if (!_isEdit) ...[
          const SectionHeader(title: S.addressOptional),
          AddressFields(controllers: _address, addressLineRequired: false),
        ],
      ],
    );
  }
}

class _DuplicateWarning extends StatelessWidget {
  const _DuplicateWarning({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(Icons.info_outline, color: scheme.onTertiaryContainer),
        title: Text(S.duplicatePhone(customer.name), style: TextStyle(color: scheme.onTertiaryContainer)),
        trailing: TextButton(
          onPressed: () => context.pushReplacement(Routes.customer(customer.id)),
          child: const Text(S.goToCustomer),
        ),
      ),
    );
  }
}
