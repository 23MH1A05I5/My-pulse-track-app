import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:math';
import '../models/bpm_record.dart';

class PdfGenerator {
  static Future<Uint8List> generateReport(List<BpmRecord> history) async {
    final pdf = pw.Document();

    int averageBpm = history.isEmpty ? 0 : (history.fold(0, (sum, r) => sum + r.bpm) / history.length).round();
    int maxBpm = history.isEmpty ? 0 : history.map((r) => r.bpm).reduce(max);
    int minBpm = history.isEmpty ? 0 : history.map((r) => r.bpm).reduce(min);

    // Sort history chronologically from newest to oldest
    final sortedHistory = List<BpmRecord>.from(history)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(),
            pw.SizedBox(height: 20),
            _buildSummary(averageBpm, maxBpm, minBpm),
            pw.SizedBox(height: 30),
            pw.Text(
              'Detailed Scan History',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
            ),
            pw.SizedBox(height: 12),
            _buildTable(sortedHistory),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PulseTrack Heart Rate Report',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Generated on: ${DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildSummary(int avg, int max, int min) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _buildSummaryBox('Average BPM', '$avg', PdfColors.red700),
        _buildSummaryBox('Maximum BPM', '$max', PdfColors.orange700),
        _buildSummaryBox('Minimum BPM', '$min', PdfColors.blue700),
      ],
    );
  }

  static pw.Widget _buildSummaryBox(String title, String value, PdfColor color) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: color, width: 2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.Text(value, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildTable(List<BpmRecord> records) {
    final headers = ['Date', 'Time', 'BPM', 'Status', 'SpO2', 'BP'];

    final data = records.map((record) {
      return [
        DateFormat('MMM dd, yyyy').format(record.timestamp),
        DateFormat('hh:mm a').format(record.timestamp),
        '${record.bpm}',
        record.status,
        record.spo2 != null ? '${record.spo2}%' : '--',
        (record.systolic != null && record.systolic! > 0) 
            ? '${record.systolic}/${record.diastolic}' 
            : '--',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
        5: pw.Alignment.center,
      },
    );
  }
}
