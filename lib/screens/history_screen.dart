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
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  List<BpmRecord> _history = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0=Day, 1=Week, 2=Month
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      final history = await _apiService.getHistory(user.id);
      history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) setState(() { _history = history; _isLoading = false; });
    }
  }

  // ── Filtered lists ──────────────────────────────────────────────────────────
  List<BpmRecord> get _tabRecords {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_selectedTab) {
      case 0: return _history.where((r) {
        final d = DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
        return d.isAtSameMomentAs(today);
      }).toList();
      case 1: return _history.where((r) => !r.timestamp.isBefore(today.subtract(const Duration(days: 6)))).toList();
      case 2: return _history.where((r) => !r.timestamp.isBefore(today.subtract(const Duration(days: 29)))).toList();
      default: return _history;
    }
  }

  List<BpmRecord> get _displayedRecords {
    if (_filterStatus == 'All') return _tabRecords;
    return _tabRecords.where((r) => r.status.toLowerCase().contains(_filterStatus.toLowerCase())).toList();
  }

  // ── Stats ────────────────────────────────────────────────────────────────────
  int _avg(List<BpmRecord> r) => r.isEmpty ? 0 : (r.fold(0, (s, e) => s + e.bpm) / r.length).round();
  int _max(List<BpmRecord> r) => r.isEmpty ? 0 : r.map((e) => e.bpm).reduce(max);
  int _min(List<BpmRecord> r) => r.isEmpty ? 0 : r.map((e) => e.bpm).reduce(min);

  String get _tabLabel => ['Today', 'This Week', 'This Month'][_selectedTab];

  // ── Real Insights ─────────────────────────────────────────────────────────
  Map<String, dynamic> get _insights {
    final now = DateTime.now();
    final wStart = now.subtract(Duration(days: now.weekday - 1));
    final thisW = _history.where((r) => !r.timestamp.isBefore(wStart)).toList();
    final lastW = _history.where((r) => r.timestamp.isBefore(wStart) && !r.timestamp.isBefore(wStart.subtract(const Duration(days: 7)))).toList();

    if (thisW.isEmpty) return {'icon': Icons.info_outline, 'color': Colors.blueAccent, 'msg': 'No scans this week yet. Start scanning to see insights!'};

    final tAvg = _avg(thisW);
    if (lastW.isEmpty) return {'icon': Icons.trending_flat, 'color': Colors.blueAccent, 'msg': 'Your average BPM this week is $tAvg. Scan daily for trend analysis!'};

    final lAvg = _avg(lastW);
    final diff = tAvg - lAvg;
    final pct = lAvg > 0 ? ((diff.abs() / lAvg) * 100).round() : 0;
    if (diff < 0) return {'icon': Icons.trending_down, 'color': Colors.greenAccent, 'msg': 'Heart rate improved by $pct% this week ($lAvg → $tAvg BPM). Great work!'};
    if (diff > 0) return {'icon': Icons.trending_up, 'color': Colors.orange, 'msg': 'Average BPM increased by $pct% this week ($lAvg → $tAvg BPM). Rest and hydrate.'};
    return {'icon': Icons.trending_flat, 'color': Colors.blueAccent, 'msg': 'Heart rate is consistent at $tAvg BPM this week. Stability is a great sign!'};
  }

  // ── PDF ─────────────────────────────────────────────────────────────────────
  Future<void> _generatePdf() async {
    if (_history.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export'))); return; }
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...')));
      final bytes = await PdfGenerator.generateReport(_history);
      await Printing.sharePdf(bytes: bytes, filename: 'pulsetrack_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  // ── Filter Sheet ─────────────────────────────────────────────────────────
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161A22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Filter by Status', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: ['All', 'Normal', 'High', 'Low'].map((s) {
                final sel = _filterStatus == s;
                final c = s == 'High' ? Colors.red : s == 'Low' ? Colors.blue : s == 'Normal' ? Colors.green : AppTheme.primaryRed;
                return GestureDetector(
                  onTap: () { setState(() => _filterStatus = s); Navigator.pop(context); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? c.withOpacity(0.2) : const Color(0xFF1E2430),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? c : Colors.transparent, width: 1.5),
                    ),
                    child: Text(s, style: TextStyle(color: sel ? c : Colors.white70, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          IconButton(icon: Icon(Icons.picture_as_pdf, color: AppTheme.primaryRed.withOpacity(0.8)), onPressed: _generatePdf),
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildTabs(),
                  const SizedBox(height: 24),
                  _buildChartCard(),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  const SizedBox(height: 16),
                  _buildInsightsCard(),
                  const SizedBox(height: 24),
                  _buildListHeader(),
                  const SizedBox(height: 16),
                  _displayedRecords.isEmpty ? _buildEmptyState() : _buildList(),
                ]),
              ),
            ),
    );
  }

  // ── Tabs ─────────────────────────────────────────────────────────────────────
  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF161A22), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [0, 1, 2].map((i) {
        final sel = _selectedTab == i;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _selectedTab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: sel ? LinearGradient(colors: [AppTheme.primaryRed, AppTheme.primaryRed.withOpacity(0.6)]) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(['Day', 'Week', 'Month'][i], textAlign: TextAlign.center,
              style: TextStyle(color: sel ? Colors.white : Colors.grey, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
          ),
        ));
      }).toList()),
    );
  }

  // ── Chart ─────────────────────────────────────────────────────────────────────
  Widget _buildChartCard() {
    final records = _tabRecords;
    final dateRange = _selectedTab == 0
        ? DateFormat('MMM dd, yyyy').format(DateTime.now())
        : _selectedTab == 1
            ? '${DateFormat('MMM dd').format(DateTime.now().subtract(const Duration(days: 6)))} – ${DateFormat('MMM dd').format(DateTime.now())}'
            : '${DateFormat('MMM dd').format(DateTime.now().subtract(const Duration(days: 29)))} – ${DateFormat('MMM dd').format(DateTime.now())}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF161A22), borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Heart Rate — $_tabLabel', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(dateRange, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              const Icon(Icons.favorite, color: AppTheme.primaryRed, size: 16),
              const SizedBox(width: 4),
              Text('${_avg(records)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Text(' BPM', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
            const Text('Average', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ]),
        const SizedBox(height: 32),
        SizedBox(
          height: 180,
          child: records.isEmpty
              ? Center(child: Text('No data for $_tabLabel', style: const TextStyle(color: Colors.grey)))
              : _buildChart(records),
        ),
      ]),
    );
  }

  Widget _buildChart(List<BpmRecord> records) {
    final sorted = List<BpmRecord>.from(records)..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    List<FlSpot> spots = [];
    List<String> labels = [];
    double maxX = 24;

    if (_selectedTab == 0) {
      for (final r in sorted) spots.add(FlSpot(r.timestamp.hour + r.timestamp.minute / 60.0, r.bpm.toDouble()));
      labels = ['12AM', '6AM', '12PM', '6PM', '12AM'];
      maxX = 24;
    } else if (_selectedTab == 1) {
      final dayMap = <int, List<int>>{};
      for (final r in sorted) {
        final key = 6 - DateTime.now().difference(DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day)).inDays.clamp(0, 6);
        dayMap.putIfAbsent(key, () => []).add(r.bpm);
      }
      for (int i = 0; i <= 6; i++) {
        if (dayMap.containsKey(i)) spots.add(FlSpot(i.toDouble(), dayMap[i]!.fold(0, (s, v) => s + v) / dayMap[i]!.length));
      }
      labels = List.generate(7, (i) => DateFormat('E').format(DateTime.now().subtract(Duration(days: 6 - i))));
      maxX = 6;
    } else {
      final wkMap = <int, List<int>>{};
      for (final r in sorted) {
        final wk = (3 - (DateTime.now().difference(r.timestamp).inDays / 7).floor()).clamp(0, 3);
        wkMap.putIfAbsent(wk, () => []).add(r.bpm);
      }
      for (int i = 0; i <= 3; i++) {
        if (wkMap.containsKey(i)) spots.add(FlSpot(i.toDouble(), wkMap[i]!.fold(0, (s, v) => s + v) / wkMap[i]!.length));
      }
      labels = ['W1', 'W2', 'W3', 'W4'];
      maxX = 3;
    }

    if (spots.isEmpty) return const Center(child: Text('No data', style: TextStyle(color: Colors.grey)));
    if (spots.length == 1) spots = [FlSpot(spots[0].x > 0 ? spots[0].x - 0.5 : 0, spots[0].y), spots[0], FlSpot(spots[0].x + 0.5, spots[0].y)];

    final maxY = spots.map((s) => s.y).reduce(max);
    final minY = spots.map((s) => s.y).reduce(min);

    return LineChart(LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 30, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1)),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 30, reservedSize: 30,
          getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(right: 8), child: Text('${v.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 10))))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: _selectedTab == 0 ? 6 : 1,
          getTitlesWidget: (v, m) {
            final idx = (_selectedTab == 0 ? (v / 6).round() : v.round()).clamp(0, labels.length - 1);
            return SideTitleWidget(meta: m, child: Text(labels[idx], style: const TextStyle(color: Colors.grey, fontSize: 10)));
          })),
      ),
      borderData: FlBorderData(show: false),
      minX: 0, maxX: maxX, minY: 40, maxY: 150,
      lineBarsData: [LineChartBarData(
        spots: spots, isCurved: true, color: AppTheme.primaryRed, barWidth: 3, isStrokeCapRound: true,
        dotData: FlDotData(show: true, checkToShowDot: (s, _) => s.y == maxY || s.y == minY,
          getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 4, color: AppTheme.backgroundColor, strokeWidth: 2, strokeColor: AppTheme.primaryRed)),
        belowBarData: BarAreaData(show: true, gradient: LinearGradient(
          colors: [AppTheme.primaryRed.withOpacity(0.3), AppTheme.primaryRed.withOpacity(0.0)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      )],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1E2430), tooltipRoundedRadius: 8,
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${s.y.toInt()} BPM', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))).toList())),
    ));
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final r = _tabRecords;
    return Row(children: [
      Expanded(child: _statCard(Icons.favorite, AppTheme.primaryRed, '${_avg(r)}', 'Average')),
      const SizedBox(width: 12),
      Expanded(child: _statCard(Icons.local_fire_department, Colors.orange, '${_max(r)}', 'Maximum')),
      const SizedBox(width: 12),
      Expanded(child: _statCard(Icons.water_drop, Colors.blue, '${_min(r)}', 'Minimum')),
    ]);
  }

  Widget _statCard(IconData icon, Color color, String val, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: const Color(0xFF161A22), borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: 8),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Text(' BPM', style: TextStyle(color: Colors.grey, fontSize: 10)),
        ]),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    );
  }

  // ── Insights ──────────────────────────────────────────────────────────────────
  Widget _buildInsightsCard() {
    final d = _insights;
    final color = d['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF161A22), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(d['icon'] as IconData, color: color, size: 24)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Weekly Insights', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(d['msg'] as String, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
        ])),
      ]),
    );
  }

  // ── List Header ──────────────────────────────────────────────────────────────
  Widget _buildListHeader() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Records — $_tabLabel${_filterStatus != 'All' ? ' · $_filterStatus' : ''}',
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      Row(children: [
        if (_filterStatus != 'All')
          GestureDetector(
            onTap: () => setState(() => _filterStatus = 'All'),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppTheme.primaryRed.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primaryRed.withOpacity(0.4))),
              child: Row(children: [
                Text(_filterStatus, style: const TextStyle(color: AppTheme.primaryRed, fontSize: 11)),
                const SizedBox(width: 4),
                const Icon(Icons.close, color: AppTheme.primaryRed, size: 12),
              ]),
            ),
          ),
        GestureDetector(
          onTap: _showFilterSheet,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF161A22), borderRadius: BorderRadius.circular(12),
              border: _filterStatus != 'All' ? Border.all(color: AppTheme.primaryRed.withOpacity(0.5)) : null,
            ),
            child: Icon(Icons.filter_list, color: _filterStatus != 'All' ? AppTheme.primaryRed : Colors.white, size: 18),
          ),
        ),
      ]),
    ]);
  }

  // ── History List ─────────────────────────────────────────────────────────────
  Widget _buildList() {
    final records = _displayedRecords;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final r = records[index];
        final isDay = r.timestamp.hour >= 6 && r.timestamp.hour < 18;
        final statusColor = r.status.toLowerCase().contains('high') ? Colors.red : r.status.toLowerCase().contains('low') ? Colors.blue : Colors.green;

        return GestureDetector(
          onTap: () => Navigator.push(context, PageRouteBuilder(
            pageBuilder: (_, __, ___) => ResultScreen(bpm: r.bpm, status: r.status,),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          )),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF161A22), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: (isDay ? Colors.orange : Colors.deepPurple).withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(isDay ? Icons.wb_sunny_outlined : Icons.nightlight_round, color: isDay ? Colors.orange : Colors.deepPurpleAccent),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(DateFormat('hh:mm a').format(r.timestamp), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(DateFormat('MMM d, yyyy').format(r.timestamp), style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ]),
              const Spacer(),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('${r.bpm}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Text(' BPM', style: TextStyle(color: Colors.grey, fontSize: 10)),
              ]),
              const SizedBox(width: 12),
              Container(
                width: 60, padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text(r.status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.withOpacity(0.3)),
      const SizedBox(height: 16),
      Text('No records for $_tabLabel${_filterStatus != 'All' ? ' ($_filterStatus)' : ''}', style: const TextStyle(color: Colors.grey, fontSize: 16)),
      if (_filterStatus != 'All') ...[
        const SizedBox(height: 12),
        TextButton(onPressed: () => setState(() => _filterStatus = 'All'), child: const Text('Clear filter', style: TextStyle(color: AppTheme.primaryRed))),
      ]
    ]));
  }
}
