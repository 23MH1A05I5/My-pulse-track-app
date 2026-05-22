/// PulseTrack — Flutter Widget & Service Tests
/// Run: flutter test
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pulse_track/models/bpm_record.dart';
import 'package:pulse_track/models/user_model.dart';
import 'package:pulse_track/services/rppg_service.dart';
import 'package:pulse_track/utils/validators.dart';
import 'package:pulse_track/widgets/signal_quality_widget.dart';
import 'package:pulse_track/widgets/live_bpm_widget.dart';
import 'package:pulse_track/theme/app_theme.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    );

// ── Validator Tests ───────────────────────────────────────────────────────────

void main() {
  group('Validators', () {
    test('email — valid', () {
      expect(Validators.email('user@example.com'), isNull);
    });

    test('email — invalid format', () {
      expect(Validators.email('not-an-email'), isNotNull);
    });

    test('email — empty', () {
      expect(Validators.email(''), isNotNull);
    });

    test('password — strong', () {
      expect(Validators.password('StrongPass1'), isNull);
    });

    test('password — too short', () {
      expect(Validators.password('Ab1'), isNotNull);
    });

    test('password — no uppercase', () {
      expect(Validators.password('weakpass1'), isNotNull);
    });

    test('password — no digit', () {
      expect(Validators.password('NoDigitPass'), isNotNull);
    });

    test('otp — valid 6-digit', () {
      expect(Validators.otp('123456'), isNull);
    });

    test('otp — too short', () {
      expect(Validators.otp('12345'), isNotNull);
    });

    test('otp — non-numeric', () {
      expect(Validators.otp('12345X'), isNotNull);
    });

    test('confirmPassword — match', () {
      expect(Validators.confirmPassword('Pass123!', 'Pass123!'), isNull);
    });

    test('confirmPassword — mismatch', () {
      expect(Validators.confirmPassword('Pass123!', 'Different!'), isNotNull);
    });
  });

  // ── BpmRecord Model Tests ────────────────────────────────────────────────────

  group('BpmRecord', () {
    test('fromJson — basic fields', () {
      final json = {
        '_id': 'abc123',
        'userId': 'user1',
        'bpm': 72,
        'status': 'Normal',
        'timestamp': '2025-01-01T10:00:00.000Z',
      };
      final record = BpmRecord.fromJson(json);
      expect(record.bpm, 72);
      expect(record.status, 'Normal');
      expect(record.id, 'abc123');
    });

    test('fromJson — vitals fields', () {
      final json = {
        'userId': 'user1',
        'bpm': 75,
        'status': 'Normal',
        'spo2': 98,
        'systolic': 120,
        'diastolic': 80,
        'confidence': 87.5,
        'signalQuality': 'Excellent',
        'timestamp': '2025-01-01T10:00:00.000Z',
      };
      final record = BpmRecord.fromJson(json);
      expect(record.spo2, 98);
      expect(record.systolic, 120);
      expect(record.confidence, 87.5);
      expect(record.signalQuality, 'Excellent');
      expect(record.isHighConfidence, isTrue);
    });

    test('fromJson — legacy packed vitals', () {
      final json = {
        'userId': 'user1',
        'bpm': 80,
        'status': 'Normal [V:97,118,78]',
        'timestamp': '2025-01-01T10:00:00.000Z',
      };
      final record = BpmRecord.fromJson(json);
      expect(record.status, 'Normal');
      expect(record.spo2, 97);
      expect(record.systolic, 118);
      expect(record.diastolic, 78);
    });

    test('toJson — includes all fields', () {
      final record = BpmRecord(
        userId: 'user1',
        bpm: 72,
        status: 'Normal',
        spo2: 98,
        systolic: 120,
        diastolic: 80,
        confidence: 90.0,
        signalQuality: 'Excellent',
        timestamp: DateTime.now(),
      );
      final json = record.toJson();
      expect(json['bpm'], 72);
      expect(json['confidence'], 90.0);
      expect(json['signalQuality'], 'Excellent');
    });

    test('confidenceLabel — formatted', () {
      final r = BpmRecord(
        userId: 'u',
        bpm: 72,
        status: 'Normal',
        timestamp: DateTime.now(),
        confidence: 87.4,
      );
      expect(r.confidenceLabel, '87%');
    });

    test('confidenceLabel — null', () {
      final r = BpmRecord(
        userId: 'u',
        bpm: 72,
        status: 'Normal',
        timestamp: DateTime.now(),
      );
      expect(r.confidenceLabel, 'N/A');
    });
  });

  // ── RppgService Local Calculation Tests ──────────────────────────────────────

  group('RppgService', () {
    late RppgService svc;

    setUp(() {
      svc = RppgService();
      svc.clearBuffer();
    });

    test('empty buffer returns 0 BPM', () {
      expect(svc.calculateBpm(), 0);
    });

    test('insufficient buffer (<90 frames) returns 0 BPM', () {
      for (int i = 0; i < 50; i++) {
        svc.addSignal(150, 160, 140);
      }
      expect(svc.calculateBpm(), 0);
    });

    test('calculateLocalQuality — insufficient returns invalid', () {
      final result = svc.calculateLocalQuality();
      expect(result.quality, SignalQuality.invalid);
      expect(result.confidence, 0);
    });

    test('addSignal — buffer grows', () {
      svc.addSignal(150, 160, 140);
      svc.addSignal(151, 161, 141);
      expect(svc.bufferLength, 2);
    });

    test('clearBuffer — resets', () {
      svc.addSignal(150, 160, 140);
      svc.clearBuffer();
      expect(svc.bufferLength, 0);
    });

    test('spo2 — zero on empty buffer', () {
      expect(svc.calculateSpo2(), 0);
    });

    test('calculateBp — returns valid ranges for normal BPM', () {
      final bp = svc.calculateBp(72);
      expect(bp['systolic']!, inInclusiveRange(90, 160));
      expect(bp['diastolic']!, inInclusiveRange(60, 100));
    });

    test('calculateBp — returns zeros for 0 BPM', () {
      final bp = svc.calculateBp(0);
      expect(bp['systolic'], 0);
      expect(bp['diastolic'], 0);
    });

    test('SignalQuality.label — all values', () {
      expect(SignalQuality.excellent.label, 'Excellent');
      expect(SignalQuality.good.label, 'Good');
      expect(SignalQuality.fair.label, 'Fair');
      expect(SignalQuality.poor.label, 'Poor');
      expect(SignalQuality.invalid.label, 'Invalid');
    });

    test('SignalQualityX.fromString — parses correctly', () {
      expect(SignalQualityX.fromString('excellent'), SignalQuality.excellent);
      expect(SignalQualityX.fromString('Good'), SignalQuality.good);
      expect(SignalQualityX.fromString(null), SignalQuality.invalid);
      expect(SignalQualityX.fromString('unknown'), SignalQuality.invalid);
    });
  });

  // ── Widget Tests ─────────────────────────────────────────────────────────────

  group('SignalQualityWidget', () {
    testWidgets('renders quality label', (tester) async {
      await tester.pumpWidget(_wrap(const SignalQualityWidget(
        quality: SignalQuality.excellent,
        confidence: 92,
        message: 'Test message',
      )));
      await tester.pump();

      expect(find.text('Excellent'), findsOneWidget);
      expect(find.text('Signal Quality'), findsOneWidget);
    });

    testWidgets('renders confidence percentage', (tester) async {
      await tester.pumpWidget(_wrap(const SignalQualityWidget(
        quality: SignalQuality.good,
        confidence: 75,
        message: 'Good signal',
      )));
      await tester.pump();
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('shows live BPM when provided', (tester) async {
      await tester.pumpWidget(_wrap(const SignalQualityWidget(
        quality: SignalQuality.good,
        confidence: 80,
        bpmEstimate: 72,
        message: 'Scanning...',
      )));
      await tester.pump();
      expect(find.textContaining('72 BPM'), findsOneWidget);
    });
  });

  group('LiveBpmWidget', () {
    testWidgets('shows -- when not scanning', (tester) async {
      await tester.pumpWidget(_wrap(const LiveBpmWidget(
        bpm: null,
        isScanning: false,
        scanProgress: 0,
      )));
      await tester.pump();
      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('shows BPM value when scanning', (tester) async {
      await tester.pumpWidget(_wrap(const LiveBpmWidget(
        bpm: 78,
        isScanning: true,
        scanProgress: 0.5,
      )));
      await tester.pump();
      expect(find.text('78'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
    });
  });

  // ── UserModel Tests ───────────────────────────────────────────────────────────

  group('UserModel', () {
    test('fromJson — basic', () {
      final json = {
        'id': 'user123',
        'name': 'John Doe',
        'email': 'john@example.com',
        'healthGoals': {},
      };
      final user = UserModel.fromJson(json);
      expect(user.id, 'user123');
      expect(user.name, 'John Doe');
      expect(user.scanStreak, 0);
      expect(user.isTwoFactorEnabled, false);
    });

    test('toJson — round-trip', () {
      final user = UserModel(
        id: 'u1',
        name: 'Test',
        email: 'test@test.com',
        healthGoals: HealthGoals(
          minBpm: 60, maxBpm: 90,
          dailyScanGoal: 3, dailyBreathingGoal: 5,
          weeklyBpmTarget: 85,
        ),
      );
      final json = user.toJson();
      final restored = UserModel.fromJson(json);
      expect(restored.id, user.id);
      expect(restored.name, user.name);
    });
  });
}
