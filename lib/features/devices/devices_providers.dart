import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/services_dao.dart';
import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';

final deviceProvider = StreamProvider.autoDispose.family<Device?, String>(
  (ref, id) => ref.watch(databaseProvider).devicesDao.watchDevice(id),
);

final deviceServicesProvider = StreamProvider.autoDispose.family<List<ServiceListItem>, String>(
  (ref, deviceId) => ref.watch(databaseProvider).servicesDao.watchServiceList(deviceId: deviceId),
);

final brandSuggestionsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(databaseProvider).devicesDao.brandSuggestions(),
);
