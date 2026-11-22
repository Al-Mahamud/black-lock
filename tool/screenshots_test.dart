// Renders real screenshots of the Flutter screen at phone size, with the real fonts.
// Run: flutter test tool/screenshots_test.dart --update-goldens   (PNGs land in tool/screenshots/)
import 'dart:io';

import 'package:black_lock/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  final dir =
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  Future<ByteData> font(String f) async =>
      ByteData.sublistView(await File('$dir/$f').readAsBytes());
  await (FontLoader('Roboto')
        ..addFont(font('Roboto-Regular.ttf'))
        ..addFont(font('Roboto-Medium.ttf'))
        ..addFont(font('Roboto-Bold.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(font('MaterialIcons-Regular.otf'))).load();
  // The app's own heading font, from its assets.
  await (FontLoader('Sora')..addFont(
        Future.value(
          ByteData.sublistView(File('assets/fonts/Sora.ttf').readAsBytesSync()),
        ),
      ))
      .load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('black_lock');
  var allowed = false;

  setUpAll(_loadFonts);
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2340);
    view.devicePixelRatio = 2.75;
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => switch (call.method) {
            'canDrawOverlays' => allowed,
            'canAddTile' => true,
            _ => null,
          },
        );
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(const BlackLockApp());
    await tester.pumpAndSettle();
  }

  testWidgets('1 permission needed', (tester) async {
    allowed = false;
    await open(tester);
    await expectLater(
      find.byType(BlackLockApp),
      matchesGoldenFile('screenshots/1-permission.png'),
    );
  });

  testWidgets('2 ready', (tester) async {
    allowed = true;
    await open(tester);
    await expectLater(
      find.byType(BlackLockApp),
      matchesGoldenFile('screenshots/2-ready.png'),
    );
  });

  testWidgets('3 counting down', (tester) async {
    allowed = true;
    await open(tester);
    await tester.tap(find.text('Lock in 5 seconds'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await expectLater(
      find.byType(BlackLockApp),
      matchesGoldenFile('screenshots/3-delay.png'),
    );
  });
}
