/// Para her zaman tam sayi kurus (int) olarak tutulur. Bu dosya sadece
/// kurus <-> metin donusumu yapar; hesaplamalarda double kullanilmaz.
library;

import 'package:intl/intl.dart';

final _thousands = NumberFormat('#,##0', 'tr_TR');

/// 125000 -> "1.250,00 ₺"
String formatMoney(int kurus) {
  final negative = kurus < 0;
  final abs = kurus.abs();
  final text = '${_thousands.format(abs ~/ 100)},${(abs % 100).toString().padLeft(2, '0')} ₺';
  return negative ? '-$text' : text;
}

/// Form alanina yazilacak duzenlenebilir bicim: 125000 -> "1250", 125050 -> "1250,50"
String kurusToInput(int kurus) {
  final lira = kurus ~/ 100;
  final k = kurus % 100;
  return k == 0 ? '$lira' : '$lira,${k.toString().padLeft(2, '0')}';
}

final _digits = RegExp(r'^\d+$');

/// Kullanici girdisini kurusa cevirir. Gecersiz ya da bossa null.
/// "1.250,50" -> 125050, "1250" -> 125000, "1250.5" -> 125050, "1.250" -> 125000
int? parseMoney(String input) {
  var s = input.replaceAll('₺', '').replaceAll(' ', '').replaceAll(' ', '').trim();
  if (s.isEmpty) return null;

  String intPart;
  var decPart = '';
  if (s.contains(',')) {
    final idx = s.lastIndexOf(',');
    intPart = s.substring(0, idx).replaceAll('.', '');
    decPart = s.substring(idx + 1);
  } else {
    final dots = '.'.allMatches(s).length;
    final idx = s.lastIndexOf('.');
    if (dots == 1 && s.length - idx - 1 <= 2) {
      // Tek nokta ve ardinda en fazla 2 hane: ondalik ayirici
      intPart = s.substring(0, idx);
      decPart = s.substring(idx + 1);
    } else {
      intPart = s.replaceAll('.', '');
    }
  }

  if (intPart.isEmpty) intPart = '0';
  if (!_digits.hasMatch(intPart)) return null;
  if (decPart.isNotEmpty && (!_digits.hasMatch(decPart) || decPart.length > 2)) return null;

  final kurus = decPart.isEmpty ? 0 : int.parse(decPart.padRight(2, '0'));
  return int.parse(intPart) * 100 + kurus;
}
