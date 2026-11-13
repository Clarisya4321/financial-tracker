import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _main;
  late final AnimationController _pulse;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    _main = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();

    // Cahaya di belakang logo berdenyut terus
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _main, curve: const Interval(0.0, 0.55, curve: Curves.elasticOut)),
    );
    _logoFade = CurvedAnimation(
        parent: _main, curve: const Interval(0.0, 0.25, curve: Curves.easeIn));
    _titleFade = CurvedAnimation(
        parent: _main, curve: const Interval(0.45, 0.75, curve: Curves.easeOut));
    _titleSlide =
        Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _main,
          curve: const Interval(0.45, 0.8, curve: Curves.easeOutCubic)),
    );
    _taglineFade = CurvedAnimation(
        parent: _main, curve: const Interval(0.7, 1.0, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 3400), () {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      Navigator.pushReplacementNamed(context, user != null ? '/home' : '/login');
    });
  }

  @override
  void dispose() {
    _main.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Widget _bubble(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00BFA5), Color(0xFF00796B), Color(0xFF004D40)],
          ),
        ),
        child: Stack(
          children: [
            // Hiasan lingkaran transparan di latar
            Positioned(top: -60, right: -60, child: _bubble(220, 0.08)),
            Positioned(top: 140, left: -50, child: _bubble(120, 0.06)),
            Positioned(bottom: -80, left: -40, child: _bubble(260, 0.07)),
            Positioned(bottom: 120, right: 30, child: _bubble(70, 0.08)),

            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // LOGO
                  AnimatedBuilder(
                    animation: Listenable.merge([_main, _pulse]),
                    builder: (context, child) {
                      final glow = 20 + (_pulse.value * 30);
                      return Opacity(
                        opacity: _logoFade.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.45),
                                  blurRadius: glow,
                                  spreadRadius: glow / 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 70,
                              color: Color(0xFF00796B),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 36),

                  // JUDUL
                  FadeTransition(
                    opacity: _titleFade,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: const Text(
                        'Personal Finance\nTracker',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // TAGLINE
                  FadeTransition(
                    opacity: _taglineFade,
                    child: const Text(
                      'Catat  •  Pantau  •  Hemat',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // BAR LOADING DI BAWAH
            Positioned(
              left: 60,
              right: 60,
              bottom: 60,
              child: FadeTransition(
                opacity: _taglineFade,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
