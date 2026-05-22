/// PulseTrack — Production PDF Report Generator
/// Generates a doctor-ready A4 report with:
///   • Patient details section
///   • Stats summary cards (avg, max, min BPM)
///   • Heart rate chart (bar graph)
///   • Signal quality column
///   • Confidence column
///   • AI health recommendations section
///   • Full scan history table
///   • Professional styling & branding
library;

import 'dart:math';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/bpm_record.dart';

class PdfGenerator {
  // ── Colour palette (dark-red brand) ────────────────────────────────────────
  static const _brand = PdfColor.fromInt(0xFFCC0000);      // deep red
  static const _brandLight = PdfColor.fromInt(0xFFFF4D4D); // bright red
  static const _bg = PdfColor.fromInt(0xFFF8F9FA);
  static const _surface = PdfColors.white;
  static const _textDark = PdfColor.fromInt(0xFF1A1A2E);
  static const _textMid = PdfColor.fromInt(0xFF6B7280);
  static const _green = PdfColor.fromInt(0xFF16A34A);
  static const _amber = PdfColor.fromInt(0xFFD97706);
  static const _blue = PdfColor.fromInt(0xFF1D4ED8);

  // ── Public entry point ──────────────────────────────────────────────────────

  /// Generate a complete PDF health report.
  /// [history] should be sorted newest-first.
  /// [patientName] and [patientEmail] are shown in the header.
  static Future<Uint8List> generateReport(
    List<BpmRecord> history, {
    String patientName = 'Patient',
    String patientEmail = '',
    List<String> aiRecommendations = const [],
  }) async {
    final pdf = pw.Document(
      title: 'PulseTrack Health Report',
      author: 'PulseTrack AI',
      subject: 'Heart Rate Monitoring Report',
    );

    // Sort newest-first for display
    final sorted = List<BpmRecord>.from(history)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Compute stats
    final bpms = history.map((r) => r.bpm).toList();
    final avgBpm = bpms.isEmpty ? 0 : (bpms.reduce((a, b) => a + b) / bpms.length).round();
    final maxBpm = bpms.isEmpty ? 0 : bpms.reduce(max);
    final minBpm = bpms.isEmpty ? 0 : bpms.reduce(min);
    final avgConf = history.where((r) => r.confidence != null).isEmpty
        ? null
        : (history
                .where((r) => r.confidence != null)
                .map((r) => r.confidence!)
                .reduce((a, b) => a + b) /
            history.where((r) => r.confidence != null).length);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          buildBackground: (context) => pw.Container(color: _bg),
        ),
        build: (ctx) => [
          _buildHeader(patientName, patientEmail),
          pw.SizedBox(height: 20),
          _buildStatCards(avgBpm, maxBpm, minBpm, avgConf),
          pw.SizedBox(height: 24),
          _buildBpmChart(sorted),
          pw.SizedBox(height: 24),
          if (aiRecommendations.isNotEmpty) ...[
            _buildAiSection(aiRecommendations),
            pw.SizedBox(height: 24),
          ],
          _buildHistoryTableHeader(),
          pw.SizedBox(height: 8),
          _buildHistoryTable(sorted),
          pw.SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(String name, String email) {
    final now = DateTime.now();
    final dateStr = DateFormat('MMMM dd, yyyy').format(now);
    final timeStr = DateFormat('hh:mm a').format(now);

    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_brand, _brandLight],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '💓 PulseTrack',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Heart Rate Monitoring Report',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                name,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              if (email.isNotEmpty)
                pw.Text(email, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: $dateStr at $timeStr',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey300),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stat Cards ──────────────────────────────────────────────────────────────

  static pw.Widget _buildStatCards(int avg, int max, int min, double? avgConf) {
    return pw.Row(
      children: [
        _statCard('Average BPM', '$avg', _brand, '❤'),
        pw.SizedBox(width: 12),
        _statCard('Maximum BPM', '$max', _amber, '↑'),
        pw.SizedBox(width: 12),
        _statCard('Minimum BPM', '$min', _blue, '↓'),
        pw.SizedBox(width: 12),
        _statCard(
          'Avg Confidence',
          avgConf != null ? '${avgConf.toInt()}%' : 'N/A',
          _green,
          '✓',
        ),
      ],
    );
  }

  static pw.Widget _statCard(String title, String value, PdfColor color, String icon) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: _surface,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          border: pw.Border.all(color: color, width: 1.5),
          boxShadow: const [pw.BoxShadow(color: PdfColors.grey200, blurRadius: 4)],
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 9, color: _textMid)),
            pw.SizedBox(height: 6),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  // ── BPM Chart ───────────────────────────────────────────────────────────────

  static pw.Widget _buildBpmChart(List<BpmRecord> records) {
    // Show last 15 records in chart
    final chartData = records.take(15).toList().reversed.toList();
    if (chartData.isEmpty) return pw.SizedBox();

    final maxVal = chartData.map((r) => r.bpm).reduce(max).toDouble();
    final chartHeight = 80.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Heart Rate Trend (Last ${chartData.length} Scans)',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _textDark),
          ),
          pw.SizedBox(height: 12),
          pw.SizedBox(
            height: chartHeight,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: chartData.map((r) {
                final ratio = maxVal > 0 ? r.bpm / maxVal : 0.5;
                final barH = (ratio * chartHeight).clamp(6.0, chartHeight);
                final barColor = r.bpm > 100
                    ? _brandLight
                    : r.bpm < 60
                        ? _blue
                        : _green;
                return pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('${r.bpm}', style: pw.TextStyle(fontSize: 7, color: _textMid)),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      width: 14,
                      height: barH,
                      decoration: pw.BoxDecoration(
                        color: barColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      DateFormat('d/M').format(r.timestamp),
                      style: pw.TextStyle(fontSize: 6, color: _textMid),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          pw.SizedBox(height: 8),
          // Legend
          pw.Row(
            children: [
              _legendDot(_green), pw.SizedBox(width: 4),
              pw.Text('Normal (60–100)', style: pw.TextStyle(fontSize: 8, color: _textMid)),
              pw.SizedBox(width: 12),
              _legendDot(_brandLight), pw.SizedBox(width: 4),
              pw.Text('High (>100)', style: pw.TextStyle(fontSize: 8, color: _textMid)),
              pw.SizedBox(width: 12),
              _legendDot(_blue), pw.SizedBox(width: 4),
              pw.Text('Low (<60)', style: pw.TextStyle(fontSize: 8, color: _textMid)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _legendDot(PdfColor color) => pw.Container(
        width: 8, height: 8,
        decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
      );

  // ── AI Recommendations ──────────────────────────────────────────────────────

  static pw.Widget _buildAiSection(List<String> tips) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF0FDF4),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: _green, width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 6, height: 6,
                decoration: const pw.BoxDecoration(color: _green, shape: pw.BoxShape.circle),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'AI Health Recommendations',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _green),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          ...tips.map((tip) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ', style: pw.TextStyle(color: _green, fontWeight: pw.FontWeight.bold)),
                    pw.Expanded(
                      child: pw.Text(tip, style: pw.TextStyle(fontSize: 10, color: _textDark)),
                    ),
                  ],
                ),
              )),
          pw.SizedBox(height: 6),
          pw.Text(
            'Disclaimer: These recommendations are AI-generated for informational purposes only. '
            'Always consult a qualified healthcare professional for medical advice.',
            style: pw.TextStyle(fontSize: 8, color: _textMid, fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    );
  }

  // ── History Table ───────────────────────────────────────────────────────────

  static pw.Widget _buildHistoryTableHeader() {
    return pw.Text(
      'Detailed Scan History',
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _textDark),
    );
  }

  static pw.Widget _buildHistoryTable(List<BpmRecord> records) {
    if (records.isEmpty) {
      return pw.Center(
        child: pw.Text('No scan records found.', style: pw.TextStyle(color: _textMid)),
      );
    }

    final headers = ['Date', 'Time', 'BPM', 'Status', 'SpO2', 'BP (mmHg)', 'Confidence', 'Quality'];

    final data = records.map((r) {
      return [
        DateFormat('MMM dd, yyyy').format(r.timestamp),
        DateFormat('hh:mm a').format(r.timestamp),
        '${r.bpm}',
        r.status,
        r.spo2 != null ? '${r.spo2}%' : '—',
        (r.systolic != null && r.systolic! > 0) ? '${r.systolic}/${r.diastolic}' : '—',
        r.confidence != null ? '${r.confidence!.toInt()}%' : '—',
        r.signalQuality ?? '—',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: _brand),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellHeight: 26,
      rowDecoration: pw.BoxDecoration(color: _surface),
      oddRowDecoration: pw.BoxDecoration(color: _bg),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
        5: pw.Alignment.center,
        6: pw.Alignment.center,
        7: pw.Alignment.center,
      },
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'PulseTrack Health Monitor v2.0',
            style: pw.TextStyle(fontSize: 8, color: _textMid),
          ),
          pw.Text(
            'This report is for informational purposes only — not a medical diagnosis.',
            style: pw.TextStyle(fontSize: 8, color: _textMid, fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

