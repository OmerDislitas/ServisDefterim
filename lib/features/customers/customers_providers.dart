import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/customers_dao.dart';
import '../../core/db/daos/services_dao.dart';
import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';

typedef CustomerListQuery = ({String query, CustomerSort sort});

final customerListProvider = StreamProvider.autoDispose.family<List<CustomerListItem>, CustomerListQuery>(
  (ref, q) => ref.watch(databaseProvider).customersDao.watchCustomerList(query: q.query, sort: q.sort),
);

final customerProvider = StreamProvider.autoDispose.family<Customer?, String>(
  (ref, id) => ref.watch(databaseProvider).customersDao.watchCustomer(id),
);

final addressesProvider = StreamProvider.autoDispose.family<List<Address>, String>(
  (ref, customerId) => ref.watch(databaseProvider).customersDao.watchAddresses(customerId),
);

final addressProvider = StreamProvider.autoDispose.family<Address?, String>(
  (ref, id) => ref.watch(databaseProvider).customersDao.watchAddress(id),
);

final devicesForAddressProvider = StreamProvider.autoDispose.family<List<Device>, String>(
  (ref, addressId) => ref.watch(databaseProvider).devicesDao.watchDevicesForAddress(addressId),
);

final customerServicesProvider = StreamProvider.autoDispose.family<List<ServiceListItem>, String>(
  (ref, customerId) => ref.watch(databaseProvider).servicesDao.watchServiceList(customerId: customerId),
);

/// Musterinin toplam alacagi (kurus).
final customerDebtProvider = StreamProvider.autoDispose.family<int, String>(
  (ref, customerId) => ref
      .watch(databaseProvider)
      .servicesDao
      .watchDebtServices(customerId)
      .map((list) => list.fold<int>(0, (sum, s) => sum + s.remaining)),
);
