import '../utils/text_normalize.dart';

// Arama yapilan tablolarin searchText kolonlari (PLAN 6.4).
// Her ekleme/guncellemede bu fonksiyonlarla yeniden uretilir.

String customerSearchText(String name, String phone, String? phone2) =>
    buildSearchText([name, phone, phone2]);

String addressSearchText({
  String? label,
  String? district,
  String? neighborhood,
  required String addressLine,
  String? directions,
}) =>
    buildSearchText([label, district, neighborhood, addressLine, directions]);

String deviceSearchText(String brand, String? model, String? serialNo) =>
    buildSearchText([brand, model, serialNo]);
