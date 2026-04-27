// lib/splash_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'info.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final VideoPlayerController _videoController;
  late final AnimationController _pulseController;

  bool _navigated = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _videoController = VideoPlayerController.asset('assets/splash.mp4')
      ..setLooping(false)
      ..setVolume(0)
      ..initialize().then((_) async {
        if (!mounted) return;
        setState(() {});
        await _videoController.play();
      });

    _videoController.addListener(_videoListener);
  }

  void _videoListener() {
    if (!_videoController.value.isInitialized) return;

    final d = _videoController.value.duration;
    final p = _videoController.value.position;

    if (d.inMilliseconds > 0) {
      final value = (p.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0);
      if ((value - _progress).abs() > 0.001 && mounted) {
        setState(() => _progress = value);
      }
    }

    final isDone = d.inMilliseconds > 0 &&
        p.inMilliseconds >= d.inMilliseconds - 120 &&
        !_navigated;

    if (isDone) _goNext();
  }

  void _goNext() {
    if (!mounted || _navigated) return;
    _navigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        pageBuilder: (_, __, ___) => const InfoPage(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _videoController.removeListener(_videoListener);
    _videoController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialized = _videoController.value.isInitialized;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final bgFallback = dark ? const Color(0xFF07111F) : const Color(0xFFF6FAFF);
    final textPrimary =
        dark ? const Color(0xFFEAF4FF) : const Color(0xFF0F172A);
    final textSecondary =
        dark ? const Color(0xFFD7EDFF) : const Color(0xFF475569);
    final chipBg = dark ? const Color(0x3319D3FF) : const Color(0xCCFFFFFF);
    final chipBorder = dark ? const Color(0x3348E7FF) : const Color(0xFFD7E4F2);
    final progressTrack =
        dark ? const Color(0x22000000) : const Color(0xFFE8F1FB);
    final glassBg = dark ? const Color(0x2219D3FF) : const Color(0xCCFFFFFF);

    return Scaffold(
      backgroundColor: bgFallback,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (initialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController.value.size.width,
                height: _videoController.value.size.height,
                child: VideoPlayer(_videoController),
              ),
            )
          else
            Container(color: bgFallback),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? const [
                        Color(0x6607111F),
                        Color(0xAA07111F),
                        Color(0xEE07111F),
                      ]
                    : const [
                        Color(0x55F6FAFF),
                        Color(0xAAF6FAFF),
                        Color(0xEEF6FAFF),
                      ],
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 0.95,
                  colors: dark
                      ? [
                          const Color(0x3319D3FF),
                          const Color(0x2200E5FF),
                          Colors.transparent,
                        ]
                      : [
                          const Color(0x2200B7E8),
                          const Color(0x140B3C7A),
                          Colors.transparent,
                        ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 8),
                Center(
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final s = 1 + (_pulseController.value * 0.05);
                          return Transform.scale(scale: s, child: child);
                        },
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF19D3FF), Color(0xFF0B3C7A)],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x6619D3FF),
                                blurRadius: 28,
                                spreadRadius: 4,
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0x669FEFFF),
                              width: 1.2,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (dark
                                          ? const Color(0xFF07111F)
                                          : const Color(0xFFFFFFFF))
                                      .withOpacity(.70),
                                  border: Border.all(
                                    color: const Color(0x3348E7FF),
                                  ),
                                ),
                              ),
                              const Text(
                                'P',
                                style: TextStyle(
                                  color: Color(0xFF8BEF3F),
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: [
                              Color(0xFFEAF4FF),
                              Color(0xFFBFE9FF),
                              Color(0xFF8BEF3F),
                            ],
                          ).createShader(bounds);
                        },
                        child: const Text(
                          'shayyek',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: chipBorder),
                        ),
                        child: Text(
                          'Smart Parking & AI Guidance',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 7),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: glassBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: chipBorder),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, _) {
                                    return Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color.lerp(
                                          const Color(0xFF19D3FF),
                                          const Color(0xFF8BEF3F),
                                          _pulseController.value,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color.lerp(
                                              const Color(0x6619D3FF),
                                              const Color(0x668BEF3F),
                                              _pulseController.value,
                                            )!,
                                            blurRadius: 12,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Initializing smart parking experience...',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(_progress * 100).toInt()}%',
                                  style: TextStyle(
                                    color: dark
                                        ? const Color(0xFFBFE9FF)
                                        : const Color(0xFF0B3C7A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 8,
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: progressTrack,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: _progress == 0 && initialized
                                        ? 0.02
                                        : (_progress == 0 ? 0.0 : _progress),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF19D3FF),
                                            Color(0xFF0EA5E9),
                                            Color(0xFF8BEF3F),
                                          ],
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x5519D3FF),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
