import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lock_orb.dart';
import 'theme.dart';

void main() => runApp(const BlackLockApp());

/// Talks to the Android side (android/app/src/main/kotlin/.../MainActivity.kt),
/// which owns the black cover, its service and the Quick Settings tile.
class LockChannel {
  static const _channel = MethodChannel('black_lock');

  static Future<bool> canDrawOverlays() async =>
      await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
  static Future<void> openOverlaySettings() =>
      _channel.invokeMethod('openOverlaySettings');
  static Future<void> lock({Duration delay = Duration.zero}) =>
      _channel.invokeMethod('lock', {'delayMs': delay.inMilliseconds});
  static Future<void> unlock() => _channel.invokeMethod('unlock');
  static Future<bool> canAddTile() async =>
      await _channel.invokeMethod<bool>('canAddTile') ?? false;
  static Future<String> addTile() async =>
      await _channel.invokeMethod<String>('addTile') ?? 'error';
}

class BlackLockApp extends StatelessWidget {
  const BlackLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Black Lock',
      debugShowCheckedModeBanner: false,
      theme: BL.theme(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _delay = Duration(seconds: 5);

  bool? _allowed; // null while checking
  bool _canAddTile = false;

  /// Drains from 1 to 0 during "Lock in 5 seconds". Kept running even with
  /// reduced motion, because the seconds are information, not decoration.
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: _delay,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _countdown.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() => _countdown.value = 1);
      }
    });
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdown.dispose();
    super.dispose();
  }

  // Coming back from the "Display over other apps" settings page.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final allowed = await LockChannel.canDrawOverlays();
    final canAddTile = await LockChannel.canAddTile();
    if (mounted) {
      setState(() {
        _allowed = allowed;
        _canAddTile = canAddTile;
      });
    }
  }

  bool get _counting => _countdown.isAnimating;

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1B2130),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  Future<void> _lockLater() async {
    await LockChannel.lock(delay: _delay);
    _countdown.reverse(from: 1); // the AnimatedBuilder redraws the orb
  }

  Future<void> _cancel() async {
    await LockChannel.unlock();
    setState(() {
      _countdown.stop();
      _countdown.value = 1;
    });
  }

  Future<void> _addTile() async {
    final result = await LockChannel.addTile();
    _toast(switch (result) {
      'added' => 'Tile added to Quick Settings',
      'already' => 'The tile is already in Quick Settings',
      'declined' => 'Tile not added',
      _ => 'Could not add the tile. Add it by editing Quick Settings.',
    });
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _allowed;
    return Scaffold(
      body: SafeArea(
        child: allowed == null
            ? const SizedBox.shrink()
            : LayoutBuilder(
                builder: (context, box) => AnimatedBuilder(
                  animation: _countdown,
                  builder: (context, _) => _content(allowed, box),
                ),
              ),
      ),
    );
  }

  /// One screen: top bar, the orb centred, the unlock hint and tile button at the bottom.
  /// Scrolls only when the phone is too short (or the text too large) to fit it.
  Widget _content(bool allowed, BoxConstraints box) {
    const pad = EdgeInsets.fromLTRB(24, 12, 24, 28);
    final mode = !allowed
        ? OrbMode.setup
        : _counting
        ? OrbMode.countdown
        : OrbMode.ready;
    return SingleChildScrollView(
      padding: pad,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (box.maxHeight - pad.vertical).clamp(0, double.infinity),
        ),
        child: IntrinsicHeight(
          child: Column(
            children: [
              _TopBar(ready: allowed),
              const Spacer(),
              const SizedBox(height: 32),
              LockOrb(
                mode: mode,
                countdown: _countdown,
                onTap: () => LockChannel.lock(),
              ),
              const SizedBox(height: 22),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                child: KeyedSubtree(
                  key: ValueKey(mode),
                  child: switch (mode) {
                    OrbMode.setup => _SetupPrompt(
                      onOpen: LockChannel.openOverlaySettings,
                    ),
                    OrbMode.ready => _DelayLink(
                      seconds: _delay.inSeconds,
                      onPressed: _lockLater,
                    ),
                    OrbMode.countdown => _CountdownHint(onCancel: _cancel),
                  },
                ),
              ),
              const Spacer(),
              const SizedBox(height: 32),
              _Footer(
                showTile: allowed,
                canAddTile: _canAddTile,
                onAddTile: _addTile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const BrandGlyph(size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Black Lock',
              style: BL.display(17, FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: ready ? BL.good : BL.amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            ready ? 'Ready' : 'Setup needed',
            style: const TextStyle(fontSize: 13, color: BL.muted),
          ),
        ],
      ),
    );
  }
}

/// Under the orb before the overlay permission is granted.
class _SetupPrompt extends StatelessWidget {
  const _SetupPrompt({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 280,
          child: Text(
            'Allow Black Lock to display over other apps to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: BL.muted, height: 1.45),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: onOpen, child: const Text('Open settings')),
      ],
    );
  }
}

/// Under the orb when ready: the delayed lock, for locking over a video.
class _DelayLink extends StatelessWidget {
  const _DelayLink({required this.seconds, required this.onPressed});

  final int seconds;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.timer_outlined, size: 19),
          label: Text('Lock in $seconds seconds'),
        ),
        const SizedBox(height: 2),
        const Text(
          'Time to switch to your video or music',
          style: TextStyle(fontSize: 12.5, color: BL.muted),
        ),
      ],
    );
  }
}

/// Under the orb while counting down.
class _CountdownHint extends StatelessWidget {
  const _CountdownHint({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 30,
          child: Center(
            child: Text(
              'Open your video or music app now',
              textAlign: TextAlign.center,
              style: BL.display(15, FontWeight.w500),
            ),
          ),
        ),
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.showTile,
    required this.canAddTile,
    required this.onAddTile,
  });

  final bool showTile;
  final bool canAddTile;
  final VoidCallback onAddTile;

  @override
  Widget build(BuildContext context) {
    const hint = TextStyle(fontSize: 12.5, color: BL.muted, height: 1.5);
    return Column(
      children: [
        const SizedBox(
          width: 290,
          child: Text(
            'To unlock: draw a V on the screen, press power, '
            'or tap Unlock in the notification.',
            textAlign: TextAlign.center,
            style: hint,
          ),
        ),
        if (showTile) ...[
          const SizedBox(height: 14),
          if (canAddTile)
            OutlinedButton.icon(
              onPressed: onAddTile,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Quick Settings tile'),
            )
          else
            const SizedBox(
              width: 290,
              child: Text(
                'Tip: add the Black Lock tile in Quick Settings '
                '(tap the pencil) to lock from any app.',
                textAlign: TextAlign.center,
                style: hint,
              ),
            ),
        ],
      ],
    );
  }
}
