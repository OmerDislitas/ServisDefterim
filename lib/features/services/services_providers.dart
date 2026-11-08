import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/db_providers.dart';

final serviceProvider = StreamProvider.autoDispose.family<ServiceRecord?, String>(
  (ref, id) => ref.watch(databaseProvider).servicesDao.watchService(id),
);

final servicePartsProvider = StreamProvider.autoDispose.family<List<ServicePart>, String>(
  (ref, id) => ref.watch(databaseProvider).servicesDao.watchParts(id),
);

final servicePaymentsProvider = StreamProvider.autoDispose.family<List<Payment>, String>(
  (ref, id) => ref.watch(databaseProvider).servicesDao.watchPayments(id),
);

final partNameSuggestionsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(databaseProvider).servicesDao.partNameSuggestions(),
);
