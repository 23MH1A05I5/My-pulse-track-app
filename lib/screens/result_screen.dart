import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/bpm_record.dart';
import '../theme/app_theme.dart';

class ResultScreen extends StatefulWidget {
  final int bpm;
  const ResultScreen({super.key, required this.bpm});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final ApiService _apiService = ApiService();
  bool _isSaving = false;

  void _saveRecord() async {
    setState(() => _isSaving = true);
    
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      String status = 'Normal';
      if (widget.bpm < 60) status = 'Low';
      if (widget.bpm > 100) status = 'High';

      final record = BpmRecord(
        userId: user.id,
        bpm: widget.bpm,
        status: status,
        timestamp: DateTime.now(),
      );

      final success = await _apiService.addRecord(record);
      
      setState(() => _isSaving = false);
      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record saved successfully!')),
        );
        Navigator.of(context).pop(); // Go back to Home/Scan
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save record.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String status = 'Normal';
    if (widget.bpm < 60) status = 'Low';
    if (widget.bpm > 100) status = 'High';

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Your heart rate is', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${widget.bpm}',
                  style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: AppTheme.primaryRed),
                ),
                const SizedBox(width: 8),
                const Text('BPM', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: status == 'Normal' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: status == 'Normal' ? Colors.green : Colors.orange,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 60),
            _buildInfoCard(),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveRecord,
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE RECORD'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Discard', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey),
                SizedBox(width: 12),
                Text('Health Tip', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.bpm > 100 
                ? 'Your heart rate is a bit high. Try to relax and take deep breaths.'
                : 'Your heart rate is in a healthy range. Keep up the good work!',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
