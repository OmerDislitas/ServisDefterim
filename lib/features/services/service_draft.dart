import 'dart:convert';

import '../../core/utils/money.dart';

/// Parca satiri (form metinleri olarak).
class PartDraft {
  const PartDraft({this.name = '', this.quantity = '1', this.unitPrice = ''});

  final String name;
  final String quantity;
  final String unitPrice;

  int get quantityValue => int.tryParse(quantity.trim()) ?? 1;
  int get unitPriceValue => parseMoney(unitPrice) ?? 0;
  int get lineTotal => quantityValue * unitPriceValue;

  Map<String, dynamic> toJson() => {'name': name, 'quantity': quantity, 'unitPrice': unitPrice};

  factory PartDraft.fromJson(Map<String, dynamic> j) => PartDraft(
        name: j['name'] as String? ?? '',
        quantity: j['quantity'] as String? ?? '1',
        unitPrice: j['unitPrice'] as String? ?? '',
      );
}

enum PaymentMode { custom, full, none }

/// Yeni servis formunun tam durumu. Otomatik taslak olarak JSON'a yazilir (PLAN 7.6),
/// boylece uygulama kapansa ya da telefon gelse bile veri kaybolmaz.
class ServiceDraft {
  const ServiceDraft({
    this.customerId,
    this.addressId,
    this.deviceId,
    this.appointmentId,
    this.newCustomer = false,
    this.newCustomerName = '',
    this.newCustomerPhone = '',
    this.newAddress = false,
    this.newAddressDistrict = '',
    this.newAddressNeighborhood = '',
    this.newAddressLine = '',
    this.newDevice = false,
    this.newDeviceBrand = '',
    this.newDeviceModel = '',
    this.newDeviceType = 'condensing',
    this.type,
    required this.date,
    this.complaint = '',
    this.errorCode = '',
    this.workNotes = '',
    this.waterPressure = '',
    this.expansionTank = '',
    this.flueCo = '',
    this.checklist = const [],
    this.parts = const [],
    this.laborFee = '',
    this.total = '',
    this.totalManual = false,
    this.payment = '',
    this.paymentMode = PaymentMode.custom,
    this.periodic = true,
    this.nextMaintenance,
    this.nextMaintenanceManual = false,
  });

  final String? customerId;
  final String? addressId;
  final String? deviceId;
  final String? appointmentId;
  final bool newCustomer;
  final String newCustomerName;
  final String newCustomerPhone;
  final bool newAddress;
  final String newAddressDistrict;
  final String newAddressNeighborhood;
  final String newAddressLine;
  final bool newDevice;
  final String newDeviceBrand;
  final String newDeviceModel;
  final String newDeviceType;
  final String? type;
  final DateTime date;
  final String complaint;
  final String errorCode;
  final String workNotes;
  final String waterPressure;
  final String expansionTank;
  final String flueCo;
  final List<String> checklist;
  final List<PartDraft> parts;
  final String laborFee;
  final String total;
  final bool totalManual;
  final String payment;
  final PaymentMode paymentMode;
  final bool periodic;
  final DateTime? nextMaintenance;
  final bool nextMaintenanceManual;

  int get partsTotal => parts.fold(0, (sum, p) => sum + p.lineTotal);

  /// Parca toplami + iscilik (kurus).
  int get autoTotal => partsTotal + (parseMoney(laborFee) ?? 0);

  Map<String, dynamic> toJson() => {
        'v': 1,
        'customerId': customerId,
        'addressId': addressId,
        'deviceId': deviceId,
        'appointmentId': appointmentId,
        'newCustomer': newCustomer,
        'newCustomerName': newCustomerName,
        'newCustomerPhone': newCustomerPhone,
        'newAddress': newAddress,
        'newAddressDistrict': newAddressDistrict,
        'newAddressNeighborhood': newAddressNeighborhood,
        'newAddressLine': newAddressLine,
        'newDevice': newDevice,
        'newDeviceBrand': newDeviceBrand,
        'newDeviceModel': newDeviceModel,
        'newDeviceType': newDeviceType,
        'type': type,
        'date': date.toIso8601String(),
        'complaint': complaint,
        'errorCode': errorCode,
        'workNotes': workNotes,
        'waterPressure': waterPressure,
        'expansionTank': expansionTank,
        'flueCo': flueCo,
        'checklist': checklist,
        'parts': [for (final p in parts) p.toJson()],
        'laborFee': laborFee,
        'total': total,
        'totalManual': totalManual,
        'payment': payment,
        'paymentMode': paymentMode.name,
        'periodic': periodic,
        'nextMaintenance': nextMaintenance?.toIso8601String(),
        'nextMaintenanceManual': nextMaintenanceManual,
      };

  factory ServiceDraft.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k] as String? ?? '';
    bool b(String k, [bool d = false]) => j[k] as bool? ?? d;
    return ServiceDraft(
      customerId: j['customerId'] as String?,
      addressId: j['addressId'] as String?,
      deviceId: j['deviceId'] as String?,
      appointmentId: j['appointmentId'] as String?,
      newCustomer: b('newCustomer'),
      newCustomerName: s('newCustomerName'),
      newCustomerPhone: s('newCustomerPhone'),
      newAddress: b('newAddress'),
      newAddressDistrict: s('newAddressDistrict'),
      newAddressNeighborhood: s('newAddressNeighborhood'),
      newAddressLine: s('newAddressLine'),
      newDevice: b('newDevice'),
      newDeviceBrand: s('newDeviceBrand'),
      newDeviceModel: s('newDeviceModel'),
      newDeviceType: j['newDeviceType'] as String? ?? 'condensing',
      type: j['type'] as String?,
      date: DateTime.tryParse(s('date')) ?? DateTime.now(),
      complaint: s('complaint'),
      errorCode: s('errorCode'),
      workNotes: s('workNotes'),
      waterPressure: s('waterPressure'),
      expansionTank: s('expansionTank'),
      flueCo: s('flueCo'),
      checklist: (j['checklist'] as List? ?? const []).cast<String>(),
      parts: [for (final p in (j['parts'] as List? ?? const [])) PartDraft.fromJson(p as Map<String, dynamic>)],
      laborFee: s('laborFee'),
      total: s('total'),
      totalManual: b('totalManual'),
      payment: s('payment'),
      paymentMode: PaymentMode.values.asNameMap()[j['paymentMode']] ?? PaymentMode.custom,
      periodic: b('periodic', true),
      nextMaintenance: DateTime.tryParse(s('nextMaintenance')),
      nextMaintenanceManual: b('nextMaintenanceManual'),
    );
  }

  String encode() => jsonEncode(toJson());

  /// Bozuk ya da eski bicimli taslakta null.
  static ServiceDraft? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return ServiceDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
