import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/daos/services_dao.dart';
import '../../core/db/daos/settings_dao.dart';
import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/strings.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/maintenance.dart';
import '../../core/utils/money.dart';
import '../../core/utils/phone.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/money_field.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_badges.dart';
import '../../shared/widgets/suggestion_field.dart';
import '../customers/customer_form_screen.dart' show validatePhone;
import '../devices/devices_providers.dart';
import 'service_draft.dart';
import 'service_selection.dart';
import 'services_providers.dart';

/// Yeni servis kaydi / servis duzenleme (PLAN 7.6). En kritik ekran: sahada, hizli,
/// hataya dayanikli. Yeni kayitta form durumu otomatik taslak olarak saklanir.
class ServiceFormScreen extends ConsumerStatefulWidget {
  const ServiceFormScreen({
    super.key,
    this.deviceId,
    this.appointmentId,
    this.serviceId,
    this.resumeDraft = false,
  });

  /// Kombi detayindan: musteri/adres/kombi secili gelir.
  final String? deviceId;

  /// Randevudan: musteri/kombi secili gelir, kayit randevuya baglanir.
  final String? appointmentId;

  /// Duzenleme modu.
  final String? serviceId;

  /// Acilistaki "devam et" sorusundan geliyorsa taslak dogrudan yuklenir.
  final bool resumeDraft;

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _PartRow {
  _PartRow([PartDraft d = const PartDraft()])
      : name = TextEditingController(text: d.name),
        quantity = TextEditingController(text: d.quantity),
        unitPrice = TextEditingController(text: d.unitPrice);

  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  PartDraft get draft => PartDraft(name: name.text, quantity: quantity.text, unitPrice: unitPrice.text);

  void dispose() {
    name.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _showErrors = false;
  Timer? _draftTimer;
  int _defaultInterval = 12;

  // Secim
  Customer? _customer;
  Address? _address;
  Device? _device;
  bool _newCustomer = false;
  bool _newAddress = false;
  bool _newDevice = false;
  String? _appointmentId;
  Customer? _duplicate;
  final _ncName = TextEditingController();
  final _ncPhone = TextEditingController();
  final _naDistrict = TextEditingController();
  final _naNeighborhood = TextEditingController();
  final _naLine = TextEditingController();
  final _ndBrand = TextEditingController();
  final _ndModel = TextEditingController();
  DeviceType _ndType = DeviceType.condensing;

  // Servis bilgisi
  ServiceType? _type;
  DateTime _date = DateTime.now();
  DateTime? _originalDate;
  final _complaint = TextEditingController();
  final _errorCode = TextEditingController();
  final _workNotes = TextEditingController();
  final _water = TextEditingController();
  final _expansion = TextEditingController();
  final _co = TextEditingController();
  List<String> _checklistLabels = const [];
  final Set<String> _checked = {};

  // Parcalar ve ucret
  final List<_PartRow> _parts = [];
  final _total = TextEditingController();
  bool _totalManual = false;
  final _payment = TextEditingController();
  PaymentMode _paymentMode = PaymentMode.custom;

  // Sonraki bakim
  bool _periodic = true;
  DateTime? _nextMaintenance;
  bool _nextManual = false;

  bool get _isEdit => widget.serviceId != null;

  List<TextEditingController> get _textControllers => [
        _ncName, _ncPhone, _naDistrict, _naNeighborhood, _naLine, _ndBrand, _ndModel, //
        _complaint, _errorCode, _workNotes, _water, _expansion, _co, _total, _payment,
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _phoneDebounce?.cancel();
    for (final c in _textControllers) {
      c.dispose();
    }
    for (final p in _parts) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Telefon gelirse / uygulama arka plana giderse taslagi hemen yaz
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) _flushDraft();
  }

  AppDatabase get _db => ref.read(databaseProvider);

  // ---------------------------------------------------------------------------
  // Yukleme
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    final db = _db;
    _defaultInterval = await db.settingsDao.getInt(SettingKeys.defaultIntervalMonths);
    _checklistLabels = await db.checklistDao.activeLabels();

    if (_isEdit) {
      await _loadService(widget.serviceId!);
    } else {
      final draft = ServiceDraft.decode(await db.settingsDao.getValue(SettingKeys.serviceDraft));
      var resume = widget.resumeDraft && draft != null;
      if (!resume && draft != null && mounted) {
        setState(() => _loading = false);
        resume = await _askResumeDraft();
        if (!resume) await db.settingsDao.setValue(SettingKeys.serviceDraft, null);
      }
      if (resume) {
        await _applyDraft(draft!);
        _dirty = true;
      } else {
        await _applyPrefill();
        // On doldurma kullanici degisikligi sayilmaz
        _dirty = false;
        _draftTimer?.cancel();
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _askResumeDraft() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(S.draftTitle),
        content: const Text(S.draftResumeBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.draftStartNew)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(S.draftContinue)),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _applyPrefill() async {
    final db = _db;
    if (widget.appointmentId != null) {
      final appt = await db.appointmentsDao.getAppointment(widget.appointmentId!);
      if (appt != null) {
        _appointmentId = appt.id;
        _type = appt.type;
        _periodic = appt.type == ServiceType.maintenance;
        await _selectCustomer(appt.customerId, autoAdvance: appt.deviceId == null);
        if (appt.deviceId != null) await _selectDeviceById(appt.deviceId!);
      }
    } else if (widget.deviceId != null) {
      await _selectDeviceById(widget.deviceId!);
    }
    _recomputeNext();
  }

  /// Kombiyi ve bagli adres/musteriyi secer.
  Future<void> _selectDeviceById(String deviceId) async {
    final db = _db;
    final device = await db.devicesDao.getDevice(deviceId);
    if (device == null) return;
    final address = await db.customersDao.getAddress(device.addressId);
    final customer = address == null ? null : await db.customersDao.getCustomer(address.customerId);
    if (address == null || customer == null) return;
    setState(() {
      _customer = customer;
      _address = address;
      _device = device;
      _newCustomer = _newAddress = _newDevice = false;
    });
  }

  Future<void> _loadService(String id) async {
    final db = _db;
    final s = await db.servicesDao.getService(id);
    if (s == null) return;
    await _selectDeviceById(s.deviceId);
    final parts = await db.servicesDao.getParts(id);
    _type = s.type;
    _date = s.date;
    _originalDate = s.date;
    _periodic = s.isPeriodicMaintenance;
    _complaint.text = s.complaint ?? '';
    _errorCode.text = s.errorCode ?? '';
    _workNotes.text = s.workNotes ?? '';
    _water.text = _numText(s.waterPressureBar);
    _expansion.text = _numText(s.expansionTankBar);
    _co.text = s.flueCoPpm?.toString() ?? '';
    _checked.addAll(s.checklistItems);
    // Sablondan cikarilmis ama bu kayitta isaretli maddeler de gorunsun
    _checklistLabels = [..._checklistLabels, ...s.checklistItems.where((l) => !_checklistLabels.contains(l))];
    for (final p in parts) {
      _parts.add(_PartRow(PartDraft(
        name: p.name,
        quantity: '${p.quantity}',
        unitPrice: p.unitPrice == 0 ? '' : kurusToInput(p.unitPrice),
      )));
    }
    _total.text = kurusToInput(s.totalAmount);
    _totalManual = s.totalAmount != _currentDraft().autoTotal;
  }

  static String _numText(double? v) => v == null ? '' : v.toString().replaceAll('.', ',');

  // ---------------------------------------------------------------------------
  // Taslak
  // ---------------------------------------------------------------------------

  ServiceDraft _currentDraft() => ServiceDraft(
        customerId: _customer?.id,
        addressId: _address?.id,
        deviceId: _device?.id,
        appointmentId: _appointmentId,
        newCustomer: _newCustomer,
        newCustomerName: _ncName.text,
        newCustomerPhone: _ncPhone.text,
        newAddress: _newAddress,
        newAddressDistrict: _naDistrict.text,
        newAddressNeighborhood: _naNeighborhood.text,
        newAddressLine: _naLine.text,
        newDevice: _newDevice,
        newDeviceBrand: _ndBrand.text,
        newDeviceModel: _ndModel.text,
        newDeviceType: _ndType.name,
        type: _type?.name,
        date: _date,
        complaint: _complaint.text,
        errorCode: _errorCode.text,
        workNotes: _workNotes.text,
        waterPressure: _water.text,
        expansionTank: _expansion.text,
        flueCo: _co.text,
        checklist: _checked.toList(),
        parts: [for (final p in _parts) p.draft],
        total: _total.text,
        totalManual: _totalManual,
        payment: _payment.text,
        paymentMode: _paymentMode,
        periodic: _periodic,
        nextMaintenance: _nextMaintenance,
        nextMaintenanceManual: _nextManual,
      );

  Future<void> _applyDraft(ServiceDraft d) async {
    final db = _db;
    if (d.deviceId != null) {
      await _selectDeviceById(d.deviceId!);
    } else if (d.customerId != null) {
      _customer = await db.customersDao.getCustomer(d.customerId!);
      if (d.addressId != null) _address = await db.customersDao.getAddress(d.addressId!);
    }
    _appointmentId = d.appointmentId;
    _newCustomer = _customer == null && d.newCustomer;
    _newAddress = _address == null && (d.newAddress || _newCustomer);
    _newDevice = _device == null && (d.newDevice || _newAddress);
    _ncName.text = d.newCustomerName;
    _ncPhone.text = d.newCustomerPhone;
    _naDistrict.text = d.newAddressDistrict;
    _naNeighborhood.text = d.newAddressNeighborhood;
    _naLine.text = d.newAddressLine;
    _ndBrand.text = d.newDeviceBrand;
    _ndModel.text = d.newDeviceModel;
    _ndType = DeviceType.values.asNameMap()[d.newDeviceType] ?? DeviceType.condensing;
    _type = d.type == null ? null : ServiceType.values.asNameMap()[d.type];
    _date = d.date;
    _complaint.text = d.complaint;
    _errorCode.text = d.errorCode;
    _workNotes.text = d.workNotes;
    _water.text = d.waterPressure;
    _expansion.text = d.expansionTank;
    _co.text = d.flueCo;
    _checked
      ..clear()
      ..addAll(d.checklist);
    for (final p in d.parts) {
      _parts.add(_PartRow(p));
    }
    _total.text = d.total;
    _totalManual = d.totalManual;
    _payment.text = d.payment;
    _paymentMode = d.paymentMode;
    _periodic = d.periodic;
    _nextMaintenance = d.nextMaintenance;
    _nextManual = d.nextMaintenanceManual;
  }

  void _scheduleDraftSave() {
    if (_isEdit) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), _flushDraft);
  }

  Future<void> _flushDraft() async {
    _draftTimer?.cancel();
    if (_isEdit || !_dirty || _saving) return;
    await _db.settingsDao.setValue(SettingKeys.serviceDraft, _currentDraft().encode());
  }

  Future<void> _clearDraft() async {
    _draftTimer?.cancel();
    await _db.settingsDao.setValue(SettingKeys.serviceDraft, null);
  }

  /// Her kullanici degisikliginde: turetilmis alanlari guncelle, taslagi planla.
  void _changed() {
    _syncTotals();
    _dirty = true;
    _scheduleDraftSave();
    setState(() {});
  }

  void _syncTotals() {
    final auto = _currentDraft().autoTotal;
    if (!_totalManual) _total.text = auto == 0 ? '' : kurusToInput(auto);
    if (_paymentMode == PaymentMode.full) _payment.text = _total.text;
    if (_paymentMode == PaymentMode.none) _payment.text = '';
  }

  int get _totalValue => parseMoney(_total.text) ?? 0;

  int get _intervalMonths => _device?.maintenanceIntervalMonths ?? _defaultInterval;

  void _recomputeNext() {
    if (!_nextManual) _nextMaintenance = computeNextMaintenance(_date, _intervalMonths);
  }

  // ---------------------------------------------------------------------------
  // Secim islemleri
  // ---------------------------------------------------------------------------

  Future<void> _selectCustomer(String id, {bool autoAdvance = true}) async {
    final db = _db;
    final customer = await db.customersDao.getCustomer(id);
    final addresses = await db.customersDao.getAddresses(id);
    if (!mounted) return;
    setState(() {
      _customer = customer;
      _newCustomer = false;
      _duplicate = null;
      _address = null;
      _device = null;
      _newAddress = addresses.isEmpty;
      _newDevice = addresses.isEmpty;
    });
    // Tek adres varsa otomatik sec
    if (autoAdvance && addresses.length == 1) await _selectAddress(addresses.single);
    _changed();
  }

  Future<void> _selectAddress(Address a) async {
    final devices = await _db.devicesDao.getDevicesForAddress(a.id);
    if (!mounted) return;
    setState(() {
      _address = a;
      _newAddress = false;
      _device = null;
      _newDevice = devices.isEmpty;
    });
    // Tek kombi varsa otomatik sec
    if (devices.length == 1) _selectDevice(devices.single);
    _changed();
  }

  void _selectDevice(Device d) {
    _device = d;
    _newDevice = false;
    _recomputeNext();
    _changed();
  }

  void _changeCustomer() {
    _customer = _address = _device = null;
    _newCustomer = _newAddress = _newDevice = false;
    _changed();
  }

  void _changeAddress() {
    _address = _device = null;
    _newAddress = _newDevice = false;
    _changed();
  }

  void _changeDevice() {
    _device = null;
    _newDevice = false;
    _recomputeNext();
    _changed();
  }

  Timer? _phoneDebounce;

  void _onNewCustomerPhoneChanged(String v) {
    _changed();
    _phoneDebounce?.cancel();
    _phoneDebounce = Timer(const Duration(milliseconds: 300), () async {
      final matches = normalizePhone(v).length < 7 ? const <Customer>[] : await _db.customersDao.findByPhone(v);
      if (mounted && matches.firstOrNull?.id != _duplicate?.id) setState(() => _duplicate = matches.firstOrNull);
    });
  }

  // ---------------------------------------------------------------------------
  // Kaydet
  // ---------------------------------------------------------------------------

  String? get _customerError => _showErrors && _customer == null && !_newCustomer ? S.selectCustomer : null;
  String? get _addressError => _showErrors && _address == null && !_newAddress ? S.selectAddress : null;
  String? get _deviceError => _showErrors && _device == null && !_newDevice ? S.selectDevice : null;
  String? get _typeError => _showErrors && _type == null ? S.selectServiceType : null;

  static double? _parseDouble(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    setState(() => _showErrors = true);
    final formOk = _formKey.currentState!.validate();
    final missing = _customerError ?? _addressError ?? _deviceError ?? _typeError;
    if (!formOk || missing != null) {
      if (missing != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(missing)));
      }
      return;
    }

    setState(() => _saving = true);
    _draftTimer?.cancel();
    final db = _db;
    final type = _type!;
    final periodic = type == ServiceType.maintenance && _periodic;
    final draft = _currentDraft();
    final payment = _isEdit ? 0 : (parseMoney(_payment.text) ?? 0);

    final serviceId = await db.transaction(() async {
      var customerId = _customer?.id;
      customerId ??= await db.customersDao.insertCustomer(name: _ncName.text, phone: _ncPhone.text);
      var addressId = _address?.id;
      addressId ??= await db.customersDao.insertAddress(
        customerId: customerId,
        district: _naDistrict.text,
        neighborhood: _naNeighborhood.text,
        addressLine: _naLine.text,
      );
      var deviceId = _device?.id;
      deviceId ??= await db.devicesDao.insertDevice(
        addressId: addressId,
        brand: _ndBrand.text,
        model: _ndModel.text,
        type: _ndType,
        maintenanceIntervalMonths: _defaultInterval,
      );

      final input = ServiceInput(
        deviceId: deviceId,
        date: _date,
        type: type,
        isPeriodicMaintenance: periodic,
        complaint: _complaint.text,
        errorCode: _errorCode.text,
        workNotes: _workNotes.text,
        checklistItems: type == ServiceType.maintenance
            ? [for (final l in _checklistLabels) if (_checked.contains(l)) l]
            : const [],
        waterPressureBar: _parseDouble(_water.text),
        expansionTankBar: _parseDouble(_expansion.text),
        flueCoPpm: int.tryParse(_co.text.trim()),
        totalAmount: _totalValue,
        appointmentId: _appointmentId,
        parts: [
          for (final p in draft.parts)
            if (p.name.trim().isNotEmpty)
              PartInput(name: p.name, quantity: p.quantityValue, unitPrice: p.unitPriceValue),
        ],
        initialPayment: payment,
        nextMaintenanceDate: !_isEdit && periodic && _nextMaintenance != null
            ? Value(_nextMaintenance)
            : const Value.absent(),
      );
      if (_isEdit) {
        await db.servicesDao.updateService(widget.serviceId!, input);
        return widget.serviceId!;
      }
      return db.servicesDao.insertService(input);
    });

    if (!_isEdit) await _clearDraft();
    if (!mounted) return;

    // Duzenlemede tarih degistiyse sonraki bakim tarihini sor (PLAN 6.1)
    if (_isEdit && periodic && _originalDate != null && !isSameDay(_originalDate!, _date)) {
      await _askUpdateNextMaintenance(db);
      if (!mounted) return;
    }

    _dirty = false;
    final messenger = ScaffoldMessenger.of(context);
    if (_isEdit) {
      context.pop();
    } else {
      context.pushReplacement(Routes.service(serviceId));
    }
    messenger.showSnackBar(const SnackBar(content: Text(S.saved)));
  }

  Future<void> _askUpdateNextMaintenance(AppDatabase db) async {
    final deviceId = _device?.id;
    if (deviceId == null) return;
    final next = computeNextMaintenance(_date, _intervalMonths);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.updateNextMaintenanceTitle),
        content: Text(S.updateNextMaintenanceBody(formatDate(next))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.keep)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(S.update)),
        ],
      ),
    );
    if (ok == true) await db.devicesDao.setNextMaintenanceDate(deviceId, next);
  }

  // ---------------------------------------------------------------------------
  // Geri tusu
  // ---------------------------------------------------------------------------

  Future<void> _onBack() async {
    final navigator = Navigator.of(context);
    if (_isEdit) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(S.discardChangesTitle),
          content: const Text(S.discardChangesBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.stayHere)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(S.discard)),
          ],
        ),
      );
      if (leave == true) {
        _dirty = false;
        navigator.pop();
      }
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.leaveFormTitle),
        content: const Text(S.leaveFormBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'delete'), child: const Text(S.draftDiscard)),
          FilledButton(onPressed: () => Navigator.pop(context, 'keep'), child: const Text(S.keepDraft)),
        ],
      ),
    );
    if (choice == 'keep') {
      await _flushDraft();
    } else if (choice == 'delete') {
      await _clearDraft();
    } else {
      return;
    }
    _dirty = false;
    navigator.pop();
  }

  // ---------------------------------------------------------------------------
  // Arayuz
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_isEdit ? S.editService : S.newService)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    if (_appointmentId != null)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Chip(avatar: Icon(Icons.event_available, size: 18), label: Text(S.appointmentLinked)),
                      ),
                    ..._buildSelection(),
                    ..._buildServiceInfo(),
                    ..._buildParts(),
                    ..._buildFee(),
                    ..._buildNextMaintenance(),
                  ],
                ),
              ),
        bottomNavigationBar: _loading
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: const Text(S.save),
                  ),
                ),
              ),
      ),
    );
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? S.requiredField : null;

  List<Widget> _buildSelection() {
    final widgets = <Widget>[];

    // 1. Musteri
    if (_customer != null) {
      widgets.add(SelectionSummary(
        icon: Icons.person_outline,
        title: _customer!.name,
        subtitle: formatPhone(_customer!.phone),
        onChange: _changeCustomer,
      ));
    } else if (_newCustomer) {
      widgets.addAll([
        _subHeader(S.addNewCustomer, onClose: _changeCustomer),
        TextFormField(
          controller: _ncName,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: S.customerName),
          validator: _required,
          onChanged: (_) => _changed(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ncPhone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: S.phone, prefixIcon: Icon(Icons.phone_outlined)),
          validator: validatePhone,
          onChanged: _onNewCustomerPhoneChanged,
        ),
        if (_duplicate != null)
          Card(
            margin: const EdgeInsets.only(top: 8),
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: ListTile(
              title: Text(S.duplicatePhone(_duplicate!.name)),
              trailing: TextButton(
                onPressed: () => _selectCustomer(_duplicate!.id),
                child: const Text(S.selectThisCustomer),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ]);
    } else {
      return [
        const SectionHeader(title: S.customer),
        CustomerSearch(
          onSelect: (id) => _selectCustomer(id),
          onNew: () {
            _newCustomer = _newAddress = _newDevice = true;
            _changed();
          },
          errorText: _customerError,
        ),
      ];
    }

    // 2. Adres
    if (_address != null) {
      widgets.add(SelectionSummary(
        icon: Icons.location_on_outlined,
        title: addressTitle(_address!),
        subtitle: addressDetail(_address!),
        onChange: _changeAddress,
      ));
    } else if (_newAddress) {
      widgets.addAll([
        _subHeader(S.addNewAddress, onClose: _newCustomer ? null : _changeAddress),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _naDistrict,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: S.district),
                onChanged: (_) => _changed(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _naNeighborhood,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: S.neighborhood),
                onChanged: (_) => _changed(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _naLine,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: S.addressLine, hintText: S.addressLineHint),
          validator: _required,
          onChanged: (_) => _changed(),
        ),
        const SizedBox(height: 16),
      ]);
    } else if (_customer != null) {
      widgets.add(AddressPicker(
        customerId: _customer!.id,
        onSelect: _selectAddress,
        onNew: () {
          _newAddress = _newDevice = true;
          _changed();
        },
        errorText: _addressError,
      ));
      return widgets;
    }

    // 3. Kombi
    if (_device != null) {
      widgets.add(SelectionSummary(
        icon: Icons.local_fire_department_outlined,
        title: deviceTitle(_device!.brand, _device!.model),
        subtitle: _device!.type.label,
        trailing: MaintenanceBadge(nextDate: _device!.nextMaintenanceDate),
        onChange: _changeDevice,
      ));
    } else if (_newDevice) {
      final brands = ref.watch(brandSuggestionsProvider).value ?? S.brandSuggestions;
      widgets.addAll([
        _subHeader(S.addNewDevice, onClose: _newAddress ? null : _changeDevice),
        SuggestionField(
          controller: _ndBrand,
          options: brands,
          label: S.brand,
          validator: _required,
          onChanged: (_) => _changed(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ndModel,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: S.model),
          onChanged: (_) => _changed(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final t in DeviceType.values)
              ChoiceChip(
                label: Text(t.label),
                selected: _ndType == t,
                onSelected: (_) {
                  _ndType = t;
                  _changed();
                },
              ),
          ],
        ),
      ]);
    } else if (_address != null) {
      widgets.add(DevicePicker(
        addressId: _address!.id,
        onSelect: _selectDevice,
        onNew: () {
          _newDevice = true;
          _changed();
        },
        errorText: _deviceError,
      ));
    }
    return widgets;
  }

  Widget _subHeader(String title, {VoidCallback? onClose}) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
            if (onClose != null) IconButton(tooltip: S.cancel, icon: const Icon(Icons.close), onPressed: onClose),
          ],
        ),
      );

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    _date = DateTime(date.year, date.month, date.day, time?.hour ?? _date.hour, time?.minute ?? _date.minute);
    _recomputeNext();
    _changed();
  }

  List<Widget> _buildServiceInfo() {
    final theme = Theme.of(context);
    final isRepair = _type == ServiceType.repair;
    final isMaintenance = _type == ServiceType.maintenance;

    final complaintFields = [
      TextFormField(
        controller: _complaint,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: S.complaint),
        minLines: 1,
        maxLines: 3,
        onChanged: (_) => _changed(),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _errorCode,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: S.errorCode),
        onChanged: (_) => _changed(),
      ),
      const SizedBox(height: 12),
    ];

    return [
      const SectionHeader(title: S.serviceInfo),
      Text(
        _typeError ?? S.serviceType,
        style: theme.textTheme.labelLarge?.copyWith(color: _typeError == null ? null : theme.colorScheme.error),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in ServiceType.values)
            ChoiceChip(
              label: Text(t.label),
              selected: _type == t,
              onSelected: (_) {
                _type = t;
                _periodic = t == ServiceType.maintenance;
                _changed();
              },
            ),
        ],
      ),
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event_outlined),
        title: const Text(S.serviceDate),
        subtitle: Text(formatDateTime(_date)),
        trailing: const Icon(Icons.edit_calendar_outlined),
        onTap: _pickDateTime,
      ),
      // Arizada sikayet ve hata kodu one cikar
      if (isRepair) ...complaintFields,
      if (isMaintenance) ..._buildChecklist(),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text(S.measurements),
        initiallyExpanded: _water.text.isNotEmpty || _expansion.text.isNotEmpty || _co.text.isNotEmpty,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        children: [
          Row(
            children: [
              Expanded(child: _decimalField(_water, S.waterPressure)),
              const SizedBox(width: 12),
              Expanded(child: _decimalField(_expansion, S.expansionTank)),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _co,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: S.flueCo),
            onChanged: (_) => _changed(),
          ),
        ],
      ),
      if (!isRepair) ...complaintFields,
      TextFormField(
        controller: _workNotes,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: S.workNotes),
        minLines: 2,
        maxLines: 6,
        onChanged: (_) => _changed(),
      ),
    ];
  }

  Widget _decimalField(TextEditingController c, String label) => TextFormField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(labelText: label),
        validator: (v) => (v == null || v.trim().isEmpty || _parseDouble(v) != null) ? null : S.invalidNumber,
        onChanged: (_) => _changed(),
      );

  List<Widget> _buildChecklist() {
    final theme = Theme.of(context);
    return [
      Row(
        children: [
          Expanded(child: Text(S.checklist, style: theme.textTheme.titleSmall)),
          TextButton(
            onPressed: () {
              _checked.addAll(_checklistLabels);
              _changed();
            },
            child: const Text(S.selectAll),
          ),
          TextButton(
            onPressed: () {
              _checked.clear();
              _changed();
            },
            child: const Text(S.clearAll),
          ),
        ],
      ),
      for (final label in _checklistLabels)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _checked.contains(label),
          title: Text(label),
          onChanged: (v) {
            v == true ? _checked.add(label) : _checked.remove(label);
            _changed();
          },
        ),
    ];
  }

  List<Widget> _buildParts() {
    final suggestions = ref.watch(partNameSuggestionsProvider).value ?? const <String>[];
    return [
      SectionHeader(
        title: S.parts,
        action: TextButton.icon(
          onPressed: () {
            _parts.add(_PartRow());
            _changed();
          },
          icon: const Icon(Icons.add),
          label: const Text(S.addPart),
        ),
      ),
      for (final (i, p) in _parts.indexed)
        Card(
          key: ObjectKey(p),
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SuggestionField(
                        controller: p.name,
                        options: suggestions,
                        label: S.partName,
                        showAllWhenEmpty: false,
                        onChanged: (_) => _changed(),
                      ),
                    ),
                    IconButton(
                      tooltip: S.removePart,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        _parts.removeAt(i).dispose();
                        _changed();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: p.quantity,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: S.quantity),
                        onChanged: (_) => _changed(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: MoneyField(controller: p.unitPrice, label: S.unitPrice, onChanged: (_) => _changed())),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: Text(formatMoney(p.draft.lineTotal), textAlign: TextAlign.end),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildFee() {
    final draft = _currentDraft();
    final paid = parseMoney(_payment.text) ?? 0;
    return [
      const SectionHeader(title: S.feeAndPayment),
      if (draft.partsTotal > 0)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('${S.partsTotal}: ${formatMoney(draft.partsTotal)}'),
        ),
      const SizedBox(height: 12),
      MoneyField(
        controller: _total,
        label: S.fee,
        onChanged: (_) {
          _totalManual = true;
          _changed();
        },
        suffix: _totalManual
            ? IconButton(
                tooltip: S.autoTotal,
                icon: const Icon(Icons.calculate_outlined),
                onPressed: () {
                  _totalManual = false;
                  _changed();
                },
              )
            : null,
      ),
      if (!_isEdit) ...[
        const SizedBox(height: 16),
        Text(S.paymentReceived, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text(S.payFull),
              selected: _paymentMode == PaymentMode.full,
              onSelected: (_) {
                _paymentMode = PaymentMode.full;
                _changed();
              },
            ),
            ChoiceChip(
              label: const Text(S.payNone),
              selected: _paymentMode == PaymentMode.none,
              onSelected: (_) {
                _paymentMode = PaymentMode.none;
                _changed();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        MoneyField(
          controller: _payment,
          label: S.paymentReceived,
          onChanged: (_) {
            _paymentMode = PaymentMode.custom;
            _changed();
          },
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            final amount = parseMoney(v);
            if (amount == null) return S.invalidAmount;
            return amount > _totalValue ? S.paymentTooHigh : null;
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: PaymentBadge(total: _totalValue, paid: paid),
        ),
      ],
    ];
  }

  List<Widget> _buildNextMaintenance() {
    // Duzenlemede sonraki bakim, kayittan sonra sorulur
    if (_type != ServiceType.maintenance || _isEdit) return const [];
    return [
      const SectionHeader(title: S.nextMaintenance),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(S.periodicMaintenance),
        subtitle: const Text(S.periodicMaintenanceHint),
        value: _periodic,
        onChanged: (v) {
          _periodic = v;
          _changed();
        },
      ),
      if (_periodic)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_repeat_outlined),
          title: Text(_nextMaintenance == null ? S.notSet : formatDateLong(_nextMaintenance!)),
          subtitle: Text(S.intervalMonths(_intervalMonths)),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _nextMaintenance ?? today(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              _nextMaintenance = dateOnly(picked);
              _nextManual = true;
              _changed();
            }
          },
        ),
    ];
  }
}
