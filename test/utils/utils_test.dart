import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:servis_defterim/core/strings.dart';
import 'package:servis_defterim/core/utils/dates.dart';
import 'package:servis_defterim/core/utils/maintenance.dart';
import 'package:servis_defterim/core/utils/money.dart';
import 'package:servis_defterim/core/utils/payment.dart';
import 'package:servis_defterim/core/utils/phone.dart';
import 'package:servis_defterim/core/utils/text_normalize.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  group('Türkçe arama normalizasyonu', () {
    test('Türkçe büyük/küçük harf ve aksanlar', () {
      expect(normalizeForSearch('Şükrü ÖZTÜRK'), 'sukru ozturk');
      expect(normalizeForSearch('IŞIK'), 'isik');
      expect(normalizeForSearch('İsmail'), 'ismail');
      expect(normalizeForSearch('ÇAĞLAR Güneş'), 'caglar gunes');
      expect(normalizeForSearch('  Ali   Veli  '), 'ali veli');
      expect(normalizeForSearch(null), '');
    });

    test('turkishLower I ve İ ayrımını yapar', () {
      expect(turkishLower('IRMAK'), 'ırmak');
      expect(turkishLower('İZMİR'), 'izmir');
    });

    test('buildSearchText boş alanları atlar', () {
      expect(buildSearchText(['Demirdöküm', null, '', 'SN123']), 'demirdokum sn123');
    });

    test('escapeLike özel karakterleri kaçırır', () {
      expect(escapeLike(r'50%_a\b'), r'50\%\_a\\b');
    });
  });

  group('Telefon', () {
    test('farklı girişler aynı forma normalize edilir', () {
      expect(normalizePhone('0532 123 45 67'), '5321234567');
      expect(normalizePhone('+90 532 123 45 67'), '5321234567');
      expect(normalizePhone('905321234567'), '5321234567');
      expect(normalizePhone('0090 (532) 123-45-67'), '5321234567');
      expect(normalizePhone('532 123 45 67'), '5321234567');
    });

    test('gösterim formatı', () {
      expect(formatPhone('5321234567'), '0532 123 45 67');
      expect(formatPhone('12345'), '12345');
    });

    test('arama terimi rakamları', () {
      expect(phoneSearchDigits('0532 12'), '53212');
      expect(phoneSearchDigits('+90 532'), '532');
      expect(phoneSearchDigits('Ahmet'), '');
    });

    test('tel ve WhatsApp linkleri', () {
      expect(telUri('5321234567').toString(), 'tel:05321234567');
      expect(whatsappUri('5321234567').toString(), 'https://wa.me/905321234567');
      expect(
        whatsappUri('5321234567', message: 'Merhaba Ali, bakım?').toString(),
        'https://wa.me/905321234567?text=Merhaba%20Ali%2C%20bak%C4%B1m%3F',
      );
    });

    test('WhatsApp şablonu doldurulur', () {
      final msg = fillWhatsappTemplate(S.defaultWhatsappTemplate, name: 'Ahmet Bey', brand: 'Vaillant');
      expect(msg, startsWith('Merhaba Ahmet Bey, kombinizin (Vaillant) yıllık bakım'));
      expect(fillWhatsappTemplate('{ad} {marka} {tarih}', name: 'A', date: '8 Kasım'), 'A  8 Kasım');
    });
  });

  group('Para (kuruş)', () {
    test('formatlama', () {
      expect(formatMoney(125000), '1.250,00 ₺');
      expect(formatMoney(5), '0,05 ₺');
      expect(formatMoney(123456789), '1.234.567,89 ₺');
      expect(formatMoney(-1500), '-15,00 ₺');
      expect(formatMoney(0), '0,00 ₺');
    });

    test('ayrıştırma', () {
      expect(parseMoney('1.250,50'), 125050);
      expect(parseMoney('1250'), 125000);
      expect(parseMoney('1250,5'), 125050);
      expect(parseMoney('1250.5'), 125050);
      expect(parseMoney('1.250'), 125000);
      expect(parseMoney('1.250.000'), 125000000);
      expect(parseMoney('750 ₺'), 75000);
      expect(parseMoney(',50'), 50);
      expect(parseMoney(''), isNull);
      expect(parseMoney('abc'), isNull);
      expect(parseMoney('12,345'), isNull);
    });

    test('form alanı biçimi geri ayrıştırılabilir', () {
      for (final k in [0, 5, 125000, 125050, 99999]) {
        expect(parseMoney(kurusToInput(k)), k);
      }
    });
  });

  group('Tarih', () {
    test('date key dönüşümü', () {
      expect(toDateKey(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
      expect(parseDateKey('2026-03-05'), DateTime(2026, 3, 5));
    });

    test('ay ekleme ayın son gününe sabitlenir', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(addMonths(DateTime(2026, 11, 8), 12), DateTime(2027, 11, 8));
      expect(addMonths(DateTime(2026, 11, 8), 3), DateTime(2027, 2, 8));
      expect(addMonths(DateTime(2026, 2, 15), -3), DateTime(2025, 11, 15));
    });

    test('Türkçe tarih formatları', () {
      expect(formatDateLong(DateTime(2026, 11, 8)), '8 Kasım 2026, Pazar');
      expect(formatDateTime(DateTime(2026, 11, 8, 18, 40)), '8 Kasım 2026, 18:40');
    });

    test('göreli gün', () {
      final now = DateTime(2026, 11, 8, 10);
      expect(relativeDay(DateTime(2026, 11, 8, 23), now: now), 'bugün');
      expect(relativeDay(DateTime(2026, 11, 7), now: now), 'dün');
      expect(relativeDay(DateTime(2026, 11, 5), now: now), '3 gün önce');
      expect(relativeDay(DateTime(2026, 11, 13), now: now), '5 gün sonra');
    });
  });

  group('Bakım', () {
    final t = DateTime(2026, 11, 8);

    test('sonraki bakım tarihi = servis tarihi + periyot', () {
      expect(computeNextMaintenance(DateTime(2026, 11, 8, 15, 30), 12), DateTime(2027, 11, 8));
      expect(computeNextMaintenance(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
    });

    test('bakım durumu', () {
      expect(maintenanceStatus(null, t), MaintenanceStatus.unknown);
      expect(maintenanceStatus(DateTime(2026, 11, 7), t), MaintenanceStatus.overdue);
      expect(maintenanceStatus(t, t), MaintenanceStatus.thisWeek);
      expect(maintenanceStatus(DateTime(2026, 11, 15), t), MaintenanceStatus.thisWeek);
      expect(maintenanceStatus(DateTime(2026, 11, 16), t), MaintenanceStatus.upcoming);
      expect(maintenanceStatus(DateTime(2026, 12, 8), t), MaintenanceStatus.upcoming);
      expect(maintenanceStatus(DateTime(2026, 12, 9), t), MaintenanceStatus.later);
    });

    test('filtre aralıkları', () {
      expect(dueRange(DueFilter.overdue, t), (from: null, to: '2026-11-07'));
      expect(dueRange(DueFilter.thisWeek, t), (from: '2026-11-08', to: '2026-11-15'));
      expect(dueRange(DueFilter.thisMonth, t), (from: '2026-11-08', to: '2026-11-30'));
      expect(dueRange(DueFilter.nextMonth, DateTime(2026, 12, 20)), (from: '2027-01-01', to: '2027-01-31'));
    });
  });

  group('Ödeme durumu', () {
    test('hesaplama', () {
      expect(paymentStatus(total: 100000, paid: 100000), PaymentStatus.paid);
      expect(paymentStatus(total: 100000, paid: 120000), PaymentStatus.paid);
      expect(paymentStatus(total: 100000, paid: 0), PaymentStatus.unpaid);
      expect(paymentStatus(total: 100000, paid: 40000), PaymentStatus.partial);
      expect(paymentStatus(total: 0, paid: 0), PaymentStatus.paid);
    });
  });
}
