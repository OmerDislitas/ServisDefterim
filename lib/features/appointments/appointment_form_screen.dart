import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/phone.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/form_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import '../customers/customer_form_screen.dart' show validatePhone;
import '../services/service_selection.dart';
import 'appointments_providers.dart';

/// Randevu formu (PLAN 7.8): musteri (ve istege bagli kombi), tarih-saat, tur, not.
class AppointmentFormScreen extends ConsumerStatefulWidget {
  const AppointmentFormScreen({super.key, this.appointmentId, this.customerId, this.deviceId, this.date});

  final String? appointmentId;
  final String? customerId;
  final String? deviceId;
  final DateTime? date;

  @override
  ConsumerState<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends ConsumerState<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  Customer? _customer;
  bool _newCustomer = false;
  String? _deviceId;
  late DateTime _date;
  late TimeOfDay _time;
  ServiceType _type = ServiceType.maintenance;
  bool _loading = true;
  bool _saving = false;
  bool _showErrors = false;

  bool get _isEdit => widget.appointmentId != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = dateOnly(widget.date ?? now);
    // Varsayilan saat: bugunse bir sonraki tam saat, degilse 10:00
    _time = isSameDay(_date, now) && now.hour < 22 ? TimeOfDay(hour: now.hour + 1, minute: 0) : const TimeOfDay(hour: 10, minute: 0);
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    if (_isEdit) {
      final a = await db.appointmentsDao.getAppointment(widget.appointmentId!);
      if (a != null) {
        _customer = await db.customersDao.getCustomer(a.customerId);
        _deviceId = a.deviceId;
        _date = dateOnly(a.scheduledAt);
        _time = TimeOfDay.fromDateTime(a.scheduledAt);
        _type = a.type;
        _note.text = a.note ?? '';
      }
    } else if (widget.customerId != null) {
      _customer = await db.customersDao.getCustomer(widget.customerId!);
      _deviceId = widget.deviceId;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _selectCustomer(String id) async {
    final c = await ref.read(databaseProvider).customersDao.getCustomer(id);
    setState(() {
      _customer = c;
      _newCustomer = false;
      _deviceId = null;
    });
  }

  Future<void> _save() async {
    setState(() => _showErrors = true);
    if (!_formKey.currentState!.validate() || (_customer == null && !_newCustomer)) return;
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final scheduledAt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

    await db.transaction(() async {
      final customerId = _customer?.id ?? await db.customersDao.insertCustomer(name: _name.text, phone: _phone.text);
      if (_isEdit) {
        await db.appointmentsDao.updateAppointment(
          widget.appointmentId!,
          customerId: customerId,
          deviceId: _deviceId,
          scheduledAt: scheduledAt,
          type: _type,
          note: _note.text,
        );
      } else {
        await db.appointmentsDao.insertAppointment(
          customerId: customerId,
          deviceId: _deviceId,
          scheduledAt: scheduledAt,
          type: _type,
          note: _note.text,
        );
      }
    });
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger.showSnackBar(const SnackBar(content: Text(S.saved)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devices = _customer == null
        ? const <Device>[]
        : ref.watch(devicesForCustomerProvider(_customer!.id)).value ?? const <Device>[];

    return FormScaffold(
      title: _isEdit ? S.editAppointment : S.newAppointment,
      formKey: _formKey,
      loading: _loading,
      saving: _saving,
      onSave: _save,
      children: [
        const SectionHeader(title: S.customer),
        if (_customer != null)
          SelectionSummary(
            icon: Icons.person_outline,
            title: _customer!.name,
            subtitle: formatPhone(_customer!.phone),
            onChange: () => setState(() {
              _customer = null;
              _deviceId = null;
            }),
          )
        else if (_newCustomer) ...[
          TextFormField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: S.customerName,
              suffixIcon: IconButton(
                tooltip: S.cancel,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _newCustomer = false),
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? S.requiredField : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: S.phone, prefixIcon: Icon(Icons.phone_outlined)),
            validator: validatePhone,
          ),
        ] else
          CustomerSearch(
            onSelect: _selectCustomer,
            onNew: () => setState(() => _newCustomer = true),
            errorText: _showErrors ? S.selectCustomer : null,
          ),

        if (devices.isNotEmpty) ...[
          const SectionHeader(title: S.deviceOptional),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text(S.noDeviceSelected),
                selected: _deviceId == null,
                onSelected: (_) => setState(() => _deviceId = null),
              ),
              for (final d in devices)
                ChoiceChip(
                  label: Text(deviceTitle(d.brand, d.model)),
                  selected: _deviceId == d.id,
                  onSelected: (_) => setState(() => _deviceId = d.id),
                ),
            ],
          ),
        ],

        const SectionHeader(title: S.appointment),
        Row(
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text(S.appointmentDate),
                subtitle: Text(formatDateLong(_date)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = dateOnly(picked));
                },
              ),
            ),
            SizedBox(
              width: 120,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: const Text(S.appointmentTime),
                subtitle: Text(_time.format(context)),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(S.serviceType, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in ServiceType.values)
              ChoiceChip(label: Text(t.label), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
          ],
        ),
        const SizedBox(height: 16),
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
