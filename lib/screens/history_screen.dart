import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';
import 'dart:math';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/bpm_record.dart';
import '../theme/app_theme.dart';
import '../utils/pdf_generator.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  List<BpmRecord> _history = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Day, 1: Week, 2: Month

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      final history = await _apiService.getHistory(user.id);
      // Sort history descending by timestamp
      history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) {
        setState(() {
          _history = history;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _generateAndSharePdf() async {
    if (_history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to generate report')),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF Report...')),
      );
      
      final pdfBytes = await PdfGenerator.generateReport(_history);
      
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'pulsetrack_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  int get _averageBpm {
    if (_history.isEmpty) return 0;
    return (_history.fold(0, (sum, record) => sum + record.bpm) / _history.length).round();
  }

  int get _maxBpm {
    if (_history.isEmpty) return 0;
    return _history.map((r) => r.bpm).reduce(max);
  }

  int get _minBpm {
    if (_history.isEmpty) return 0;
    return _history.map((r) => r.bpm).reduce(min);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: AppTheme.primaryRed.withOpacity(0.8)),
            tooltip: 'Generate PDF Report',
            onPressed: () => _generateAndSharePdf(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchHistory,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSegmentedControl(),
                    const SizedBox(height: 24),
                    _buildChartCard(),
                    const SizedBox(height: 16),
                    _buildStatsRow(),
                    const SizedBox(height: 16),
                    _buildAdvancedAnalytics(),
                    const SizedBox(height: 24),
                    _buildListHeader(),
                    const SizedBox(height: 16),
                    _history.isEmpty ? _buildEmptyState() : _buildHistoryList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSegmentItem(0, 'Day'),
          _buildSegmentItem(1, 'Week'),
          _buildSegmentItem(2, 'Month'),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(colors: [AppTheme.primaryRed, AppTheme.primaryRed.withOpacity(0.6)])
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Heart Rate - Today', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(DateFormat('MMM dd, yyyy').format(DateTime.now()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 4),
                      const Icon(Icons.calendar_today, color: Colors.grey, size: 12),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: AppTheme.primaryRed, size: 16),
                      const SizedBox(width: 4),
                      Text('$_averageBpm', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text(' BPM', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const Text('Average', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 180,
            child: _history.isEmpty ? const Center(child: Text('No data for today', style: TextStyle(color: Colors.grey))) : _buildFlChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildFlChart() {
    List<FlSpot> spots = [];
    
    // Sort chronological for chart (oldest to newest)
    final chartData = List<BpmRecord>.from(_history)..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (int i = 0; i < chartData.length; i++) {
      double x = (chartData.length > 1) ? (i / (chartData.length - 1)) * 4.0 : 2.0;
      spots.add(FlSpot(x, chartData[i].bpm.toDouble()));
    }

    if (spots.length == 1) {
      spots.add(FlSpot(3.0, chartData[0].bpm.toDouble()));
      spots.insert(0, FlSpot(1.0, chartData[0].bpm.toDouble()));
    }
    
    // Find max and min spots for tooltips
    double maxY = spots.map((s) => s.y).reduce(max);
    double minY = spots.map((s) => s.y).reduce(min);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 30,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 30,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('${value.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ),
              reservedSize: 30,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(color: Colors.grey, fontSize: 10);
                Widget text;
                switch (value.toInt()) {
                  case 0: text = const Text('12 AM', style: style); break;
                  case 1: text = const Text('6 AM', style: style); break;
                  case 2: text = const Text('12 PM', style: style); break;
                  case 3: text = const Text('6 PM', style: style); break;
                  case 4: text = const Text('12 AM', style: style); break;
                  default: text = const Text('', style: style); break;
                }
                return SideTitleWidget(meta: meta, child: text);
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 4,
        minY: 0,
        maxY: 150,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primaryRed,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) {
                return spot.y == maxY || spot.y == minY; // Only show dots for max/min
              },
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppTheme.backgroundColor,
                  strokeWidth: 2,
                  strokeColor: AppTheme.primaryRed,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryRed.withOpacity(0.3),
                  AppTheme.primaryRed.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (LineBarSpot touchedSpot) => AppTheme.primaryRed,
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                return LineTooltipItem(
                  '${touchedSpot.y.toInt()} BPM',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatItem(Icons.favorite, AppTheme.primaryRed, '$_averageBpm', 'Average')),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem(Icons.local_fire_department, Colors.orange, '$_maxBpm', 'Maximum')),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem(Icons.water_drop, Colors.blue, '$_minBpm', 'Minimum')),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const Text(' BPM', style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('All Records - Today', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF161A22),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Text('All', style: TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 16),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF161A22),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.filter_list, color: Colors.white, size: 16),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedAnalytics() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.trending_down, color: Colors.greenAccent, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Weekly Insights', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Your resting heart rate improved by 5% this week. Great job staying active!', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final record = _history[index];
        final isDay = record.timestamp.hour >= 6 && record.timestamp.hour < 18;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161A22),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDay ? Colors.orange.withOpacity(0.1) : Colors.deepPurple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDay ? Icons.wb_sunny_outlined : Icons.nightlight_round, 
                  color: isDay ? Colors.orange : Colors.deepPurpleAccent,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('hh:mm a').format(record.timestamp),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(record.timestamp),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${record.bpm}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text(' BPM', style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
              const Spacer(),
              _buildSmallBadge(record.status),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSmallBadge(String status) {
    Color color;
    if (status.toLowerCase().contains('high')) {
      color = Colors.red;
    } else if (status.toLowerCase().contains('low')) {
      color = Colors.blue;
    } else {
      color = Colors.green;
    }
    
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          status,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No records yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}
