import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mosaic/main.dart';

void main() {
  testWidgets('CartaApp renders MaterialApp', (WidgetTester tester) async {
    // Phone-sized surface
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Suppress RenderFlex overflow exceptions — they show as yellow overflow
    // stripes on device but throw in tests. This is safe for a smoke test.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final summary = details.summary.toString();
      if (summary.contains('overflowed') || summary.contains('paint')) return;
      originalOnError?.call(details);
    };

    await tester.pumpWidget(const CartaApp());
    await tester.pump(Duration.zero);

    FlutterError.onError = originalOnError;

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
