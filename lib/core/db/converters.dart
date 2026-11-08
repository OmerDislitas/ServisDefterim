import 'dart:convert';

import 'package:drift/drift.dart';

import '../utils/dates.dart';

/// Sadece tarih alanlari: veritabaninda 'yyyy-MM-dd', Dart'ta yerel gece yarisi.
class DateOnlyConverter extends TypeConverter<DateTime, String> {
  const DateOnlyConverter();

  @override
  DateTime fromSql(String fromDb) => parseDateKey(fromDb);

  @override
  String toSql(DateTime value) => toDateKey(value);
}

/// Checklist maddelerinin metin kopyasi: JSON dizi.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) => (jsonDecode(fromDb) as List).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
