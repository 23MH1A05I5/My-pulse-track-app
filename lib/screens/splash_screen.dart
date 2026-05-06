import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'main_nav_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _ecgController;
  late AnimationController _contentController;
  late Animation<double> _heartScale;
  late Animation<double> _contentOpacity;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _ecgController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
    ]).animate(_pulseController);

    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeIn),
    );

    _contentController.forward();
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Provider.of<AuthProvider>(context, listen: false).loadUser();
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    Widget nextScreen;
    if (authProvider.isAuthenticated) {
      nextScreen = const MainNavScreen();
    } else if (authProvider.shouldShowOnboarding) {
      nextScreen = const OnboardingScreen();
    } else {
      nextScreen = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ecgController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    const Color(0xFF1A0505).withOpacity(0.5),
                    const Color(0xFF0A0A0A),
                  ],
                ),
              ),
            ),
          ),

          // Pulsing Rings
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return CustomPaint(
                  painter: PulseRingsPainter(_pulseController.value),
                  size: const Size(300, 300),
                );
              },
            ),
          ),

          // Main Content
          FadeTransition(
            opacity: _contentOpacity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // Glowing Heart
                ScaleTransition(
                  scale: _heartScale,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryRed.withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/glowing_heart.png',
                      width: 120,
                      height: 120,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.favorite,
                        color: AppTheme.primaryRed,
                        size: 100,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Pulse',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'Track',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryRed,
                        letterSpacing: -1,
                        shadows: [
                          Shadow(
                            color: AppTheme.primaryRed.withOpacity(0.5),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryRed.withOpacity(0.2)),
                  ),
                  child: Text(
                    'AI-POWERED WELLNESS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryRed.withOpacity(0.8),
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const Spacer(),
                // ECG Waveform
                SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: _ecgController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: ECGWaveformPainter(_ecgController.value),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
                // Bottom Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryRed.withOpacity(0.5)),
                        ),
                        child: const Icon(Icons.shield_outlined, color: AppTheme.primaryRed, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Monitor. Understand. Improve.',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Your heart, our priority.',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PulseRingsPainter extends CustomPainter {
  final double progress;
  PulseRingsPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke;

    // Background subtle glow
    final radialPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.primaryRed.withOpacity(0.15 * (1 - progress)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width / 2));
    canvas.drawCircle(center, size.width / 2, radialPaint);

    for (int i = 0; i < 4; i++) {
      final ringProgress = (progress + (i / 4)) % 1.0;
      final radius = (size.width / 2) * ringProgress;
      final opacity = math.pow(1.0 - ringProgress, 2.0).toDouble();
      
      paint.strokeWidth = 1.0 + (1.0 - ringProgress) * 2;
      paint.color = AppTheme.primaryRed.withOpacity(opacity * 0.4);
      canvas.drawCircle(center, radius, paint);
      
      // Outer subtle glow
      paint.color = AppTheme.primaryRed.withOpacity(opacity * 0.05);
      paint.strokeWidth = 8.0;
      canvas.drawCircle(center, radius, paint);
    }

    // Orbiting Data Dots
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      double angle = (i * math.pi / 3) + (progress * math.pi * 0.5);
      double dist = 100 + math.sin(progress * math.pi + i) * 15;
      double dotOpacity = (0.3 + 0.3 * math.sin(progress * math.pi * 2 + i)).clamp(0.0, 1.0);
      
      dotPaint.color = AppTheme.primaryRed.withOpacity(dotOpacity);
      canvas.drawCircle(
        Offset(center.dx + math.cos(angle) * dist, center.dy + math.sin(angle) * dist),
        1.5,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(PulseRingsPainter oldDelegate) => true;
}

class ECGWaveformPainter extends CustomPainter {
  final double progress;
  ECGWaveformPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryRed.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final midY = height / 2;

    path.moveTo(0, midY);

    for (double x = 0; x <= width; x += 2) {
      double relativeX = (x / width + progress) % 1.0;
      double y = midY;

      // Create ECG spikes at specific points in the cycle
      if (relativeX > 0.45 && relativeX < 0.55) {
        // Main spike (QRS complex)
        double peakProgress = (relativeX - 0.45) / 0.1;
        if (peakProgress < 0.2) {
          y = midY + (peakProgress / 0.2) * 10; // Q
        } else if (peakProgress < 0.5) {
          y = midY - ((peakProgress - 0.2) / 0.3) * 40; // R
        } else if (peakProgress < 0.8) {
          y = midY + ((peakProgress - 0.5) / 0.3) * 30; // S
        } else {
          y = midY - ((peakProgress - 0.8) / 0.2) * 5; // T start
        }
      } else if (relativeX > 0.1 && relativeX < 0.2) {
        // P wave
        double pProgress = (relativeX - 0.1) / 0.1;
        y = midY - math.sin(pProgress * math.pi) * 8;
      } else if (relativeX > 0.7 && relativeX < 0.85) {
        // T wave
        double tProgress = (relativeX - 0.7) / 0.15;
        y = midY - math.sin(tProgress * math.pi) * 12;
      }

      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Shadow/Glow for the ECG line
    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.primaryRed.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ECGWaveformPainter oldDelegate) => true;
}

