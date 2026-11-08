import '../core/db/database.dart';
import '../core/strings.dart';

/// "Demirdöküm Nitromix"
String deviceTitle(String brand, String? model) => model == null ? brand : '$brand $model';

/// "Kayabaşı, Başakşehir" (mahalle, ilçe). Ikisi de yoksa bos metin.
String areaText(String? district, String? neighborhood) =>
    [neighborhood, district].whereType<String>().join(', ');

/// "Gül Sk. No:5, Kat 3, Daire 12"
String addressDetail(Address a) => [
      a.addressLine,
      if (a.floor != null) S.floorShort(a.floor!),
      if (a.apartmentNo != null) S.apartmentShort(a.apartmentNo!),
    ].join(', ');

/// Adres karti basligi: etiket, yoksa bolge, yoksa acik adres.
String addressTitle(Address a) {
  final area = areaText(a.district, a.neighborhood);
  if (a.label != null) return area.isEmpty ? a.label! : '${a.label} · $area';
  return area.isEmpty ? a.addressLine : area;
}
