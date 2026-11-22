import 'package:black_lock/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('black_lock');
  late bool allowed;
  late List<MethodCall> calls;

  setUp(() {
    final binding = TestWidgetsFlutterBinding.instance;
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400); // a typical phone
    view.devicePixelRatio = 2.75;
    // The orb's breathing glow repeats forever; reduced motion keeps pumpAndSettle finite.
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    allowed = false;
    calls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return switch (call.method) {
        'canDrawOverlays' => allowed,
        'canAddTile' => true,
        'addTile' => 'added',
        _ => null,
      };
    });
  });

  List<String> methods() => calls.map((c) => c.method).toList();

  testWidgets('asks for setup and does not lock until allowed', (tester) async {
    await tester.pumpWidget(const BlackLockApp());
    await tester.pumpAndSettle();

    expect(find.text('One-time setup'), findsOneWidget);
    expect(find.text('Setup needed'), findsOneWidget);

    await tester.tap(find.text('Lock now'));
    await tester.tap(find.text('Lock in 5 seconds'));
    await tester.pump();
    expect(methods(), isNot(contains('lock')));

    await tester.tap(find.text('Open settings'));
    expect(calls.last.method, 'openOverlaySettings');
  });

  testWidgets('tapping the orb locks straight away', (tester) async {
    allowed = true;
    await tester.pumpWidget(const BlackLockApp());
    await tester.pumpAndSettle();

    expect(find.text('One-time setup'), findsNothing);
    expect(find.text('Ready'), findsOneWidget);

    await tester.tap(find.text('Lock now'));
    expect(calls.last.method, 'lock');
    expect(calls.last.arguments, {'delayMs': 0});
  });

  testWidgets('counts down after "Lock in 5 seconds" and can cancel', (
    tester,
  ) async {
    allowed = true;
    await tester.pumpWidget(const BlackLockApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lock in 5 seconds'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(calls.last.arguments, {'delayMs': 5000});
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Open your video or music app now'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls.last.method, 'unlock');
    expect(find.text('Pure black'), findsOneWidget);
  });

  testWidgets('countdown ends by itself after 5 seconds', (tester) async {
    allowed = true;
    await tester.pumpWidget(const BlackLockApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lock in 5 seconds'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Lock now'), findsOneWidget);
  });

  testWidgets('adds the Quick Settings tile', (tester) async {
    allowed = true;
    await tester.pumpWidget(const BlackLockApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add tile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add tile'));
    await tester.pumpAndSettle();
    expect(find.text('Tile added to Quick Settings'), findsOneWidget);
  });
}
