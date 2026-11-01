import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_ncs/main.dart';
import 'package:car_ncs/services/car_audio_handler.dart';

void main() {
  testWidgets('Car NCS app landscape layout & audio handler smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final handler = CarAudioHandler(autoStart: false);

    await tester.pumpWidget(CarNcsApp(audioHandler: handler));
    await tester.pump();

    // Verify 3 columns
    expect(find.text('CAR NCS'), findsOneWidget);
    expect(find.text('RAND'), findsOneWidget);
    expect(find.text('LIST'), findsOneWidget);
    expect(find.text('METRIC'), findsOneWidget);
    expect(find.text('SET'), findsOneWidget);

    // Verify initial RAND Viewport contents
    expect(find.text('GENRE SELECTOR (RANDOM DISPATCH)'), findsOneWidget);
    expect(find.text('TRAP'), findsWidgets);
    expect(find.text('HOUSE'), findsOneWidget);
    expect(find.text('DUBSTEP'), findsOneWidget);

    // Switch to LIST tab
    await tester.tap(find.text('LIST'));
    await tester.pump();

    // Verify Song List tabs
    expect(find.textContaining('RECENTLY PLAYED'), findsOneWidget);
    expect(find.textContaining('POOL'), findsOneWidget);

    // Switch to METRIC tab
    await tester.tap(find.text('METRIC'));
    await tester.pump();

    // Verify telemetry readouts
    expect(find.text('GROUND SPEED'), findsOneWidget);
    expect(find.text('KM/H'), findsOneWidget);
    expect(find.text('KM/MIN'), findsOneWidget);
    expect(find.text('ELEVATION (GPS - WGS84)'), findsOneWidget);
    expect(find.text('ALTITUDE (STD / BARO)'), findsOneWidget);
    expect(find.textContaining('COORDS [DDM]'), findsOneWidget);

    // Switch to SET tab
    await tester.tap(find.text('SET'));
    await tester.pump();

    // Verify settings controls
    expect(find.textContaining('BARO / QNH'), findsOneWidget);
    expect(find.text('EXIT APP / UNPIN (HOLD 2s)'), findsOneWidget);
  });
}
