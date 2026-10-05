import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/logo.dart';
import '../shell/shell.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  bool _animationDone = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      _animationDone = true;
      _maybeContinue();
    });
  }

  void _maybeContinue() {
    if (_navigated || !_animationDone || ref.read(ledgerProvider) == null || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => const HomeShell(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ledgerProvider, (_, _) => _maybeContinue());
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF34D399), brandColor, brandDark],
            ),
          ),
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                final text = Curves.easeOut.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0));
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.7 + 0.3 * Curves.easeOutBack.transform((t / 0.6).clamp(0.0, 1.0)),
                      child: HisobchiLogo(size: 132, progress: t, onBrand: true),
                    ),
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: text,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - text)),
                        child: Column(
                          children: [
                            Text(
                              'Hisobchi',
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Shaxsiy moliya — oson va aniq',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
