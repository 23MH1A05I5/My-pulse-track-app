import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/bpm_record.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'dart:math' as math;
import 'dart:async';

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _instruction = 'Inhale';
  String _instructionSubtitle = 'Breathe in slowly through your nose';
  
  int _selectedMinutes = 3;
  int _remainingSeconds = 180;
  bool _isPlaying = false;
  Timer? _countdownTimer;

  // 1: Inhale, 2: Hold, 3: Exhale
  int _currentPhase = 1;

  int _latestBpm = 0;
  final ApiService _apiService = ApiService();

  int get _inhaleSec => _selectedMinutes == 1 ? 3 : (_selectedMinutes == 2 ? 4 : (_selectedMinutes == 3 ? 4 : (_selectedMinutes == 4 ? 5 : 6)));
  int get _holdSec => _selectedMinutes == 1 ? 2 : (_selectedMinutes == 2 ? 3 : (_selectedMinutes == 3 ? 4 : (_selectedMinutes == 4 ? 4 : 5)));
  int get _exhaleSec => _selectedMinutes == 1 ? 3 : (_selectedMinutes == 2 ? 4 : (_selectedMinutes == 3 ? 6 : (_selectedMinutes == 4 ? 6 : 8)));

  String get _timeText {
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _fetchBpm();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: _inhaleSec),
      reverseDuration: Duration(seconds: _exhaleSec),
    );

    _controller.addListener(() {
      setState(() {});
    });

    _controller.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        setState(() {
          _instruction = 'Hold';
          _instructionSubtitle = 'Hold your breath comfortably';
          _currentPhase = 2;
        });
        HapticFeedback.selectionClick();
        await Future.delayed(Duration(seconds: _holdSec));
        if (mounted && _isPlaying) {
          setState(() {
            _instruction = 'Exhale';
            _instructionSubtitle = 'Breathe out slowly through your mouth';
            _currentPhase = 3;
          });
          HapticFeedback.selectionClick();
          _controller.reverseDuration = Duration(seconds: _exhaleSec);
          _controller.reverse();
        }
      } else if (status == AnimationStatus.dismissed) {
        setState(() {
          _instruction = 'Hold';
          _instructionSubtitle = 'Wait before your next breath';
          _currentPhase = 2;
        });
        HapticFeedback.selectionClick();
        await Future.delayed(Duration(seconds: _holdSec));
        if (mounted && _isPlaying) {
          setState(() {
            _instruction = 'Inhale';
            _instructionSubtitle = 'Breathe in slowly through your nose';
            _currentPhase = 1;
          });
          HapticFeedback.selectionClick();
          _controller.duration = Duration(seconds: _inhaleSec);
          _controller.forward();
        }
      }
    });
  }

  Future<void> _fetchBpm() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      try {
        final latest = await _apiService.getLatest(user.id);
        if (latest != null && mounted) {
          setState(() {
            _latestBpm = latest.bpm;
          });
        }
      } catch (e) {
        // Ignore error
      }
    }
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      if (_remainingSeconds <= 0) {
        setState(() => _remainingSeconds = _selectedMinutes * 60);
      }
      
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
          _stopExercise();
        }
      });

      if (_controller.status == AnimationStatus.dismissed || _controller.status == AnimationStatus.forward) {
        _controller.duration = Duration(seconds: _inhaleSec);
        _controller.forward();
      } else {
        _controller.reverseDuration = Duration(seconds: _exhaleSec);
        _controller.reverse();
      }
    } else {
      _countdownTimer?.cancel();
      _controller.stop();
    }
  }

  void _stopExercise() {
    _countdownTimer?.cancel();
    _controller.stop();
    
    // Calculate minutes spent
    int totalSeconds = _selectedMinutes * 60;
    int secondsSpent = totalSeconds - _remainingSeconds;
    int minutesSpent = (secondsSpent / 60).round();
    
    if (minutesSpent > 0) {
      Provider.of<AuthProvider>(context, listen: false).recordBreathingSession(minutesSpent);
    }

    setState(() {
      _isPlaying = false;
      _instruction = 'Done';
      _instructionSubtitle = 'Exercise complete. Great job!';
      _currentPhase = 1;
    });
    HapticFeedback.heavyImpact();
  }

  void _changeTime(int minutes) {
    if (_isPlaying) return;
    setState(() {
      _selectedMinutes = minutes;
      _remainingSeconds = minutes * 60;
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17), // Deep dark premium blue/black
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              'Breathing Exercise',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Follow the animation and breathe slowly',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Top Cards
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTopCard(
                    icon: Icons.favorite,
                    iconColor: AppTheme.primaryRed,
                    value: _latestBpm > 0 ? '$_latestBpm' : '--',
                    label: 'BPM',
                  ),
                  PopupMenuButton<int>(
                    color: const Color(0xFF161A22),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    offset: const Offset(0, 60),
                    onSelected: _isPlaying ? null : (min) {
                      _changeTime(min);
                    },
                    itemBuilder: (context) => [1, 2, 3, 4, 5].map((min) {
                      return PopupMenuItem<int>(
                        value: min,
                        child: Text(
                          '$min Minute${min > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: _selectedMinutes == min ? Colors.cyan : Colors.white,
                            fontWeight: _selectedMinutes == min ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                    child: _buildTopCard(
                      icon: Icons.timer_outlined,
                      iconColor: Colors.blueAccent,
                      value: '${_selectedMinutes.toString().padLeft(2, '0')}:00',
                      label: 'Time',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Centerpiece
              SizedBox(
                width: 320,
                height: 320,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(320, 320),
                      painter: BreathingTrackPainter(_controller.value),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Glowing Lungs Image
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyan.withOpacity(0.3 * _controller.value),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/lungs.png',
                            width: 100 + (40 * _controller.value), // Scales from 100 to 140
                            height: 100 + (40 * _controller.value),
                            fit: BoxFit.contain,
                            color: Colors.cyanAccent.withOpacity(0.8), // Tint it cyan to match neon theme
                            colorBlendMode: BlendMode.modulate,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _instruction,
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            _instructionSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _timeText,
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Steps Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStepIndicator(1, 'Inhale', '${_inhaleSec} Sec', _currentPhase == 1, Colors.cyanAccent),
                  _buildLineConnection(_currentPhase == 1 || _currentPhase == 2),
                  _buildStepIndicator(2, 'Hold', '${_holdSec} Sec', _currentPhase == 2, Colors.blueAccent),
                  _buildLineConnection(_currentPhase == 2 || _currentPhase == 3),
                  _buildStepIndicator(3, 'Exhale', '${_exhaleSec} Sec', _currentPhase == 3, Colors.purpleAccent),
                ],
              ),
              const SizedBox(height: 30),

              // Tip Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF131824),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_border, color: Colors.tealAccent, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tip', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 6),
                          Text(
                            'Relax your shoulders, sit comfortably and focus on your breathing.',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Play / Stop Button
              GestureDetector(
                onTap: _togglePlay,
                child: Column(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0A0E17),
                        border: Border.all(color: AppTheme.primaryRed.withOpacity(0.5), width: 2),
                        boxShadow: _isPlaying ? [
                          BoxShadow(color: AppTheme.primaryRed.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
                        ] : [],
                      ),
                      child: Center(
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryRed,
                          ),
                          child: Icon(
                            _isPlaying ? Icons.stop : Icons.play_arrow,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isPlaying ? 'Stop Exercise' : 'Start Exercise',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopCard({required IconData icon, required Color iconColor, required String value, required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF131824),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String title, String time, bool isActive, Color color) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? color.withOpacity(0.2) : Colors.transparent,
            border: Border.all(color: isActive ? color : Colors.white.withOpacity(0.2), width: isActive ? 2 : 1),
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(color: isActive ? color : Colors.white54, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(color: isActive ? color : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Text(time, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
      ],
    );
  }

  Widget _buildLineConnection(bool isActive) {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.only(bottom: 30),
        color: isActive ? Colors.cyan.withOpacity(0.5) : Colors.white.withOpacity(0.1),
      ),
    );
  }
}

class BreathingTrackPainter extends CustomPainter {
  final double progress;

  BreathingTrackPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background track
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, bgPaint);

    // Glowing track
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: const [Colors.cyan, Colors.blueAccent, Colors.purpleAccent, Colors.cyan],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );

    final trackPaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      trackPaint,
    );

    // Thumb
    final thumbAngle = -math.pi / 2 + sweepAngle;
    final thumbX = center.dx + radius * math.cos(thumbAngle);
    final thumbY = center.dy + radius * math.sin(thumbAngle);
    
    // Thumb Glow
    final glowPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset(thumbX, thumbY), 16, glowPaint);

    // Thumb Core
    final thumbPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(thumbX, thumbY), 8, thumbPaint);
    
    // Inner Thumb Core
    final innerThumbPaint = Paint()..color = Colors.cyan;
    canvas.drawCircle(Offset(thumbX, thumbY), 4, innerThumbPaint);
  }

  @override
  bool shouldRepaint(covariant BreathingTrackPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
