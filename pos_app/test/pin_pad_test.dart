import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/auth/pin_pad.dart';

void main() {
  Future<void> pumpPad(WidgetTester tester, ValueChanged<String> onChanged) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: PinPad(onChanged: onChanged),
          ),
        ),
      ),
    );
  }

  testWidgets('tap angka membangun PIN berurutan', (tester) async {
    var value = '';
    await pumpPad(tester, (v) => value = v);
    await tester.tap(find.byKey(const Key('pinKey-1')));
    await tester.tap(find.byKey(const Key('pinKey-2')));
    await tester.tap(find.byKey(const Key('pinKey-3')));
    await tester.pump();
    expect(value, '123');
  });

  testWidgets('hapus mengurangi digit terakhir', (tester) async {
    var value = '';
    await pumpPad(tester, (v) => value = v);
    await tester.tap(find.byKey(const Key('pinKey-7')));
    await tester.tap(find.byKey(const Key('pinKey-8')));
    await tester.tap(find.byKey(const Key('pinKey-delete')));
    await tester.pump();
    expect(value, '7');
  });

  testWidgets('maksimal 6 digit, indikator penuh saat lengkap', (tester) async {
    var value = '';
    await pumpPad(tester, (v) => value = v);
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byKey(const Key('pinKey-9')));
    }
    await tester.pump();
    expect(value, '999999');
    expect(find.byKey(const Key('pinIndicator-5')), findsOneWidget);
  });
}
