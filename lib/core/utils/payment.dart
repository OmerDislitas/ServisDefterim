import '../strings.dart';

/// Odeme durumu saklanmaz, toplam ve odenen tutardan hesaplanir.
enum PaymentStatus {
  paid,
  unpaid,
  partial;

  String get label => switch (this) {
        paid => S.paymentPaid,
        unpaid => S.paymentUnpaid,
        partial => S.paymentPartial,
      };
}

/// odenen >= toplam -> Odendi, odenen = 0 -> Veresiye, arada -> Kismi. Tutarlar kurus.
PaymentStatus paymentStatus({required int total, required int paid}) {
  if (paid >= total) return PaymentStatus.paid;
  if (paid <= 0) return PaymentStatus.unpaid;
  return PaymentStatus.partial;
}
