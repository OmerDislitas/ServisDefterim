import 'package:flutter_test/flutter_test.dart';
import 'package:servis_defterim/core/db/daos/services_dao.dart';
import 'package:servis_defterim/core/db/database.dart';

import 'test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDb());
  tearDown(() => db.close());

  test('servis güncelleme parçaları değiştirir, ödemeler korunur', () async {
    final a = await createCustomerWithDevice(db);
    final id = await db.servicesDao.insertService(ServiceInput(
      deviceId: a.deviceId,
      date: DateTime(2026, 10, 1),
      type: ServiceType.repair,
      totalAmount: 50000,
      initialPayment: 20000,
      parts: const [PartInput(name: 'Pompa', unitPrice: 30000)],
    ));

    await db.servicesDao.updateService(
      id,
      ServiceInput(
        deviceId: a.deviceId,
        date: DateTime(2026, 10, 2),
        type: ServiceType.repair,
        complaint: 'Ses yapıyor',
        laborFee: 10000,
        totalAmount: 70000,
        parts: const [PartInput(name: 'Fan', quantity: 2, unitPrice: 30000)],
      ),
    );

    final s = await db.servicesDao.getService(id);
    expect(s!.date, DateTime(2026, 10, 2));
    expect(s.complaint, 'Ses yapıyor');
    expect(s.totalAmount, 70000);
    final parts = await db.servicesDao.getParts(id);
    expect(parts.map((p) => (p.name, p.quantity)), [('Fan', 2)]);
    expect(await db.servicesDao.watchPayments(id).first, hasLength(1));
  });

  test('önceki periyodik bakım tarihi, silinen kayıt hariç bulunur', () async {
    final a = await createCustomerWithDevice(db);
    Future<String> svc(DateTime date, {bool periodic = true}) => db.servicesDao.insertService(ServiceInput(
          deviceId: a.deviceId,
          date: date,
          type: periodic ? ServiceType.maintenance : ServiceType.repair,
          isPeriodicMaintenance: periodic,
          totalAmount: 0,
        ));
    await svc(DateTime(2024, 11, 1));
    await svc(DateTime(2025, 3, 1), periodic: false);
    final last = await svc(DateTime(2025, 11, 1));

    expect(await db.servicesDao.latestPeriodicServiceDate(a.deviceId), DateTime(2025, 11, 1));
    expect(await db.servicesDao.latestPeriodicServiceDate(a.deviceId, excludeId: last), DateTime(2024, 11, 1));
  });
}
