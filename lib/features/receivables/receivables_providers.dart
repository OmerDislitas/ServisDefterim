import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/services_dao.dart';
import '../../core/db/db_providers.dart';

final receivablesProvider = StreamProvider.autoDispose<List<ReceivableCustomer>>(
  (ref) => ref.watch(databaseProvider).servicesDao.watchReceivables(),
);

final totalReceivableProvider = StreamProvider.autoDispose<int>(
  (ref) => ref.watch(databaseProvider).servicesDao.watchTotalReceivable(),
);

/// Bir musterinin borclu servisleri, en eski once.
final debtServicesProvider = StreamProvider.autoDispose.family<List<ServiceListItem>, String>(
  (ref, customerId) => ref.watch(databaseProvider).servicesDao.watchDebtServices(customerId),
);
