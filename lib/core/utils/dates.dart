/// Tarih yardimcilari.
///
/// Sadece tarih olan alanlar (bakim tarihi, garanti bitisi) saat dilimi
/// kaymasina ugramamasi icin veritabaninda `yyyy-MM-dd` metni olarak tutulur
/// ("date key"). Dart tarafinda yerel gece yarisi DateTime olarak kullanilir.
library;

import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../strings.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// 2026-11-08
String toDateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

DateTime parseDateKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today([DateTime? now]) => dateOnly(now ?? DateTime.now());

/// Takvim gunu farki (b - a). Yaz saati gecislerinden etkilenmez.
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Ay ekler; ayin son gununu asarsa son gune sabitler. 31 Ocak + 1 ay -> 28/29 Subat.
DateTime addMonths(DateTime d, int months) {
  final total = d.month - 1 + months;
  final year = d.year + (total / 12).floor();
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(d.day, lastDay));
}

DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "8 Kasım 2026, Pazar"
String formatDateLong(DateTime d) => DateFormat('d MMMM y, EEEE', 'tr_TR').format(d);

/// "8 Kasım 2026"
String formatDate(DateTime d) => DateFormat('d MMMM y', 'tr_TR').format(d);

/// "08.11.2026"
String formatDateShort(DateTime d) => DateFormat('dd.MM.yyyy', 'tr_TR').format(d);

/// "18:40"
String formatTime(DateTime d) => DateFormat('HH:mm', 'tr_TR').format(d);

/// "8 Kasım 2026, 18:40"
String formatDateTime(DateTime d) => '${formatDate(d)}, ${formatTime(d)}';

/// "bugün", "dün", "3 gün önce", "yarın", "5 gün sonra"
String relativeDay(DateTime d, {DateTime? now}) {
  final diff = daysBetween(today(now), d);
  if (diff == 0) return S.today;
  if (diff == -1) return S.yesterday;
  if (diff == 1) return S.tomorrow;
  return diff < 0 ? S.daysAgo(-diff) : S.daysLater(diff);
}
