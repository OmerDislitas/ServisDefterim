import 'package:drift/drift.dart';

import '../../strings.dart';
import '../database.dart';
import '../tables/tables.dart';

part 'settings_dao.g.dart';

abstract final class SettingKeys {
  static const defaultIntervalMonths = 'defaultIntervalMonths';
  static const notificationHour = 'notificationHour';
  static const remindDaysBefore = 'remindDaysBefore';
  static const whatsappTemplate = 'whatsappTemplate';
  static const driveAutoBackup = 'driveAutoBackup';
  static const driveAccountEmail = 'driveAccountEmail';
  static const lastBackupAt = 'lastBackupAt';
  static const lastLocalChangeAt = 'lastLocalChangeAt';

  /// Yarim kalan yeni servis formu (JSON). Bkz. ServiceDraft.
  static const serviceDraft = 'serviceDraft';

  /// Veritabani ilk olusturulurken yazilan degerler.
  static const defaults = {
    defaultIntervalMonths: '12',
    notificationHour: '9',
    remindDaysBefore: '3',
    whatsappTemplate: S.defaultWhatsappTemplate,
    driveAutoBackup: 'false',
  };
}

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  SimpleSelectStatement<$AppSettingsTable, AppSetting> _byKey(String key) =>
      select(appSettings)..where((t) => t.key.equals(key));

  Future<String?> getValue(String key) async =>
      (await _byKey(key).getSingleOrNull())?.value ?? SettingKeys.defaults[key];

  Stream<String?> watchValue(String key) =>
      _byKey(key).watchSingleOrNull().map((r) => r?.value ?? SettingKeys.defaults[key]);

  /// null deger anahtari siler.
  Future<void> setValue(String key, String? value) async {
    if (value == null) {
      await (delete(appSettings)..where((t) => t.key.equals(key))).go();
    } else {
      await into(appSettings).insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));
    }
  }

  Future<int> getInt(String key) async => int.tryParse(await getValue(key) ?? '') ?? 0;

  Future<bool> getBool(String key) async => (await getValue(key)) == 'true';

  Future<void> setInt(String key, int value) => setValue(key, '$value');

  Future<void> setBool(String key, bool value) => setValue(key, '$value');
}
