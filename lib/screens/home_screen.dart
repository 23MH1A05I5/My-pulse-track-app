import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/bpm_record.dart';
import '../theme/app_theme.dart';
import 'scan_screen.dart';
import 'dart:math' show Random;
import 'breathing_screen.dart';
import 'sleep_screen.dart';
import 'ai_chat_screen.dart';
import '../models/user_model.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onScanComplete;
  const HomeScreen({super.key, this.onScanComplete});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  BpmRecord? _latestRecord;
  List<BpmRecord> _history = [];
  bool _isLoading = true;
  Map<String, dynamic>? _healthStatus;
  Timer? _subscriptionTimer;
  Duration _remainingTime = Duration.zero;

  late AnimationController _animationController;
  late Animation<double> _heartScaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Default 60 BPM
    )..repeat();

    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.05,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.1,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_animationController);

    _startSubscriptionTimer();
    _fetchData();
  }

  void _startSubscriptionTimer() {
    _subscriptionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user?.subscriptionExpiry != null) {
        if (mounted) {
          setState(() {
            _remainingTime = authProvider.user!.subscriptionExpiry!.difference(
              DateTime.now(),
            );
            if (_remainingTime.isNegative) {
              _remainingTime = Duration.zero;
              authProvider.checkSubscription();
            }
          });
        }
      }
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "00d:00h:00m:00s";
    String days = duration.inDays.toString().padLeft(2, '0');
    String hours = (duration.inHours % 24).toString().padLeft(2, '0');
    String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "${days}d:${hours}h:${minutes}m:${seconds}s";
  }

  Widget _buildSubscriptionCard() {
    final user = Provider.of<AuthProvider>(context).user;
    if (user?.subscriptionType == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueAccent.withValues(alpha: 0.15),
            Colors.purpleAccent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Colors.blueAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user!.subscriptionType!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  'Premium Member',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'TIME LEFT',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
              Text(
                _formatDuration(_remainingTime),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _fetchData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user != null) {
      try {
        // Wait a bit for backend to process the new record
        await Future.delayed(const Duration(milliseconds: 1500));

        await authProvider.syncUserWithServer();
        
        final healthStatus = await authProvider.getHealthStatus();
        debugPrint('HEALTH STATUS UPDATED: $healthStatus');

        final latest = await _apiService.getLatest(user.id);
        final history = await _apiService.getHistory(user.id);

        if (mounted) {
          setState(() {
            _latestRecord = latest;
            _history = history.reversed.toList();
            _healthStatus = healthStatus;
            _isLoading = false;
          });

          if (latest != null && latest.bpm > 0) {
            int durationMs = (60000 / latest.bpm).round();
            durationMs = durationMs.clamp(333, 1500); // Between ~40 and 180 BPM
            _animationController.duration = Duration(milliseconds: durationMs);
            _animationController.repeat();
          }
        }
      } catch (e) {
        debugPrint('Error fetching data: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _subscriptionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1216),
      floatingActionButton: FloatingActionButton(
        heroTag: 'ai_chat_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AiChatScreen()),
          );
        },
        backgroundColor: const Color(0xFF6C63FF),
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchData,
          color: AppTheme.primaryRed,
          backgroundColor: const Color(0xFF161A22),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildTopBar(),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildStreakBadge(isBreathing: false),
                    _buildStreakBadge(isBreathing: true),
                  ],
                ),
                _buildSubscriptionCard(),
                const SizedBox(height: 32),
                _buildCenterPiece(),
                const SizedBox(height: 16),
                _buildBpmDisplay(),
                const SizedBox(height: 32),
                _buildStatCards(),
                const SizedBox(height: 24),
                _buildDailyGoalsCard(),
                const SizedBox(height: 24),
                _buildAIInsights(),
                const SizedBox(height: 24),
                _buildActionButtons(),
                const SizedBox(height: 32),
                _buildStartScanButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final user = Provider.of<AuthProvider>(context).user;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.menu, color: Colors.white, size: 20),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Hello, ${user?.name ?? 'Alex'} 👋',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Track your heart, track your life.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: const Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_none, color: Colors.white, size: 20),
              Positioned(
                right: 0,
                top: 0,
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: AppTheme.primaryRed,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakBadge({required bool isBreathing}) {
    final user = Provider.of<AuthProvider>(context).user;
    final streak = isBreathing
        ? (user?.breathingStreak ?? 0)
        : (user?.scanStreak ?? 0);

    if (streak == 0) return const SizedBox.shrink();

    final color = isBreathing ? Colors.cyanAccent : Colors.orange;
    final icon = isBreathing ? Icons.air : Icons.local_fire_department;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '$streak Day${streak > 1 ? 's' : ''} ${isBreathing ? 'Breathing' : 'Scanning'}!',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showStreakCelebration(int days, {bool isBreathing = false}) {
    String message = "Good!";
    if (days >= 3 && days < 5) message = "Keep it up!";
    if (days >= 5 && days < 7) message = "Excellent!";
    if (days >= 7 && days < 10) message = "Awesome!";
    if (days >= 10) message = "Unstoppable!";

    final color = isBreathing ? Colors.cyanAccent : Colors.orange;
    final icon = isBreathing ? Icons.air : Icons.local_fire_department;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) {
        // Auto-close after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (context.mounted) Navigator.pop(context);
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: color, size: 80),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                '${isBreathing ? 'RELAXATION' : 'CONSISTENCY'} MASTER!',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$days Day${days > 1 ? 's' : ''} ${isBreathing ? 'Breathing' : 'Streak'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 24,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 40),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 2,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCenterPiece() {
    return SizedBox(
      height: 240, // Reduced height since gauge is removed
      child: Stack(
        alignment: Alignment.center,
        children: [
          // EKG Line Animated
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return SizedBox(
                width: double.infinity,
                height: 120,
                child: CustomPaint(
                  painter: EKGPainter(_animationController.value),
                ),
              );
            },
          ),
          // Pumping Heart Image
          AnimatedBuilder(
            animation: _heartScaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale:
                    _heartScaleAnimation.value *
                    2.0, // Multiplier to force the image to display much larger
                child: Image.asset(
                  'assets/images/glowing_heart.png',
                  width: 2000,
                  height: 160,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.favorite,
                      color: AppTheme.primaryRed,
                      size: 140,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBpmDisplay() {
    int bpm = _latestRecord?.bpm ?? 0;
    String status = _latestRecord?.status ?? 'No Data';
    Color statusColor = status == 'Normal' ? Colors.green : Colors.orange;
    if (bpm == 0) statusColor = Colors.grey;

    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Gauge Meter Background wrapped around text
          SizedBox(
            width: 320,
            height: 180,
            child: CustomPaint(painter: GaugeMeterPainter(bpm)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24, // Push text slightly up from the bottom line
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Heart Rate ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(Icons.favorite, color: AppTheme.primaryRed, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _isLoading ? '--' : (bpm > 0 ? '$bpm' : '--'),
                      style: const TextStyle(
                        fontSize:
                            64, // Scaled down slightly to fit the gauge perfectly
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'BPM',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppTheme.primaryRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, color: statusColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSmallCard(
          Icons.favorite,
          AppTheme.primaryRed,
          '120/80',
          'Blood Pressure\nmmHg',
        ),
        _buildSmallCard(
          Icons.water_drop,
          Colors.blueAccent,
          '98%',
          'Oxygen Level\nSpO2',
        ),
        _buildSmallCard(
          Icons.local_fire_department,
          Colors.orangeAccent,
          '420',
          'Calories Burn\nkcal',
        ),
      ],
    );
  }

  Widget _buildSmallCard(
    IconData icon,
    Color iconColor,
    String value,
    String label,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161A22),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.1),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartScanButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: AppTheme.redGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRed.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final oldStreak =
                Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).user?.scanStreak ??
                0;
            // Push scan screen directly so it overlays the home view fully
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    title: const Text('Heart Scan'),
                    backgroundColor: Colors.transparent,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  extendBodyBehindAppBar: true,
                  body: ScanScreen(
                    isActive: true,
                    onScanComplete: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ).then((_) async {
              await _fetchData(); // Refresh once back
              widget.onScanComplete?.call(); // Trigger global refresh for history tab
              if (!mounted) return;
              final newStreak =
                  Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  ).user?.scanStreak ??
                  0;
              if (newStreak > oldStreak) {
                _showStreakCelebration(newStreak);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Heart Scan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Check your heart rate',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAIInsights() {
    int bpm = _latestRecord?.bpm ?? 0;
    if (bpm == 0) return const SizedBox.shrink();

    // Mock HRV derived from BPM
    int hrv = 120 - bpm + Random().nextInt(10);
    if (hrv < 20) hrv = 20;

    // Stress Level
    String stress = '🟢 Relaxed';
    Color stressColor = Colors.greenAccent;
    if (hrv < 40) {
      stress = '🔴 High Stress';
      stressColor = Colors.redAccent;
    } else if (hrv < 60) {
      stress = '🟡 Mild Stress';
      stressColor = Colors.orangeAccent;
    }

    // Health Score
    int score = 100 - (70 - bpm).abs() - (hrv < 40 ? 10 : 0);
    if (score > 100) score = 100;
    if (score < 40) score = 40;

    // AI Suggestion
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final targetMin = user?.healthGoals.minBpm ?? 60;
    final targetMax = user?.healthGoals.maxBpm ?? 90;

    String suggestion = "Your heart rate is stable. Keep up the good work!";
    if (bpm > targetMax) {
      suggestion =
          "Your heart rate is above your target range ($targetMax BPM). Try a breathing exercise to relax.";
    } else if (bpm < targetMin) {
      suggestion =
          "Your heart rate is below your target range ($targetMin BPM). If you're resting, this might be fine, but consult a doctor if you feel dizzy.";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryRed.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.psychology,
                color: AppTheme.primaryRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Health Analysis',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Score: $score/100',
                  style: const TextStyle(
                    color: AppTheme.primaryRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInsightColumn('HRV (ms)', '$hrv', color: Colors.white),
              _buildInsightColumn('Stress Level', stress, color: stressColor),
              _buildInsightColumn('Trend', 'Stable', color: Colors.blueAccent),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    suggestion,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightColumn(
    String label,
    String value, {
    Color color = Colors.white,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildModeButton(
            icon: Icons.air,
            label: 'Breathe',
            color: Colors.tealAccent,
            onTap: () {
              final oldStreak =
                  Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  ).user?.breathingStreak ??
                  0;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BreathingScreen(),
                ),
              ).then((_) async {
                await _fetchData();
                if (!mounted) return;
                final newStreak =
                    Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).user?.breathingStreak ??
                    0;
                if (newStreak > oldStreak) {
                  _showStreakCelebration(newStreak, isBreathing: true);
                }
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildModeButton(
            icon: Icons.bedtime,
            label: 'Sleep',
            color: Colors.indigoAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SleepScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyGoalsCard() {
    final user = Provider.of<AuthProvider>(context).user;
    final progress = _healthStatus?['progress'] ?? {'scansCompleted': 0, 'breathingMinutes': 0};
    final goals = user?.healthGoals ?? HealthGoals(minBpm: 60, maxBpm: 90, dailyScanGoal: 3, dailyBreathingGoal: 5, weeklyBpmTarget: 85);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Progress',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.stars, color: Colors.amber.withOpacity(0.8), size: 20),
            ],
          ),
          const SizedBox(height: 20),
          _buildGoalProgress(
            'Scans',
            progress['scansCompleted'] ?? 0,
            goals.dailyScanGoal,
            Colors.blueAccent,
            Icons.qr_code_scanner,
          ),
          const SizedBox(height: 16),
          _buildGoalProgress(
            'Breathing',
            progress['breathingMinutes'] ?? 0,
            goals.dailyBreathingGoal,
            Colors.tealAccent,
            Icons.air,
            unit: 'min',
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgress(String label, int current, int goal, Color color, IconData icon, {String? unit}) {
    double percent = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const Spacer(),
            Text(
              '$current/$goal${unit != null ? ' $unit' : ''}',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.white.withOpacity(0.05),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// Custom Painter for the 180-degree BPM Gauge Meter
class GaugeMeterPainter extends CustomPainter {
  final int bpm;

  GaugeMeterPainter(this.bpm);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height - 10,
    ); // Center at bottom edge
    final radius = size.width / 2 - 30; // More padding to fit ticks

    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // Vibrant Gradient from Cyan (Low) -> Green -> Yellow -> Orange -> Red (High)
    const gradient = SweepGradient(
      startAngle: math.pi,
      endAngle: 2 * math.pi,
      colors: [
        Colors.cyanAccent,
        Colors.greenAccent,
        Colors.yellowAccent,
        Colors.orangeAccent,
        Colors.redAccent,
      ],
      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
    );

    final bgPaint = Paint()
      ..shader = gradient.createShader(arcRect)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..shader = gradient.createShader(arcRect)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw full 180 degree track
    canvas.drawArc(arcRect, math.pi, math.pi, false, trackPaint);

    // Draw tick marks (outer ring)
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final majorTickPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const int tickCount = 28; // Marks from 40 to 180
    for (int i = 0; i <= tickCount; i++) {
      double tickAngle = math.pi + (i * (math.pi / tickCount));
      bool isMajor = i % 4 == 0;
      double tickLength = isMajor ? 12 : 6;
      double tickRadius = radius + 15; // Outside the arc

      Offset start = Offset(
        center.dx + tickRadius * math.cos(tickAngle),
        center.dy + tickRadius * math.sin(tickAngle),
      );
      Offset end = Offset(
        center.dx + (tickRadius + tickLength) * math.cos(tickAngle),
        center.dy + (tickRadius + tickLength) * math.sin(tickAngle),
      );

      canvas.drawLine(start, end, isMajor ? majorTickPaint : tickPaint);
    }

    double minBpm = 40.0;
    double maxBpm = 180.0;
    double currentBpm = bpm.toDouble().clamp(minBpm, maxBpm);

    // Default to 0 percent if no BPM reading
    double percent = bpm > 0 ? (currentBpm - minBpm) / (maxBpm - minBpm) : 0.0;

    // Draw colored arc up to the current BPM and its glow
    if (bpm > 0) {
      canvas.drawArc(arcRect, math.pi, math.pi * percent, false, glowPaint);
      canvas.drawArc(arcRect, math.pi, math.pi * percent, false, bgPaint);
    }

    // Draw Needle/Arrow
    final needleAngle = math.pi + (math.pi * percent);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(needleAngle);

    // Modern Needle Base
    final needleBasePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final needleAccentPaint = Paint()
      ..color = AppTheme.primaryRed
      ..style = PaintingStyle.fill;

    // Draw a sleek arrow shape
    final needlePath = Path()
      ..moveTo(0, -6)
      ..lineTo(radius - 10, -2) // Tip of arrow
      ..lineTo(radius - 5, 0) // Tip point
      ..lineTo(radius - 10, 2)
      ..lineTo(0, 6)
      ..close();

    // Add a shadow to the needle
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(needlePath, shadowPaint);

    canvas.drawPath(needlePath, needleBasePaint);

    // Inner red accent for the needle
    final accentPath = Path()
      ..moveTo(0, -2)
      ..lineTo(radius - 15, -1)
      ..lineTo(radius - 10, 0)
      ..lineTo(radius - 15, 1)
      ..lineTo(0, 2)
      ..close();

    canvas.drawPath(accentPath, needleAccentPaint);

    // Center pivot circle (layered)
    canvas.drawCircle(const Offset(0, 0), 12, needleBasePaint);
    canvas.drawCircle(const Offset(0, 0), 6, needleAccentPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GaugeMeterPainter oldDelegate) {
    return oldDelegate.bpm != bpm;
  }
}

// Custom Painter for the scrolling EKG line
class EKGPainter extends CustomPainter {
  final double animationValue;

  EKGPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryRed
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final double width = size.width;
    final double midY = size.height / 2;

    // Simplified seamless EKG wave
    final List<Offset> points = [
      const Offset(0, 0),
      const Offset(0.2, 0),
      const Offset(0.25, -0.2), // P
      const Offset(0.3, 0),
      const Offset(0.35, 0.2), // Q
      const Offset(0.4, -0.8), // R (peak)
      const Offset(0.45, 0.4), // S
      const Offset(0.5, 0),
      const Offset(0.65, 0),
      const Offset(0.75, -0.3), // T
      const Offset(0.85, 0),
      const Offset(1.0, 0),
    ];

    path.moveTo(0, midY);

    // Draw 3 segments shifting by the animation value to make it continuous
    for (double i = -1; i <= 2; i++) {
      double offsetX = (i - animationValue) * width;

      for (int j = 0; j < points.length; j++) {
        double px = offsetX + (points[j].dx * width);
        double py = midY + (points[j].dy * size.height * 0.4);
        if (j == 0 && i == -1) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
    }

    canvas.drawPath(path, paint);

    // Add glow
    final shadowPaint = Paint()
      ..color = AppTheme.primaryRed.withOpacity(0.5)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawPath(path, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant EKGPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
