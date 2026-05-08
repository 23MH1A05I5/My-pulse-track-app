import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';

class HealthGoalsScreen extends StatefulWidget {
  const HealthGoalsScreen({super.key});

  @override
  State<HealthGoalsScreen> createState() => _HealthGoalsScreenState();
}

class _HealthGoalsScreenState extends State<HealthGoalsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late double _minBpm;
  late double _maxBpm;
  late int _dailyScanGoal;
  late int _dailyBreathingGoal;
  late int _weeklyBpmTarget;
  bool _isLoading = false;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final goals = user?.healthGoals ?? HealthGoals(
      minBpm: 60,
      maxBpm: 90,
      dailyScanGoal: 3,
      dailyBreathingGoal: 5,
      weeklyBpmTarget: 85,
    );
    _minBpm = goals.minBpm.toDouble();
    _maxBpm = goals.maxBpm.toDouble();
    _dailyScanGoal = goals.dailyScanGoal;
    _dailyBreathingGoal = goals.dailyBreathingGoal;
    _weeklyBpmTarget = goals.weeklyBpmTarget;
    _fetchStatus();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final status = await Provider.of<AuthProvider>(context, listen: false).getHealthStatus();
      if (mounted && status != null) {
        setState(() {
          _status = status;
          final goals = HealthGoals.fromJson(status['healthGoals'] ?? {});
          _minBpm = goals.minBpm.toDouble();
          _maxBpm = goals.maxBpm.toDouble();
          _dailyScanGoal = goals.dailyScanGoal;
          _dailyBreathingGoal = goals.dailyBreathingGoal;
          _weeklyBpmTarget = goals.weeklyBpmTarget;
        });
      }
    } catch (e) {
      debugPrint('Error fetching health status: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveGoals() async {
    setState(() => _isLoading = true);
    final goals = HealthGoals(
      minBpm: _minBpm.toInt(),
      maxBpm: _maxBpm.toInt(),
      dailyScanGoal: _dailyScanGoal,
      dailyBreathingGoal: _dailyBreathingGoal,
      weeklyBpmTarget: _weeklyBpmTarget,
    );

    final success = await Provider.of<AuthProvider>(context, listen: false).updateHealthGoals(goals);
    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Health goals updated!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Health Goals',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryRed,
          labelColor: AppTheme.primaryRed,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Setup'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildSetupTab(),
        ],
      ),
      bottomNavigationBar: _isLoading || _tabController.index == 0 
        ? null 
        : Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _saveGoals,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save My Goals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
    );
  }

  Widget _buildOverviewTab() {
    if (_status == null && _isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRed),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchStatus,
      color: AppTheme.primaryRed,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressSection(),
            const SizedBox(height: 30),
            _buildSectionTitle('Active Streaks'),
            _buildStreaksSection(),
            const SizedBox(height: 30),
            _buildAchievementSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Target Heart Rate Range'),
          _buildBpmRangeSelector(),
          const SizedBox(height: 24),
          _buildGoalCounter(
            'Daily Scan Goal',
            _dailyScanGoal,
            (val) => setState(() => _dailyScanGoal = val),
            'scans per day',
          ),
          const SizedBox(height: 24),
          _buildGoalCounter(
            'Daily Breathing Goal',
            _dailyBreathingGoal,
            (val) => setState(() => _dailyBreathingGoal = val),
            'minutes daily',
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Weekly Health Target (Avg BPM)'),
          _buildWeeklyTargetSlider(),
          const SizedBox(height: 100), // Space for button
        ],
      ),
    );
  }

  Widget _buildStreaksSection() {
    final user = Provider.of<AuthProvider>(context).user;
    final scanStreak = user?.scanStreak ?? 0;
    final breatheStreak = user?.breathingStreak ?? 0;

    return Row(
      children: [
        _buildStreakCard('Scanning', scanStreak, Colors.orange, Icons.local_fire_department),
        const SizedBox(width: 16),
        _buildStreakCard('Breathing', breatheStreak, Colors.cyanAccent, Icons.air),
      ],
    );
  }

  Widget _buildStreakCard(String title, int days, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF131824),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 12),
            Text('$days Days', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final progress = _status?['progress'] ?? {'scansCompleted': 0, 'breathingMinutes': 0};
    final scanGoal = _dailyScanGoal;
    final breathingGoal = _dailyBreathingGoal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121417),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Today\'s Performance', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Icon(Icons.insights, color: AppTheme.primaryRed),
            ],
          ),
          const SizedBox(height: 20),
          _buildProgressBar('Scans', progress['scansCompleted'], scanGoal, Colors.blue),
          const SizedBox(height: 16),
          _buildProgressBar('Breathing', progress['breathingMinutes'], breathingGoal, Colors.green),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, int current, int goal, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            Text('$current / $goal', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0,
            backgroundColor: Colors.white.withOpacity(0.05),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildBpmRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_minBpm.toInt()} BPM', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('${_maxBpm.toInt()} BPM', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          RangeSlider(
            values: RangeValues(_minBpm, _maxBpm),
            min: 40,
            max: 200,
            divisions: 160,
            activeColor: AppTheme.primaryRed,
            inactiveColor: Colors.grey[800],
            labels: RangeLabels('${_minBpm.toInt()}', '${_maxBpm.toInt()}'),
            onChanged: (RangeValues values) {
              setState(() {
                _minBpm = values.start;
                _maxBpm = values.end;
              });
            },
          ),
          const Text('Adjust your target heart rate range', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGoalCounter(String title, int value, Function(int) onChanged, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$value $unit', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                    onPressed: value > 0 ? () => onChanged(value - 1) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryRed),
                    onPressed: () => onChanged(value + 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyTargetSlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${_weeklyBpmTarget.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              const Text('BPM', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
          Slider(
            value: _weeklyBpmTarget.toDouble(),
            min: 50,
            max: 120,
            divisions: 70,
            activeColor: AppTheme.primaryRed,
            onChanged: (val) => setState(() => _weeklyBpmTarget = val.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementSection() {
    final achievements = _status?['achievements'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Achievements'),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildBadge('7 days streak', Icons.local_fire_department, Colors.orange, achievements.contains('7 days streak')),
              _buildBadge('Stable heart rate', Icons.favorite, Colors.green, achievements.contains('Stable heart rate')),
              _buildBadge('Consistent breathing', Icons.self_improvement, Colors.purple, achievements.contains('Consistent breathing')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String title, IconData icon, Color color, bool earned) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: earned ? color.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: earned ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: earned ? color : Colors.grey, size: 30),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: earned ? Colors.white : Colors.grey, fontSize: 10, fontWeight: earned ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
