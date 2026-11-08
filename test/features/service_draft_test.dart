import 'package:flutter_test/flutter_test.dart';
import 'package:servis_defterim/features/services/service_draft.dart';

void main() {
  test('taslak JSON gidiş-dönüşte bozulmaz', () {
    final d = ServiceDraft(
      customerId: 'c1',
      newDevice: true,
      newDeviceBrand: 'Bosch',
      type: 'repair',
      date: DateTime(2026, 11, 8, 14, 30),
      complaint: 'Sıcak su yok',
      checklist: const ['Gaz kaçak kontrolü'],
      parts: const [PartDraft(name: 'Pompa', quantity: '2', unitPrice: '150')],
      laborFee: '500',
      total: '800',
      payment: '800',
      paymentMode: PaymentMode.full,
      nextMaintenance: DateTime(2027, 11, 8),
    );
    final back = ServiceDraft.decode(d.encode())!;
    expect(back.toJson(), d.toJson());
    expect(back.paymentMode, PaymentMode.full);
    expect(back.parts.single.name, 'Pompa');
  });

  test('otomatik toplam = parçalar + işçilik (kuruş)', () {
    final d = ServiceDraft(
      date: DateTime(2026),
      parts: const [
        PartDraft(name: 'Pompa', quantity: '2', unitPrice: '150'),
        PartDraft(name: 'Conta', unitPrice: '12,50'),
        PartDraft(name: 'Boş fiyat'),
      ],
      laborFee: '500',
    );
    expect(d.partsTotal, 31250);
    expect(d.autoTotal, 81250);
  });

  test('bozuk taslak null döner', () {
    expect(ServiceDraft.decode('{bozuk'), isNull);
    expect(ServiceDraft.decode(null), isNull);
  });
}
