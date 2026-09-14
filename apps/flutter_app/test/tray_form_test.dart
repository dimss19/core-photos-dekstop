import 'package:core_photo/tray_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('To < From blocks capture with warning', () {
    final f = TrayForm(holeId: 'Core01', trayId: '1', intervalFrom: '20', intervalTo: '10');
    expect(f.warning, 'To < From');
    expect(f.canCapture, isFalse);
  });

  test('valid tray builds filename per format', () {
    final f = TrayForm(holeId: 'Core01', trayId: '1', intervalFrom: '0', intervalTo: '2.6', rows: '3');
    expect(f.canCapture, isTrue);
    expect(f.filename(), 'Core01_1_000.00_2.60.jpg');
    expect(f.toJson('s1')['rows'], 3);
  });

  test('missing ids or non-numeric interval warn', () {
    expect(TrayForm().warning, isNotNull);
    expect(TrayForm(holeId: 'C', trayId: '1', intervalFrom: 'x', intervalTo: '1').warning, contains('angka'));
  });
}
