import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/db_providers.dart';
import '../../core/strings.dart';
import '../../shared/widgets/form_scaffold.dart';
import 'address_fields.dart';

/// Yeni adres ([customerId]) ya da adres duzenleme ([addressId]).
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.customerId, this.addressId})
      : assert(customerId != null || addressId != null);

  final String? customerId;
  final String? addressId;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _c = AddressControllers();
  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.addressId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final a = await ref.read(databaseProvider).customersDao.getAddress(widget.addressId!);
    if (!mounted) return;
    if (a != null) _c.fill(a);
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final dao = ref.read(databaseProvider).customersDao;
    if (_isEdit) {
      await dao.updateAddress(
        widget.addressId!,
        label: _c.label.text,
        district: _c.district.text,
        neighborhood: _c.neighborhood.text,
        addressLine: _c.addressLine.text,
        floor: _c.floor.text,
        apartmentNo: _c.apartmentNo.text,
        directions: _c.directions.text,
      );
    } else {
      await dao.insertAddress(
        customerId: widget.customerId!,
        label: _c.label.text,
        district: _c.district.text,
        neighborhood: _c.neighborhood.text,
        addressLine: _c.addressLine.text,
        floor: _c.floor.text,
        apartmentNo: _c.apartmentNo.text,
        directions: _c.directions.text,
      );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: _isEdit ? S.editAddress : S.newAddress,
      formKey: _formKey,
      loading: _loading,
      saving: _saving,
      onSave: _save,
      children: [AddressFields(controllers: _c)],
    );
  }
}
