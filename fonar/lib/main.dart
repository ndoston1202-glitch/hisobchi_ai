import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:torch_light/torch_light.dart';

void main() => runApp(const FonarApp());

const amber = Color(0xFFFFC94D);
const bg = Color(0xFF0B0F1A);

class FonarApp extends StatelessWidget {
  const FonarApp({super.key, this.torch = const Torch()});

  final Torch torch;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fonar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: amber, brightness: Brightness.dark, primary: amber),
        scaffoldBackgroundColor: bg,
      ),
      home: FonarScreen(torch: torch),
    );
  }
}

/// Haqiqiy chiroq. Testlarda almashtiriladi.
class Torch {
  const Torch();

  Future<bool> get available async {
    try {
      return await TorchLight.isTorchAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<void> set(bool on) async {
    try {
      on ? await TorchLight.enableTorch() : await TorchLight.disableTorch();
    } catch (_) {
      // Chiroq band yoki yo'q — ekran yorug'ligi ishlatiladi.
    }
  }
}

class FonarScreen extends StatefulWidget {
  const FonarScreen({super.key, required this.torch});

  final Torch torch;

  @override
  State<FonarScreen> createState() => _FonarScreenState();
}

class _FonarScreenState extends State<FonarScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);
  bool _on = false;

  /// Hazil har safar ilova ochilganda bir marta ko'rsatiladi.
  bool _pranked = false;
  bool _hasTorch = true;

  @override
  void initState() {
    super.initState();
    widget.torch.available.then((v) {
      if (mounted) setState(() => _hasTorch = v);
    });
  }

  @override
  void dispose() {
    widget.torch.set(false);
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    HapticFeedback.mediumImpact();
    if (_on) {
      await _setLight(false);
      return;
    }
    if (!_pranked) {
      final paid = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF151B2B),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => const PaywallSheet(),
      );
      if (paid != true || !mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, _, _) => const PrankScreen(),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ),
      );
      if (!mounted) return;
      _pranked = true;
    }
    await _setLight(true);
  }

  Future<void> _setLight(bool on) async {
    setState(() => _on = on);
    await widget.torch.set(on);
  }

  @override
  Widget build(BuildContext context) {
    final screenLight = _on && !_hasTorch;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: screenLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
            gradient: screenLight
                ? const LinearGradient(colors: [Colors.white, Color(0xFFFFF8E1)])
                : const RadialGradient(center: Alignment(0, -0.2), radius: 1.1, colors: [Color(0xFF1A2236), bg]),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      Icon(Icons.flashlight_on_rounded, color: screenLight ? Colors.black87 : amber),
                      const SizedBox(width: 8),
                      Text(
                        'Fonar',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: screenLight ? Colors.black87 : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFFD86B), Color(0xFFFF9F43)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!screenLight)
                        Positioned.fill(
                          child: AnimatedOpacity(
                            opacity: _on ? 1 : 0,
                            duration: const Duration(milliseconds: 500),
                            child: const CustomPaint(painter: _BeamPainter()),
                          ),
                        ),
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => _PowerButton(on: _on, pulse: _pulse.value, onTap: _toggle),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _on ? 'Yoniq' : 'Yoqish uchun bosing',
                      key: ValueKey(_on),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: screenLight ? Colors.black54 : Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.on, required this.pulse, required this.onTap});

  final bool on;
  final double pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glow = on ? 0.55 + 0.25 * pulse : 0.08 + 0.06 * pulse;
    return Semantics(
      button: true,
      label: on ? 'O\'chirish' : 'Yoqish',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: on
                  ? const [Color(0xFFFFE08A), amber, Color(0xFFFF9F43)]
                  : const [Color(0xFF2A3350), Color(0xFF161D2F)],
            ),
            boxShadow: [
              BoxShadow(
                color: amber.withValues(alpha: glow),
                blurRadius: on ? 80 : 30,
                spreadRadius: on ? 12 : 2,
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: on ? 0.6 : 0.08), width: 2),
          ),
          child: Icon(Icons.power_settings_new_rounded, size: 84, color: on ? const Color(0xFF3A2500) : Colors.white70),
        ),
      ),
    );
  }
}

/// Yuqoriga tarqaluvchi yorug'lik nuri.
class _BeamPainter extends CustomPainter {
  const _BeamPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final path = Path()
      ..moveTo(c.dx - 50, c.dy)
      ..lineTo(c.dx + 50, c.dy)
      ..lineTo(size.width + 60, 0)
      ..lineTo(-60, 0)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [amber.withValues(alpha: 0.45), amber.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, c.dy)),
    );
  }

  @override
  bool shouldRepaint(_BeamPainter oldDelegate) => false;
}

/// Soxta "Premium" oynasi. Hech qanday ma'lumot so'ramaydi va to'lov olmaydi.
class PaywallSheet extends StatelessWidget {
  const PaywallSheet({super.key});

  @override
  Widget build(BuildContext context) {
    const features = ['Cheksiz yorug\'lik', 'Reklamasiz', 'SOS va strob rejimlari'];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFFFFD86B), Color(0xFFFF9F43)]),
              ),
              child: const Icon(Icons.workspace_premium_rounded, size: 40, color: Color(0xFF3A2500)),
            ),
            const SizedBox(height: 16),
            const Text('Fonar Premium', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Bepul sinov muddati tugadi.\nFonarni yoqish uchun Premium\'ni faollashtiring.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 20),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: amber, size: 20),
                    const SizedBox(width: 10),
                    Flexible(child: Text(f, style: const TextStyle(fontSize: 15))),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: amber, width: 2),
                color: amber.withValues(alpha: 0.08),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text('1 oylik obuna', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(
                    "9 900 so'm",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: amber),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: amber,
                  foregroundColor: const Color(0xFF3A2500),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("To'lash", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keyinroq', style: TextStyle(color: Colors.white60)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "To'lov" → qisqa kutish → "HAZIL!" va konfetti.
class PrankScreen extends StatefulWidget {
  const PrankScreen({super.key});

  @override
  State<PrankScreen> createState() => _PrankScreenState();
}

class _PrankScreenState extends State<PrankScreen> with TickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _confetti = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _revealed = true);
      _reveal.forward();
      _confetti.repeat();
    });
  }

  @override
  void dispose() {
    _reveal.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _revealed ? _buildReveal(context) : _buildProcessing());
  }

  Widget _buildProcessing() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5, color: amber)),
          SizedBox(height: 24),
          Text("To'lov amalga oshirilmoqda...", style: TextStyle(fontSize: 18, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildReveal(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _confetti,
            builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_confetti.value)),
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: CurvedAnimation(parent: _reveal, curve: Curves.elasticOut),
                    child: const Text('😂', style: TextStyle(fontSize: 120)),
                  ),
                  const SizedBox(height: 8),
                  ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _reveal,
                      curve: const Interval(0.2, 1, curve: Curves.elasticOut),
                    ),
                    child: const Text(
                      'HAZIL!',
                      style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: amber, letterSpacing: 2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: CurvedAnimation(parent: _reveal, curve: const Interval(0.5, 1)),
                    child: const Text(
                      "Hech qanday to'lov olinmadi.\nFonar mutlaqo bepul! 😄",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.white, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeTransition(
                    opacity: CurvedAnimation(parent: _reveal, curve: const Interval(0.6, 1)),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: amber,
                          foregroundColor: const Color(0xFF3A2500),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.flashlight_on_rounded),
                        label: const Text(
                          'Fonarni yoqish',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  final double t;
  static const _colors = [
    amber,
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFF7C83FD),
    Color(0xFF6BCB77),
    Colors.white,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 90; i++) {
      final x = random.nextDouble() * size.width;
      final speed = 0.6 + random.nextDouble() * 0.8;
      final offset = random.nextDouble();
      final y = ((t * speed + offset) % 1) * (size.height + 40) - 20;
      final sway = math.sin((t * 6 + i) * 1.3) * 14;
      paint.color = _colors[i % _colors.length];
      canvas.save();
      canvas.translate(x + sway, y);
      canvas.rotate((t * 10 + i) * (i.isEven ? 1 : -1));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -3, 10, 6), const Radius.circular(1.5)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
