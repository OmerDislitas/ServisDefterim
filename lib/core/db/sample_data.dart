import 'dart:math';

import 'package:drift/drift.dart';

import '../utils/dates.dart';
import '../utils/maintenance.dart';
import 'daos/services_dao.dart';
import 'database.dart';
import 'search_text.dart';

/// Performans testi icin ornek veri (PLAN 11). Sadece debug build'de kullanilir.
/// ~300 musteri, ~400 adres, ~500 cihaz, ~1.500 servis, ~200 randevu.
class SampleDataGenerator {
  SampleDataGenerator(this.db, {int seed = 42}) : _r = Random(seed);

  final AppDatabase db;
  final Random _r;

  static const _firstNames = [
    'Ahmet', 'Mehmet', 'Mustafa', 'Ali', 'Hüseyin', 'Hasan', 'İbrahim', 'İsmail', 'Osman', 'Yusuf',
    'Murat', 'Ömer', 'Ramazan', 'Halil', 'Süleyman', 'Abdullah', 'Mahmut', 'Recep', 'Şükrü', 'Kadir',
    'Fatma', 'Ayşe', 'Emine', 'Hatice', 'Zeynep', 'Elif', 'Meryem', 'Şerife', 'Zehra', 'Sultan',
    'Hanife', 'Merve', 'Havva', 'Zeliha', 'Esra', 'Fadime', 'Özlem', 'Hacer', 'Gülşen', 'İrem',
  ];
  static const _lastNames = [
    'Yılmaz', 'Kaya', 'Demir', 'Çelik', 'Şahin', 'Yıldız', 'Yıldırım', 'Öztürk', 'Aydın', 'Özdemir',
    'Arslan', 'Doğan', 'Kılıç', 'Aslan', 'Çetin', 'Kara', 'Koç', 'Kurt', 'Özkan', 'Şimşek',
    'Polat', 'Özcan', 'Korkmaz', 'Çakır', 'Erdoğan', 'Yavuz', 'Can', 'Acar', 'Şen', 'Aktaş',
    'Güler', 'Yalçın', 'Güneş', 'Bozkurt', 'Bulut', 'Keskin', 'Ünal', 'Turan', 'Gül', 'Işık',
  ];
  static const _districts = {
    'Başakşehir': ['Kayabaşı', 'Bahçeşehir', 'Altınşehir', 'Güvercintepe'],
    'Esenyurt': ['Fatih', 'Cumhuriyet', 'Pınar', 'Saadetdere'],
    'Küçükçekmece': ['Halkalı', 'Atakent', 'Sefaköy', 'Cennet'],
    'Bağcılar': ['Güneşli', 'Kirazlı', 'Yenimahalle', 'Demirkapı'],
    'Avcılar': ['Ambarlı', 'Cihangir', 'Denizköşkler', 'Firuzköy'],
    'Beylikdüzü': ['Adnan Kahveci', 'Barış', 'Kavaklı', 'Yakuplu'],
    'Sultangazi': ['Cebeci', 'Esentepe', 'Habipler', 'Uğur Mumcu'],
    'Bahçelievler': ['Şirinevler', 'Yenibosna', 'Kocasinan', 'Soğanlı'],
  };
  static const _labels = ['Ev', 'Yazlık', 'İşyeri', 'Annesinin evi'];
  static const _brands = ['Demirdöküm', 'Vaillant', 'Baymak', 'Bosch', 'ECA', 'Buderus', 'Viessmann', 'Ariston'];
  static const _models = ['Nitromix', 'ecoTEC Pro', 'Lambert', 'Condens 2200', 'Proteus Premix', 'Logamax', 'Vitodens 050', 'Clas One'];
  static const _parts = [
    ('Genleşme tankı', 120000),
    ('Pompa', 250000),
    ('Ateşleme elektrodu', 35000),
    ('Fan motoru', 180000),
    ('Üç yollu vana', 140000),
    ('NTC sensörü', 25000),
    ('Basınç şalteri', 45000),
    ('Kart tamiri', 300000),
  ];
  static const _complaints = ['Sıcak su gelmiyor', 'Petekler ısınmıyor', 'Su basıncı düşüyor', 'Kombi sürekli kapanıyor', 'Ses yapıyor'];
  static const _errorCodes = ['F28', 'F29', 'F75', 'E01', 'E133', 'F22', null];

  T _pick<T>(List<T> list) => list[_r.nextInt(list.length)];

  String _phone() => '5${List.generate(9, (_) => _r.nextInt(10)).join()}';

  /// Rastgele kurus tutari, 10 TL'ye yuvarli.
  int _amount(int minLira, int maxLira) => (minLira + _r.nextInt(maxLira - minLira + 1)) ~/ 10 * 1000;

  Future<void> generate({
    int customerCount = 300,
    int extraAddresses = 100,
    int extraDevices = 100,
    int serviceCount = 1500,
    int appointmentCount = 200,
  }) async {
    final now = DateTime.now();
    final todayDate = today(now);
    final checklist = await db.checklistDao.activeLabels();

    final customerRows = <CustomersCompanion>[];
    final customerIds = <String>[];
    for (var i = 0; i < customerCount; i++) {
      final id = newId();
      final name = '${_pick(_firstNames)} ${_pick(_lastNames)}';
      final phone = _phone();
      final phone2 = _r.nextInt(5) == 0 ? _phone() : null;
      customerIds.add(id);
      customerRows.add(CustomersCompanion.insert(
        id: Value(id),
        name: name,
        phone: phone,
        phone2: Value(phone2),
        note: Value(_r.nextInt(8) == 0 ? 'Akşam 18:00 sonrası aranmalı' : null),
        searchText: customerSearchText(name, phone, phone2),
      ));
    }

    // Adresler: her musteriye bir, bazilarina iki
    final addressRows = <AddressesCompanion>[];
    final addressIds = <String>[];
    final addressCustomer = <String, String>{};
    void addAddress(String customerId, String? label) {
      final id = newId();
      final district = _pick(_districts.keys.toList());
      final hood = _pick(_districts[district]!);
      final line = '${_pick(['Gül', 'Lale', 'Menekşe', 'Çınar', 'Akasya', 'Papatya'])} Sk. No:${1 + _r.nextInt(80)}';
      final directions = _r.nextInt(4) == 0 ? 'Market yanı, ${1 + _r.nextInt(5)}. bina' : null;
      addressIds.add(id);
      addressCustomer[id] = customerId;
      addressRows.add(AddressesCompanion.insert(
        id: Value(id),
        customerId: customerId,
        label: Value(label),
        district: Value(district),
        neighborhood: Value(hood),
        addressLine: line,
        floor: Value('${_r.nextInt(8)}'),
        apartmentNo: Value('${1 + _r.nextInt(20)}'),
        directions: Value(directions),
        searchText: addressSearchText(
          label: label,
          district: district,
          neighborhood: hood,
          addressLine: line,
          directions: directions,
        ),
      ));
    }

    for (final c in customerIds) {
      addAddress(c, 'Ev');
    }
    for (var i = 0; i < extraAddresses; i++) {
      addAddress(_pick(customerIds), _pick(_labels.sublist(1)));
    }

    // Cihazlar: her adrese bir, bazilarina iki
    final deviceIds = <String>[];
    final deviceAddress = <String, String>{};
    final deviceMeta = <String, ({String brand, String? model, String? serial, DeviceType type, int? year})>{};
    void addDevice(String addressId) {
      final id = newId();
      final bi = _r.nextInt(_brands.length);
      deviceIds.add(id);
      deviceAddress[id] = addressId;
      deviceMeta[id] = (
        brand: _brands[bi],
        model: _r.nextInt(6) == 0 ? null : _models[bi],
        serial: _r.nextInt(3) == 0 ? null : 'SN${100000 + _r.nextInt(900000)}',
        type: DeviceType.values[_r.nextInt(10) < 7 ? 0 : _r.nextInt(DeviceType.values.length)],
        year: _r.nextInt(4) == 0 ? null : now.year - _r.nextInt(15),
      );
    }

    for (final a in addressIds) {
      addDevice(a);
    }
    for (var i = 0; i < extraDevices; i++) {
      addDevice(_pick(addressIds));
    }

    // Servisler: son 3 yila dagitilmis
    final serviceRows = <ServiceRecordsCompanion>[];
    final partRows = <ServicePartsCompanion>[];
    final paymentRows = <PaymentsCompanion>[];
    final lastPeriodic = <String, DateTime>{};
    for (var i = 0; i < serviceCount; i++) {
      final id = newId();
      final deviceId = _pick(deviceIds);
      final date = now.subtract(Duration(days: _r.nextInt(3 * 365), hours: _r.nextInt(9), minutes: _r.nextInt(60)));
      final roll = _r.nextInt(100);
      final type = roll < 55
          ? ServiceType.maintenance
          : roll < 85
              ? ServiceType.repair
              : roll < 92
                  ? ServiceType.inspection
                  : roll < 97
                      ? ServiceType.installation
                      : ServiceType.other;
      final periodic = type == ServiceType.maintenance;
      if (periodic && (lastPeriodic[deviceId]?.isBefore(date) ?? true)) lastPeriodic[deviceId] = date;

      final parts = <PartInput>[];
      if (type == ServiceType.repair && _r.nextBool()) {
        final p = _pick(_parts);
        parts.add(PartInput(name: p.$1, unitPrice: p.$2));
      }
      final labor = type == ServiceType.maintenance ? _amount(800, 1500) : _amount(500, 2500);
      final total = labor + parts.fold<int>(0, (s, p) => s + p.lineTotal);

      serviceRows.add(ServiceRecordsCompanion.insert(
        id: Value(id),
        deviceId: deviceId,
        date: date,
        type: type,
        isPeriodicMaintenance: Value(periodic),
        complaint: Value(type == ServiceType.repair ? _pick(_complaints) : null),
        errorCode: Value(type == ServiceType.repair ? _pick(_errorCodes) : null),
        workNotes: Value(_r.nextInt(3) == 0 ? 'Kontroller yapıldı, sorun giderildi.' : null),
        checklistItems: Value(periodic ? checklist.where((_) => _r.nextInt(5) > 0).toList() : const []),
        waterPressureBar: Value(periodic ? 1.2 + _r.nextInt(6) / 10 : null),
        totalAmount: Value(total),
      ));
      for (final p in parts) {
        partRows.add(ServicePartsCompanion.insert(serviceId: id, name: p.name, unitPrice: Value(p.unitPrice)));
      }

      // %80 tam odeme, %10 kismi, %10 veresiye
      final pay = _r.nextInt(10);
      final paid = pay < 8 ? total : (pay == 8 ? total ~/ 2 ~/ 1000 * 1000 : 0);
      if (paid > 0) paymentRows.add(PaymentsCompanion.insert(serviceId: id, amount: paid, date: date));
    }

    final deviceRows = <DevicesCompanion>[];
    for (final id in deviceIds) {
      final m = deviceMeta[id]!;
      DateTime? next;
      if (lastPeriodic[id] != null) {
        next = computeNextMaintenance(lastPeriodic[id]!, 12);
      } else if (_r.nextInt(3) > 0) {
        next = addDays(todayDate, -60 + _r.nextInt(240));
      }
      deviceRows.add(DevicesCompanion.insert(
        id: Value(id),
        addressId: deviceAddress[id]!,
        brand: m.brand,
        model: Value(m.model),
        serialNo: Value(m.serial),
        type: m.type,
        installYear: Value(m.year),
        warrantyEnd: Value(m.year != null && m.year! >= now.year - 2 ? DateTime(m.year! + 2, 6, 1) : null),
        maintenanceIntervalMonths: const Value(12),
        nextMaintenanceDate: Value(next),
        lastReminderSentAt: Value(_r.nextInt(10) == 0 ? now.subtract(Duration(days: _r.nextInt(20))) : null),
        searchText: deviceSearchText(m.brand, m.model, m.serial),
      ));
    }

    // Randevular: -30 ile +60 gun arasi, mesai saatlerinde
    final appointmentRows = <AppointmentsCompanion>[];
    for (var i = 0; i < appointmentCount; i++) {
      final deviceId = _pick(deviceIds);
      final customerId = addressCustomer[deviceAddress[deviceId]!]!;
      final day = addDays(todayDate, -30 + _r.nextInt(91));
      final at = DateTime(day.year, day.month, day.day, 9 + _r.nextInt(9), _r.nextBool() ? 0 : 30);
      final status = at.isAfter(now)
          ? AppointmentStatus.planned
          : (_r.nextInt(5) == 0 ? AppointmentStatus.cancelled : AppointmentStatus.done);
      appointmentRows.add(AppointmentsCompanion.insert(
        customerId: customerId,
        deviceId: Value(_r.nextInt(5) == 0 ? null : deviceId),
        scheduledAt: at,
        type: _r.nextInt(3) == 0 ? ServiceType.repair : ServiceType.maintenance,
        status: status,
        note: Value(_r.nextInt(4) == 0 ? 'Öğleden sonra gelinmesi istendi' : null),
      ));
    }

    await db.batch((b) {
      b.insertAll(db.customers, customerRows);
      b.insertAll(db.addresses, addressRows);
      b.insertAll(db.devices, deviceRows);
      b.insertAll(db.serviceRecords, serviceRows);
      b.insertAll(db.serviceParts, partRows);
      b.insertAll(db.payments, paymentRows);
      b.insertAll(db.appointments, appointmentRows);
    });
  }
}
