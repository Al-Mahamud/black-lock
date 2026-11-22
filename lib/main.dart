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
      body: Stack(
        children: [
          const _Backdrop(),
          SafeArea(
            child: allowed == null
                ? const SizedBox.shrink()
                : AnimatedBuilder(
                    animation: _countdown,
                    builder: (context, _) => _content(allowed),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _content(bool allowed) {
    final mode = !allowed
        ? OrbMode.setup
        : _counting
        ? OrbMode.countdown
        : OrbMode.ready;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        _TopBar(ready: allowed),
        const SizedBox(height: 22),
        if (!allowed) ...[
          _SetupCard(onOpen: LockChannel.openOverlaySettings),
          const SizedBox(height: 18),
        ],
        Center(
          child: LockOrb(
            mode: mode,
            countdown: _countdown,
            onTap: () => LockChannel.lock(),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: mode == OrbMode.countdown
              ? Column(
                  key: const ValueKey('counting'),
                  children: [
                    Text(
                      'Open your video or music app now',
                      textAlign: TextAlign.center,
                      style: BL.display(15, FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    TextButton(onPressed: _cancel, child: const Text('Cancel')),
                  ],
                )
              : const _Promises(key: ValueKey('promises')),
        ),
        const SizedBox(height: 18),
        _DelayButton(
          enabled: allowed && mode != OrbMode.countdown,
          seconds: _delay.inSeconds,
          onPressed: _lockLater,
        ),
        const SizedBox(height: 30),
        const _SectionLabel('Ways to unlock'),
        const SizedBox(height: 12),
        const _UnlockWays(),
        const SizedBox(height: 30),
        const _SectionLabel('Lock from any app'),
        const SizedBox(height: 12),
        _TileCard(canAdd: _canAddTile, onAdd: _addTile),
      ],
    );
  }
}

/// Near-black with a cool blue glow behind the orb.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.48),
            radius: 0.95,
            colors: [Color(0xFF14213F), Color(0xFF0A0D16), BL.bg],
            stops: [0, 0.55, 1],
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
    final color = ready ? BL.good : BL.amber;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.asset('assets/logo.png', width: 38, height: 38),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Black Lock',
            style: BL.display(21, FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                ready ? 'Ready' : 'Setup needed',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Glass(
      borderColor: BL.amber.withValues(alpha: 0.3),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBubble(icon: Icons.layers_outlined, color: BL.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'One-time setup',
                  style: BL.display(16, FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Black Lock covers the screen on top of other apps. '
            'Turn on "Display over other apps" for Black Lock, then come back.',
            style: TextStyle(color: BL.muted, height: 1.45),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
              child: const Text('Open settings'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three short promises under the orb.
class _Promises extends StatelessWidget {
  const _Promises({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.dark_mode_outlined, 'Pure black'),
      (Icons.do_not_touch_outlined, 'No touches'),
      (Icons.graphic_eq, 'Sound plays on'),
    ];
    // One row always; on a narrow phone it scales down a little instead of wrapping.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          for (final (icon, label) in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: BL.glass,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: BL.glassLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: BL.accentHi),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12.5, color: BL.ink),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DelayButton extends StatelessWidget {
  const _DelayButton({
    required this.enabled,
    required this.seconds,
    required this.onPressed,
  });

  final bool enabled;
  final int seconds;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: BL.glass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: BL.glassLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            child: Row(
              children: [
                const _IconBubble(
                  icon: Icons.timer_outlined,
                  color: BL.accentHi,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lock in $seconds seconds',
                        style: BL.display(15, FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Time to switch to your video or music app',
                        style: TextStyle(fontSize: 12.5, color: BL.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: BL.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.4,
      color: BL.faint,
    ),
  );
}

class _UnlockWays extends StatelessWidget {
  const _UnlockWays();

  @override
  Widget build(BuildContext context) {
    const ways = [
      (Icons.swipe_rounded, 'Swipe', 'Any direction, one finger'),
      (Icons.power_settings_new_rounded, 'Power', 'Screen off ends the lock'),
      (
        Icons.notifications_none_rounded,
        'Notification',
        'Tap Unlock in the shade',
      ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (icon, title, sub)) in ways.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Glass(
                radius: 18,
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IconBubble(
                      icon: icon,
                      color: i == 0 ? BL.accentHi : BL.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(title, style: BL.display(14, FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: BL.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TileCard extends StatelessWidget {
  const _TileCard({required this.canAdd, required this.onAdd});

  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x593D7BFF), Color(0x0F3D7BFF), Color(0x1AFFFFFF)],
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D111B),
          borderRadius: BorderRadius.circular(21),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A miniature of the Quick Settings tile, so people know what to look for.
            Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 16, 9),
              decoration: BoxDecoration(
                color: const Color(0xFFA9C2FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandGlyph(
                    size: 18,
                    color: Color(0xFF0E1D45),
                    trail: Color(0xFFA9C2FF),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Black Lock',
                        style: BL.display(
                          13,
                          FontWeight.w600,
                          color: const Color(0xFF0E1D45),
                        ),
                      ),
                      const Text(
                        'Tap to lock',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF34477A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Add the Black Lock tile to Quick Settings. Then pull down the shade '
              'and tap it while your video or music is open.',
              style: TextStyle(color: BL.muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            if (canAdd)
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add tile'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              )
            else
              const Text(
                'Open Quick Settings, tap the pencil, and drag Black Lock in.',
                style: TextStyle(color: BL.ink, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(icon, size: 19, color: color),
  );
}
