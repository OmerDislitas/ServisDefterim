/// Telefon normalizasyonu ve arama/WhatsApp linkleri (PLAN 6.3).
library;

final _nonDigits = RegExp(r'\D');

String digitsOnly(String input) => input.replaceAll(_nonDigits, '');

/// Kayitta saklanacak bicim: sadece rakamlar, ulke kodu ve bastaki 0 olmadan.
/// "0532 123 45 67", "+90 532 123 45 67", "905321234567" -> "5321234567"
String normalizePhone(String input) {
  var d = digitsOnly(input);
  if (d.startsWith('00')) d = d.substring(2);
  if (d.length == 12 && d.startsWith('90')) {
    d = d.substring(2);
  } else if (d.length == 11 && d.startsWith('0')) {
    d = d.substring(1);
  }
  return d;
}

/// Gosterim: "5321234567" -> "0532 123 45 67". Turkiye formatinda degilse oldugu gibi.
String formatPhone(String normalized) {
  if (normalized.length != 10) return normalized;
  final d = normalized;
  return '0${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6, 8)} ${d.substring(8)}';
}

/// Arama teriminden telefon kolonunda aranacak rakam kismi.
/// "0532 12" -> "53212", "+90 532" -> "532"
String phoneSearchDigits(String term) {
  var d = digitsOnly(term);
  if (d.startsWith('00')) d = d.substring(2);
  if (term.trim().startsWith('+90') && d.startsWith('90')) d = d.substring(2);
  if (d.startsWith('0')) d = d.substring(1);
  return d;
}

Uri telUri(String normalized) =>
    Uri(scheme: 'tel', path: normalized.length == 10 ? '0$normalized' : normalized);

/// `https://wa.me/90XXXXXXXXXX?text=mesaj`
Uri whatsappUri(String normalized, {String? message}) {
  final number = normalized.length == 10 ? '90$normalized' : normalized;
  final text = (message == null || message.isEmpty) ? '' : '?text=${Uri.encodeComponent(message)}';
  return Uri.parse('https://wa.me/$number$text');
}

/// WhatsApp hatirlatma sablonunu doldurur (PLAN 6.5). Degiskenler: {ad}, {marka}, {tarih}.
String fillWhatsappTemplate(
  String template, {
  required String name,
  String? brand,
  String? date,
}) =>
    template
        .replaceAll('{ad}', name)
        .replaceAll('{marka}', brand ?? '')
        .replaceAll('{tarih}', date ?? '');
