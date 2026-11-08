import 'package:drift/drift.dart';

import '../../utils/phone.dart';
import '../../utils/text_normalize.dart';
import '../database.dart';
import '../search_text.dart';
import '../tables/tables.dart';

part 'customers_dao.g.dart';

enum CustomerSort { lastService, name }

/// Musteri listesi satiri (tek sorguda, N+1 yok).
class CustomerListItem {
  const CustomerListItem({
    required this.id,
    required this.name,
    required this.phone,
    this.district,
    this.neighborhood,
    required this.deviceCount,
    this.lastServiceAt,
  });

  final String id;
  final String name;
  final String phone;
  final String? district;
  final String? neighborhood;
  final int deviceCount;
  final DateTime? lastServiceAt;
}

String? _clean(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

@DriftAccessor(tables: [Customers, Addresses, Devices, ServiceRecords])
class CustomersDao extends DatabaseAccessor<AppDatabase> with _$CustomersDaoMixin {
  CustomersDao(super.attachedDatabase);

  // --- Musteri -------------------------------------------------------------

  Future<String> insertCustomer({
    required String name,
    required String phone,
    String? phone2,
    String? note,
  }) async {
    final p = normalizePhone(phone);
    final p2 = _clean(phone2) == null ? null : normalizePhone(phone2!);
    final row = await into(customers).insertReturning(CustomersCompanion.insert(
      name: name.trim(),
      phone: p,
      phone2: Value(p2),
      note: Value(_clean(note)),
      searchText: customerSearchText(name, p, p2),
    ));
    return row.id;
  }

  Future<void> updateCustomer(
    String id, {
    required String name,
    required String phone,
    String? phone2,
    String? note,
  }) {
    final p = normalizePhone(phone);
    final p2 = _clean(phone2) == null ? null : normalizePhone(phone2!);
    return (update(customers)..where((t) => t.id.equals(id))).write(CustomersCompanion(
      name: Value(name.trim()),
      phone: Value(p),
      phone2: Value(p2),
      note: Value(_clean(note)),
      searchText: Value(customerSearchText(name, p, p2)),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Stream<Customer?> watchCustomer(String id) =>
      (select(customers)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).watchSingleOrNull();

  Future<Customer?> getCustomer(String id) =>
      (select(customers)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();

  /// Ayni numarali musteri uyarisi icin (PLAN 7.6).
  Future<List<Customer>> findByPhone(String phone) {
    final p = normalizePhone(phone);
    if (p.isEmpty) return Future.value(const []);
    return (select(customers)
          ..where((t) => t.deletedAt.isNull() & (t.phone.equals(p) | t.phone2.equals(p))))
        .get();
  }

  /// Arama + liste (PLAN 6.4, 7.3). Musteri adi, telefon, adres, cihaz marka/model/seri no
  /// alanlarinda arar; sonuclar musteri bazinda doner.
  Stream<List<CustomerListItem>> watchCustomerList({
    String query = '',
    CustomerSort sort = CustomerSort.lastService,
  }) {
    final term = normalizeForSearch(query);
    final vars = <Variable>[];
    var where = 'c.deleted_at IS NULL';

    if (term.isNotEmpty) {
      final like = '%${escapeLike(term)}%';
      final conditions = [
        r"c.search_text LIKE ? ESCAPE '\'",
        'EXISTS (SELECT 1 FROM addresses a WHERE a.customer_id = c.id AND a.deleted_at IS NULL '
            r"AND a.search_text LIKE ? ESCAPE '\')",
        'EXISTS (SELECT 1 FROM devices d JOIN addresses a ON a.id = d.address_id '
            'WHERE a.customer_id = c.id AND a.deleted_at IS NULL AND d.deleted_at IS NULL '
            r"AND d.search_text LIKE ? ESCAPE '\')",
      ];
      vars.addAll([Variable(like), Variable(like), Variable(like)]);

      final digits = phoneSearchDigits(query);
      if (digits.length >= 3) {
        conditions.addAll(['c.phone LIKE ?', 'c.phone2 LIKE ?']);
        vars.addAll([Variable('%$digits%'), Variable('%$digits%')]);
      }
      where += ' AND (${conditions.join(' OR ')})';
    }

    final orderBy = switch (sort) {
      CustomerSort.lastService => 'last_service_at IS NULL, last_service_at DESC, c.search_text',
      CustomerSort.name => 'c.search_text',
    };

    return customSelect(
      '''
SELECT c.id, c.name, c.phone, fa.district, fa.neighborhood,
  (SELECT COUNT(*) FROM devices d JOIN addresses a ON a.id = d.address_id
     WHERE a.customer_id = c.id AND a.deleted_at IS NULL AND d.deleted_at IS NULL) AS device_count,
  (SELECT MAX(s.date) FROM service_records s
     JOIN devices d ON d.id = s.device_id
     JOIN addresses a ON a.id = d.address_id
     WHERE a.customer_id = c.id AND s.deleted_at IS NULL) AS last_service_at
FROM customers c
LEFT JOIN addresses fa ON fa.id = (
  SELECT a.id FROM addresses a WHERE a.customer_id = c.id AND a.deleted_at IS NULL
  ORDER BY a.created_at, a.id LIMIT 1)
WHERE $where
ORDER BY $orderBy
''',
      variables: vars,
      readsFrom: {customers, addresses, devices, serviceRecords},
    ).watch().map((rows) => [
          for (final r in rows)
            CustomerListItem(
              id: r.read<String>('id'),
              name: r.read<String>('name'),
              phone: r.read<String>('phone'),
              district: r.readNullable<String>('district'),
              neighborhood: r.readNullable<String>('neighborhood'),
              deviceCount: r.read<int>('device_count'),
              lastServiceAt: r.readNullable<DateTime>('last_service_at'),
            ),
        ]);
  }

  // --- Adres ---------------------------------------------------------------

  Future<String> insertAddress({
    required String customerId,
    String? label,
    String? district,
    String? neighborhood,
    required String addressLine,
    String? floor,
    String? apartmentNo,
    String? directions,
  }) async {
    final row = await into(addresses).insertReturning(AddressesCompanion.insert(
      customerId: customerId,
      label: Value(_clean(label)),
      district: Value(_clean(district)),
      neighborhood: Value(_clean(neighborhood)),
      addressLine: addressLine.trim(),
      floor: Value(_clean(floor)),
      apartmentNo: Value(_clean(apartmentNo)),
      directions: Value(_clean(directions)),
      searchText: addressSearchText(
        label: label,
        district: district,
        neighborhood: neighborhood,
        addressLine: addressLine,
        directions: directions,
      ),
    ));
    return row.id;
  }

  Future<void> updateAddress(
    String id, {
    String? label,
    String? district,
    String? neighborhood,
    required String addressLine,
    String? floor,
    String? apartmentNo,
    String? directions,
  }) =>
      (update(addresses)..where((t) => t.id.equals(id))).write(AddressesCompanion(
        label: Value(_clean(label)),
        district: Value(_clean(district)),
        neighborhood: Value(_clean(neighborhood)),
        addressLine: Value(addressLine.trim()),
        floor: Value(_clean(floor)),
        apartmentNo: Value(_clean(apartmentNo)),
        directions: Value(_clean(directions)),
        searchText: Value(addressSearchText(
          label: label,
          district: district,
          neighborhood: neighborhood,
          addressLine: addressLine,
          directions: directions,
        )),
        updatedAt: Value(DateTime.now()),
      ));

  SimpleSelectStatement<$AddressesTable, Address> _addressesOf(String customerId) => select(addresses)
    ..where((t) => t.customerId.equals(customerId) & t.deletedAt.isNull())
    ..orderBy([(t) => OrderingTerm.asc(t.createdAt), (t) => OrderingTerm.asc(t.id)]);

  Stream<List<Address>> watchAddresses(String customerId) => _addressesOf(customerId).watch();

  Future<List<Address>> getAddresses(String customerId) => _addressesOf(customerId).get();

  Stream<Address?> watchAddress(String id) =>
      (select(addresses)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).watchSingleOrNull();

  Future<Address?> getAddress(String id) =>
      (select(addresses)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
}
