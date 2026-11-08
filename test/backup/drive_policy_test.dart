import 'package:flutter_test/flutter_test.dart';
import 'package:servis_defterim/core/services/drive_service.dart';
import 'package:servis_defterim/features/settings/backup_actions.dart';

void main() {
  group('Otomatik Drive yedeği koşulları', () {
    final now = DateTime(2026, 11, 8, 12);

    bool check({
      bool enabled = true,
      bool connected = true,
      DateTime? lastDrive,
      DateTime? lastChange,
      DateTime? lastBackup,
    }) =>
        shouldAutoBackup(
          enabled: enabled,
          connected: connected,
          now: now,
          lastDriveBackup: lastDrive,
          lastLocalChange: lastChange,
          lastBackup: lastBackup,
        );

    final yesterday = now.subtract(const Duration(hours: 25));
    final change = now.subtract(const Duration(hours: 1));

    test('tüm koşullar sağlanınca yedek alınır', () {
      expect(check(lastDrive: yesterday, lastChange: change, lastBackup: yesterday), isTrue);
      expect(check(lastChange: change), isTrue); // hic yedek yok
    });

    test('kapalıysa ya da bağlı değilse alınmaz', () {
      expect(check(enabled: false, lastChange: change), isFalse);
      expect(check(connected: false, lastChange: change), isFalse);
    });

    test('son Drive yedeği 24 saatten yeniyse alınmaz', () {
      final recent = now.subtract(const Duration(hours: 5));
      expect(check(lastDrive: recent, lastChange: change, lastBackup: recent), isFalse);
    });

    test('son yedekten sonra veri değişmediyse alınmaz', () {
      expect(check(lastDrive: yesterday, lastChange: yesterday.subtract(const Duration(hours: 1)), lastBackup: yesterday),
          isFalse);
      expect(check(lastDrive: yesterday), isFalse); // hic degisiklik yok
      // Elle disa aktarma da "son yedek" sayilir
      final manual = now.subtract(const Duration(minutes: 10));
      expect(check(lastDrive: yesterday, lastChange: change, lastBackup: manual), isFalse);
    });
  });

  test('Drive\'da en yeni 15 yedek kalır', () {
    final files = [
      for (var i = 0; i < 20; i++)
        DriveBackupFile(id: 'f$i', name: 'y$i.zip', createdAt: DateTime(2026, 1, 1).add(Duration(days: i))),
    ]..shuffle();
    final prune = filesToPrune(files, 15);
    expect(prune.map((f) => f.id).toSet(), {'f0', 'f1', 'f2', 'f3', 'f4'});
    expect(filesToPrune(files.take(10).toList(), 15), isEmpty);
  });

  test('dosya boyutu biçimi', () {
    expect(formatFileSize(500), '1 KB');
    expect(formatFileSize(2411724), '2,3 MB');
  });
}
