import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:servis_defterim/core/db/daos/customers_dao.dart';
import 'package:servis_defterim/core/db/daos/settings_dao.dart';
import 'package:servis_defterim/core/db/database.dart';
import 'package:servis_defterim/core/db/sample_data.dart';
import 'package:servis_defterim/core/services/app_paths.dart';
import 'package:servis_defterim/core/services/backup_service.dart';
import 'package:servis_defterim/core/strings.dart';

void main() {
  late Directory root;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() async => root = await Directory.systemTemp.createTemp('servis_backup_test'));
  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  AppPaths pathsFor(String name) => AppPaths(
        documentsDir: p.join(root.path, name, 'docs'),
        tempDir: p.join(root.path, name, 'tmp'),
      );

  Future<AppDatabase> openFileDb(AppPaths paths) async {
    await Directory(paths.documentsDir).create(recursive: true);
    return AppDatabase(NativeDatabase(File(paths.dbFile)));
  }

  BackupService serviceFor(AppPaths paths) => BackupService(paths: paths, appVersion: '1.0.0+1');

  BackupManifest manifest({String app = BackupService.appId, int schema = 1}) => BackupManifest(
        app: app,
        appVersion: '1.0.0+1',
        schemaVersion: schema,
        createdAt: DateTime(2026, 11, 8, 18, 40),
        counts: const {'customers': 1},
      );

  group('Manifest', () {
    test('doğrulama: uygulama ve şema sürümü', () {
      manifest().validate(currentSchemaVersion: 1);
      expect(
        () => manifest(app: 'baska').validate(currentSchemaVersion: 1),
        throwsA(isA<BackupException>().having((e) => e.message, 'message', S.backupWrongApp)),
      );
      expect(
        () => manifest(schema: 2).validate(currentSchemaVersion: 1),
        throwsA(isA<BackupException>().having((e) => e.message, 'message', S.backupNewerVersion)),
      );
      // Eski sema kabul edilir (acilinca migration calisir)
      manifest(schema: 1).validate(currentSchemaVersion: 3);
    });

    test('JSON gidiş-dönüş, tarih saat dilimiyle yazılır', () {
      final m = manifest();
      final json = m.toJson();
      expect(json['createdAt'], matches(RegExp(r'^2026-11-08T18:40:00[+-]\d\d:\d\d$')));
      final back = BackupManifest.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(back.createdAt, m.createdAt);
      expect(back.count('customers'), 1);
    });

    test('dosya adı alındığı tarih ve saati içerir', () {
      expect(BackupService.fileNameFor(DateTime(2026, 11, 8, 9, 5)), 'servis_defterim_yedek_2026-11-08_0905.zip');
    });
  });

  group('Yedek ve geri yükleme', () {
    test('roundtrip: örnek veri -> zip -> boş veritabanına geri yükle', () async {
      final a = pathsFor('a');
      final dbA = await openFileDb(a);
      await SampleDataGenerator(dbA).generate(
        customerCount: 60,
        extraAddresses: 10,
        extraDevices: 10,
        serviceCount: 150,
        appointmentCount: 20,
      );
      await dbA.settingsDao.setInt(SettingKeys.defaultIntervalMonths, 6);
      await Directory(a.photosDir).create(recursive: true);
      await File(p.join(a.photosDir, 'foto1.jpg')).writeAsBytes([1, 2, 3]);
      final countsA = await dbA.recordCounts();
      final customersA = await dbA.customersDao.watchCustomerList(sort: CustomerSort.name).first;

      final zip = await serviceFor(a).createBackup(dbA, outDir: p.join(root.path, 'out'));
      expect(p.basename(zip.path), startsWith('servis_defterim_yedek_'));
      await dbA.close();

      // Bos ikinci "telefon"
      final b = pathsFor('b');
      final dbB = await openFileDb(b);
      expect((await dbB.recordCounts()).customers, 0);
      final serviceB = serviceFor(b);

      final preview = await serviceB.inspect(zip, currentSchemaVersion: dbB.schemaVersion);
      expect(preview.manifest.count('customers'), countsA.customers);
      expect(preview.manifest.count('services'), countsA.services);

      final restored = await serviceB.restore(
        preview: preview,
        current: dbB,
        reopen: () => AppDatabase(NativeDatabase(File(b.dbFile))),
      );
      final countsB = await restored.recordCounts();
      expect(
        (countsB.customers, countsB.devices, countsB.services, countsB.appointments),
        (countsA.customers, countsA.devices, countsA.services, countsA.appointments),
      );
      final customersB = await restored.customersDao.watchCustomerList(sort: CustomerSort.name).first;
      expect(customersB.map((c) => (c.id, c.name, c.phone)), customersA.map((c) => (c.id, c.name, c.phone)));
      expect(await restored.settingsDao.getInt(SettingKeys.defaultIntervalMonths), 6);
      expect(await restored.settingsDao.getValue(SettingKeys.lastBackupAt), isNotNull);
      expect(File(p.join(b.photosDir, 'foto1.jpg')).readAsBytesSync(), [1, 2, 3]);
      // Guvenlik yedegi alindi
      expect(Directory(b.safetyBackupsDir).listSync(), hasLength(1));
      await restored.close();
    });

    test('geçersiz dosyalar reddedilir', () async {
      final a = pathsFor('a');
      final service = serviceFor(a);
      await Directory(a.tempDir).create(recursive: true);

      final notZip = File(p.join(root.path, 'not.zip'))..writeAsStringSync('merhaba');
      await expectLater(
        service.inspect(notZip, currentSchemaVersion: 1),
        throwsA(isA<BackupException>().having((e) => e.message, 'message', S.backupInvalidFile)),
      );

      // Manifest yok
      final noManifest = File(p.join(root.path, 'nomanifest.zip'));
      final enc = ZipFileEncoder()..create(noManifest.path);
      enc.addArchiveFile(ArchiveFile.bytes('servis_defterim.db', utf8.encode('x')));
      await enc.close();
      await expectLater(service.inspect(noManifest, currentSchemaVersion: 1), throwsA(isA<BackupException>()));

      // Daha yeni sema
      final newer = File(p.join(root.path, 'newer.zip'));
      final enc2 = ZipFileEncoder()..create(newer.path);
      enc2.addArchiveFile(ArchiveFile.bytes('manifest.json', utf8.encode(jsonEncode(manifest(schema: 9).toJson()))));
      await enc2.close();
      await expectLater(
        service.inspect(newer, currentSchemaVersion: 1),
        throwsA(isA<BackupException>().having((e) => e.message, 'message', S.backupNewerVersion)),
      );
    });

    test('zip içinden klasör dışına yazılamaz', () async {
      final a = pathsFor('a');
      await Directory(a.tempDir).create(recursive: true);
      final evil = File(p.join(root.path, 'evil.zip'));
      final enc = ZipFileEncoder()..create(evil.path);
      enc.addArchiveFile(ArchiveFile.bytes('manifest.json', utf8.encode(jsonEncode(manifest().toJson()))));
      enc.addArchiveFile(ArchiveFile.bytes('../../kotu.txt', utf8.encode('x')));
      enc.addArchiveFile(ArchiveFile.bytes('photos/../../kotu2.txt', utf8.encode('x')));
      await enc.close();

      // Veritabani yok -> gecersiz; ama hicbir dosya disari yazilmamis olmali
      await expectLater(serviceFor(a).inspect(evil, currentSchemaVersion: 1), throwsA(isA<BackupException>()));
      final escaped = root.listSync(recursive: true).where((f) => p.basename(f.path).startsWith('kotu'));
      expect(escaped, isEmpty);
    });

    test('güvenlik yedeklerinden son 3 tanesi tutulur', () async {
      final a = pathsFor('a');
      final db = await openFileDb(a);
      final service = serviceFor(a);
      for (var i = 0; i < 5; i++) {
        final f = await service.createSafetyBackup(db);
        // Ayni dakikada ayni ad olusmasin
        await f.rename(p.join(p.dirname(f.path), 'yedek_$i.zip'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await service.createSafetyBackup(db);
      expect(Directory(a.safetyBackupsDir).listSync(), hasLength(3));
      await db.close();
    });
  });

  test('veri değişince lastLocalChangeAt yazılır, ayar değişikliği saymaz', () async {
    final db = AppDatabase(NativeDatabase.memory())..startChangeTracking();
    // Ilk acilistaki seed (checklist) bir degisiklik sayilir; olcume ondan sonra basla
    await db.recordCounts();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.settingsDao.setValue(SettingKeys.lastLocalChangeAt, null);
    await db.settingsDao.setValue(SettingKeys.serviceDraft, '{}');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await db.settingsDao.getValue(SettingKeys.lastLocalChangeAt), isNull);

    await db.customersDao.insertCustomer(name: 'Ali', phone: '05001112233');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await db.settingsDao.getValue(SettingKeys.lastLocalChangeAt), isNotNull);
    await db.close();
  });
}
