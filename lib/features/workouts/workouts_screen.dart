import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/workout_data.dart';
import '../../models/workout_model.dart';
import 'muscle_exercises_screen.dart';
import 'preset_workout_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FitVerse Body Map — Anatomical SVG-style CustomPainter
// • Real body drawing with visible muscle anatomy (no basic rectangles)
// • No side naming panel — body fills the full width
// • Tappable anatomical muscle regions with glow highlight
// ─────────────────────────────────────────────────────────────────────────────

// ── Region definition ─────────────────────────────────────────────────────────
class _Region {
  final String groupId;
  final bool front;
  final bool back;
  final List<Path Function(Size)> builders;

  const _Region({
    required this.groupId,
    this.front = false,
    this.back = false,
    required this.builders,
  });

  bool contains(Offset pt, Size s) =>
      builders.any((b) => b(s).contains(pt));
}

// ── Anatomical region map — paths follow real muscle contours ────────────────
final List<_Region> _kRegions = [

  // ═══ BOTH VIEWS ══════════════════════════════════════════════════════════

  // Neck — tapered trapezoid
  _Region(groupId: 'neck', front: true, back: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.430 * s.width, 0.138 * s.height);
      p.lineTo(0.570 * s.width, 0.138 * s.height);
      p.lineTo(0.555 * s.width, 0.178 * s.height);
      p.lineTo(0.445 * s.width, 0.178 * s.height);
      p.close();
      return p;
    },
  ]),

  // Shoulders — realistic deltoid caps with inner curve
  _Region(groupId: 'shoulders', front: true, back: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.330 * s.width, 0.175 * s.height);
      p.quadraticBezierTo(0.200 * s.width, 0.155 * s.height,
          0.120 * s.width, 0.220 * s.height);
      p.quadraticBezierTo(0.100 * s.width, 0.270 * s.height,
          0.118 * s.width, 0.310 * s.height);
      p.lineTo(0.190 * s.width, 0.300 * s.height);
      p.quadraticBezierTo(0.240 * s.width, 0.230 * s.height,
          0.295 * s.width, 0.215 * s.height);
      p.lineTo(0.330 * s.width, 0.195 * s.height);
      p.close();
      return p;
    },
    (s) {
      final p = Path();
      p.moveTo(0.670 * s.width, 0.175 * s.height);
      p.quadraticBezierTo(0.800 * s.width, 0.155 * s.height,
          0.880 * s.width, 0.220 * s.height);
      p.quadraticBezierTo(0.900 * s.width, 0.270 * s.height,
          0.882 * s.width, 0.310 * s.height);
      p.lineTo(0.810 * s.width, 0.300 * s.height);
      p.quadraticBezierTo(0.760 * s.width, 0.230 * s.height,
          0.705 * s.width, 0.215 * s.height);
      p.lineTo(0.670 * s.width, 0.195 * s.height);
      p.close();
      return p;
    },
  ]),

  // Upper arms (biceps front / triceps back)
  _Region(groupId: 'arms', front: true, back: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.118 * s.width, 0.310 * s.height);
      p.quadraticBezierTo(0.090 * s.width, 0.380 * s.height,
          0.098 * s.width, 0.450 * s.height);
      p.lineTo(0.172 * s.width, 0.455 * s.height);
      p.quadraticBezierTo(0.188 * s.width, 0.390 * s.height,
          0.190 * s.width, 0.300 * s.height);
      p.close();
      return p;
    },
    (s) {
      final p = Path();
      p.moveTo(0.882 * s.width, 0.310 * s.height);
      p.quadraticBezierTo(0.910 * s.width, 0.380 * s.height,
          0.902 * s.width, 0.450 * s.height);
      p.lineTo(0.828 * s.width, 0.455 * s.height);
      p.quadraticBezierTo(0.812 * s.width, 0.390 * s.height,
          0.810 * s.width, 0.300 * s.height);
      p.close();
      return p;
    },
  ]),

  // Forearms — tapered shape
  _Region(groupId: 'forearms', front: true, back: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.098 * s.width, 0.450 * s.height);
      p.quadraticBezierTo(0.082 * s.width, 0.520 * s.height,
          0.095 * s.width, 0.580 * s.height);
      p.lineTo(0.158 * s.width, 0.580 * s.height);
      p.quadraticBezierTo(0.175 * s.width, 0.520 * s.height,
          0.172 * s.width, 0.455 * s.height);
      p.close();
      return p;
    },
    (s) {
      final p = Path();
      p.moveTo(0.902 * s.width, 0.450 * s.height);
      p.quadraticBezierTo(0.918 * s.width, 0.520 * s.height,
          0.905 * s.width, 0.580 * s.height);
      p.lineTo(0.842 * s.width, 0.580 * s.height);
      p.quadraticBezierTo(0.825 * s.width, 0.520 * s.height,
          0.828 * s.width, 0.455 * s.height);
      p.close();
      return p;
    },
  ]),

  // Calves — diamond-shaped gastrocnemius
  _Region(groupId: 'calves', front: true, back: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.330 * s.width, 0.840 * s.height);
      p.quadraticBezierTo(0.295 * s.width, 0.880 * s.height,
          0.318 * s.width, 0.940 * s.height);
      p.quadraticBezierTo(0.340 * s.width, 0.970 * s.height,
          0.378 * s.width, 0.965 * s.height);
      p.quadraticBezierTo(0.408 * s.width, 0.960 * s.height,
          0.415 * s.width, 0.940 * s.height);
      p.quadraticBezierTo(0.430 * s.width, 0.885 * s.height,
          0.402 * s.width, 0.840 * s.height);
      p.close();
      return p;
    },
    (s) {
      final p = Path();
      p.moveTo(0.670 * s.width, 0.840 * s.height);
      p.quadraticBezierTo(0.705 * s.width, 0.880 * s.height,
          0.682 * s.width, 0.940 * s.height);
      p.quadraticBezierTo(0.660 * s.width, 0.970 * s.height,
          0.622 * s.width, 0.965 * s.height);
      p.quadraticBezierTo(0.592 * s.width, 0.960 * s.height,
          0.585 * s.width, 0.940 * s.height);
      p.quadraticBezierTo(0.570 * s.width, 0.885 * s.height,
          0.598 * s.width, 0.840 * s.height);
      p.close();
      return p;
    },
  ]),

  // ═══ FRONT ONLY ══════════════════════════════════════════════════════════

  // Chest — pectoral shape with inner and outer curves
  _Region(groupId: 'chest', front: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.445 * s.width, 0.178 * s.height);
      p.lineTo(0.330 * s.width, 0.195 * s.height);
      p.quadraticBezierTo(0.295 * s.width, 0.215 * s.height,
          0.278 * s.width, 0.255 * s.height);
      p.quadraticBezierTo(0.270 * s.width, 0.305 * s.height,
          0.305 * s.width, 0.338 * s.height);
      p.lineTo(0.490 * s.width, 0.345 * s.height);
      p.lineTo(0.490 * s.width, 0.210 * s.height);
      p.close();
      return p;
    },
    (s) {
      final p = Path();
      p.moveTo(0.555 * s.width, 0.178 * s.height);
      p.lineTo(0.670 * s.width, 0.195 * s.height);
      p.quadraticBezierTo(0.705 * s.width, 0.215 * s.height,
          0.722 * s.width, 0.255 * s.height);
      p.quadraticBezierTo(0.730 * s.width, 0.305 * s.height,
          0.695 * s.width, 0.338 * s.height);
      p.lineTo(0.510 * s.width, 0.345 * s.height);
      p.lineTo(0.510 * s.width, 0.210 * s.height);
      p.close();
      return p;
    },
  ]),

  // Serratus — finger-like projections on the sides
  _Region(groupId: 'serratus', front: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.278 * s.width, 0.255 * s.height);
      p.quadraticBezierTo(0.255 * s.width, 0.300 * s.height,
          0.260 * s.width, 0.350 * s.height);
      p.lineTo(0.305 * s.width, 0.338 * s.height);
      p.quadraticBezierTo(0.270 * s.width, 0.305 * s.height,
          0.278 * s.width, 0.255 * s.height);
      return p;
    },
    (s) {
      final p = Path();
      // Left serratus strip
      p.moveTo(0.260 * s.width, 0.350 * s.height);
      p.quadraticBezierTo(0.248 * s.width, 0.395 * s.height,
          0.258 * s.width, 0.440 * s.height);
      p.lineTo(0.298 * s.width, 0.430 * s.height);
      p.lineTo(0.305 * s.width, 0.338 * s.height);
      p.close();
      return p;
    },
    (s) {
      final p = Path();
      p.moveTo(0.722 * s.width, 0.255 * s.height);
      p.quadraticBezierTo(0.745 * s.width, 0.300 * s.height,
          0.740 * s.width, 0.350 * s.height);
      p.lineTo(0.695 * s.width, 0.338 * s.height);
      p.quadraticBezierTo(0.730 * s.width, 0.305 * s.height,
          0.722 * s.width, 0.255 * s.height);
      return p;
    },
    (s) {
      final p = Path();
      p.moveTo(0.740 * s.width, 0.350 * s.height);
      p.quadraticBezierTo(0.752 * s.width, 0.395 * s.height,
          0.742 * s.width, 0.440 * s.height);
      p.lineTo(0.702 * s.width, 0.430 * s.height);
      p.lineTo(0.695 * s.width, 0.338 * s.height);
      p.close();
      return p;
    },
  ]),

  // Obliques — flanking the abs
  _Region(groupId: 'obliques', front: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.258 * s.width, 0.440 * s.height);
      p.quadraticBezierTo(0.248 * s.width, 0.490 * s.height,
          0.278 * s.width, 0.540 * s.height);
      p.lineTo(0.342 * s.width, 0.545 * s.height);
      p.lineTo(0.340 * s.width, 0.430 * s.height);
      p.lineTo(0.298 * s.width, 0.430 * s.height);
      p.close();
      return p;
    },
    (s) {
      final p = Path();
      p.moveTo(0.742 * s.width, 0.440 * s.height);
      p.quadraticBezierTo(0.752 * s.width, 0.490 * s.height,
          0.722 * s.width, 0.540 * s.height);
      p.lineTo(0.658 * s.width, 0.545 * s.height);
      p.lineTo(0.660 * s.width, 0.430 * s.height);
      p.lineTo(0.702 * s.width, 0.430 * s.height);
      p.close();
      return p;
    },
  ]),

  // Core (abs) — six-pack segment shape
  _Region(groupId: 'core', front: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.305 * s.width, 0.338 * s.height);
      p.lineTo(0.695 * s.width, 0.338 * s.height);
      p.lineTo(0.658 * s.width, 0.545 * s.height);
      p.lineTo(0.342 * s.width, 0.545 * s.height);
      p.close();
      return p;
    },
  ]),

  // Hip Flexors — V-shape below abs
  _Region(groupId: 'hip_flexors', front: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.342 * s.width, 0.545 * s.height);
      p.lineTo(0.658 * s.width, 0.545 * s.height);
      p.quadraticBezierTo(0.650 * s.width, 0.595 * s.height,
          0.625 * s.width, 0.628 * s.height);
      p.lineTo(0.500 * s.width, 0.638 * s.height);
      p.lineTo(0.375 * s.width, 0.628 * s.height);
      p.quadraticBezierTo(0.350 * s.width, 0.595 * s.height,
          0.342 * s.width, 0.545 * s.height);
      p.close();
      return p;
    },
  ]),

  // Adductors — inner thigh teardrop shape
  _Region(groupId: 'adductors', front: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.430 * s.width, 0.638 * s.height);
      p.quadraticBezierTo(0.415 * s.width, 0.700 * s.height,
          0.422 * s.width, 0.840 * s.height);
      p.lineTo(0.458 * s.width, 0.840 * s.height);
      p.quadraticBezierTo(0.470 * s.width, 0.730 * s.height,
          0.490 * s.width, 0.650 * s.height);
      p.lineTo(0.500 * s.width, 0.638 * s.height);
      p.close();
      return p;
    },
    (s) {
      final p = Path();
      p.moveTo(0.570 * s.width, 0.638 * s.height);
      p.quadraticBezierTo(0.585 * s.width, 0.700 * s.height,
          0.578 * s.width, 0.840 * s.height);
      p.lineTo(0.542 * s.width, 0.840 * s.height);
      p.quadraticBezierTo(0.530 * s.width, 0.730 * s.height,
          0.510 * s.width, 0.650 * s.height);
      p.lineTo(0.500 * s.width, 0.638 * s.height);
      p.close();
      return p;
    },
  ]),

  // Quadriceps — outer teardrop shape
  _Region(groupId: 'quadriceps', front: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.375 * s.width, 0.628 * s.height);
      p.quadraticBezierTo(0.320 * s.width, 0.660 * s.height,
          0.308 * s.width, 0.700 * s.height);
      p.quadraticBezierTo(0.295 * s.width, 0.760 * s.height,
          0.310 * s.width, 0.840 * s.height);
      p.lineTo(0.422 * s.width, 0.840 * s.height);
      p.quadraticBezierTo(0.415 * s.width, 0.700 * s.height,
          0.430 * s.width, 0.638 * s.height);
      p.close();
      return p;
    },
    (s) {
      final p = Path();
      p.moveTo(0.625 * s.width, 0.628 * s.height);
      p.quadraticBezierTo(0.680 * s.width, 0.660 * s.height,
          0.692 * s.width, 0.700 * s.height);
      p.quadraticBezierTo(0.705 * s.width, 0.760 * s.height,
          0.690 * s.width, 0.840 * s.height);
      p.lineTo(0.578 * s.width, 0.840 * s.height);
      p.quadraticBezierTo(0.585 * s.width, 0.700 * s.height,
          0.570 * s.width, 0.638 * s.height);
      p.close();
      return p;
    },
  ]),

  // ═══ BACK ONLY ═══════════════════════════════════════════════════════════

  // Trapezius — upper back diamond
  _Region(groupId: 'trapezius', back: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.500 * s.width, 0.138 * s.height);
      p.lineTo(0.700 * s.width, 0.195 * s.height);
      p.quadraticBezierTo(0.720 * s.width, 0.260 * s.height,
          0.700 * s.width, 0.310 * s.height);
      p.lineTo(0.500 * s.width, 0.278 * s.height);
      p.lineTo(0.300 * s.width, 0.310 * s.height);
      p.quadraticBezierTo(0.280 * s.width, 0.260 * s.height,
          0.300 * s.width, 0.195 * s.height);
      p.close();
      return p;
    },
  ]),

  // Back (lats) — wide fan shape
  _Region(groupId: 'back', back: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.500 * s.width, 0.278 * s.height);
      p.lineTo(0.700 * s.width, 0.310 * s.height);
      p.quadraticBezierTo(0.720 * s.width, 0.380 * s.height,
          0.710 * s.width, 0.460 * s.height);
      p.quadraticBezierTo(0.695 * s.width, 0.490 * s.height,
          0.665 * s.width, 0.498 * s.height);
      p.lineTo(0.500 * s.width, 0.490 * s.height);
      p.close();
      return p;
    },
    (s) {
      final p = Path();
      p.moveTo(0.500 * s.width, 0.278 * s.height);
      p.lineTo(0.300 * s.width, 0.310 * s.height);
      p.quadraticBezierTo(0.280 * s.width, 0.380 * s.height,
          0.290 * s.width, 0.460 * s.height);
      p.quadraticBezierTo(0.305 * s.width, 0.490 * s.height,
          0.335 * s.width, 0.498 * s.height);
      p.lineTo(0.500 * s.width, 0.490 * s.height);
      p.close();
      return p;
    },
  ]),

  // Lower Back — lumbar rectangle
  _Region(groupId: 'lower_back', back: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.335 * s.width, 0.498 * s.height);
      p.lineTo(0.665 * s.width, 0.498 * s.height);
      p.quadraticBezierTo(0.680 * s.width, 0.545 * s.height,
          0.665 * s.width, 0.595 * s.height);
      p.lineTo(0.335 * s.width, 0.595 * s.height);
      p.quadraticBezierTo(0.320 * s.width, 0.545 * s.height,
          0.335 * s.width, 0.498 * s.height);
      p.close();
      return p;
    },
  ]),

  // Glutes — wide rounded shape
  _Region(groupId: 'glutes', back: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.335 * s.width, 0.595 * s.height);
      p.lineTo(0.665 * s.width, 0.595 * s.height);
      p.quadraticBezierTo(0.710 * s.width, 0.620 * s.height,
          0.715 * s.width, 0.680 * s.height);
      p.quadraticBezierTo(0.710 * s.width, 0.730 * s.height,
          0.500 * s.width, 0.740 * s.height);
      p.quadraticBezierTo(0.290 * s.width, 0.730 * s.height,
          0.285 * s.width, 0.680 * s.height);
      p.quadraticBezierTo(0.290 * s.width, 0.620 * s.height,
          0.335 * s.width, 0.595 * s.height);
      p.close();
      return p;
    },
  ]),

  // Abductors — outer hip strip
  _Region(groupId: 'abductors', back: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.285 * s.width, 0.680 * s.height);
      p.quadraticBezierTo(0.260 * s.width, 0.720 * s.height,
          0.268 * s.width, 0.760 * s.height);
      p.lineTo(0.310 * s.width, 0.760 * s.height);
      p.quadraticBezierTo(0.305 * s.width, 0.720 * s.height,
          0.320 * s.width, 0.680 * s.height);
      p.close();
      return p;
    },
    (s) {
      final p = Path();
      p.moveTo(0.715 * s.width, 0.680 * s.height);
      p.quadraticBezierTo(0.740 * s.width, 0.720 * s.height,
          0.732 * s.width, 0.760 * s.height);
      p.lineTo(0.690 * s.width, 0.760 * s.height);
      p.quadraticBezierTo(0.695 * s.width, 0.720 * s.height,
          0.680 * s.width, 0.680 * s.height);
      p.close();
      return p;
    },
  ]),

  // Hamstrings — back thigh, paired
  _Region(groupId: 'hamstrings', back: true, builders: [
    (s) {
      final p = Path();
      p.moveTo(0.320 * s.width, 0.680 * s.height);
      p.quadraticBezierTo(0.308 * s.width, 0.720 * s.height,
          0.310 * s.width, 0.760 * s.height);
      p.lineTo(0.315 * s.width, 0.840 * s.height);
      p.lineTo(0.468 * s.width, 0.840 * s.height);
      p.lineTo(0.478 * s.width, 0.760 * s.height);
      p.quadraticBezierTo(0.490 * s.width, 0.710 * s.height,
          0.500 * s.width, 0.690 * s.height);
      p.quadraticBezierTo(0.420 * s.width, 0.720 * s.height,
          0.320 * s.width, 0.680 * s.height);
      p.close();
      return p;
    },
    (s) {
      final p = Path();
      p.moveTo(0.680 * s.width, 0.680 * s.height);
      p.quadraticBezierTo(0.692 * s.width, 0.720 * s.height,
          0.690 * s.width, 0.760 * s.height);
      p.lineTo(0.685 * s.width, 0.840 * s.height);
      p.lineTo(0.532 * s.width, 0.840 * s.height);
      p.lineTo(0.522 * s.width, 0.760 * s.height);
      p.quadraticBezierTo(0.510 * s.width, 0.710 * s.height,
          0.500 * s.width, 0.690 * s.height);
      p.quadraticBezierTo(0.580 * s.width, 0.720 * s.height,
          0.680 * s.width, 0.680 * s.height);
      p.close();
      return p;
    },
  ]),
];

// ═══════════════════════════════════════════════════════════════════════════════
// Main screen
// ═══════════════════════════════════════════════════════════════════════════════
class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});
  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(
                color: AppTheme.seedColor,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              labelPadding: EdgeInsets.zero,
              tabs: const [
                Tab(text: 'Body Map', height: 38),
                Tab(text: 'Presets', height: 38),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              const _BodyMapTab(),
              _PresetsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Body Map Tab
// ═══════════════════════════════════════════════════════════════════════════════
class _BodyMapTab extends StatefulWidget {
  const _BodyMapTab();
  @override
  State<_BodyMapTab> createState() => _BodyMapTabState();
}

class _BodyMapTabState extends State<_BodyMapTab>
    with SingleTickerProviderStateMixin {
  bool _isFront = true;
  String? _selectedId;
  late AnimationController _panelCtrl;
  late Animation<double> _panelAnim;
  Size _bodySize = Size.zero;
  Offset _bodyOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _panelCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _panelAnim =
        CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _panelCtrl.dispose();
    super.dispose();
  }

  List<_Region> get _visible =>
      _kRegions.where((r) => _isFront ? r.front : r.back).toList();

  void _onTap(Offset local) {
    for (final region in _visible.reversed) {
      if (region.contains(local, _bodySize)) {
        HapticFeedback.selectionClick();
        if (_selectedId == region.groupId) {
          _openExercises(region.groupId);
          return;
        }
        setState(() => _selectedId = region.groupId);
        _panelCtrl.forward(from: 0);
        return;
      }
    }
    setState(() => _selectedId = null);
    _panelCtrl.reverse();
  }

  void _openExercises(String groupId) {
    final group =
        WorkoutData.muscleGroups.firstWhere((g) => g.id == groupId);
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => MuscleExercisesScreen(group: group)));
  }

  MuscleGroup? get _selectedGroup => _selectedId == null
      ? null
      : WorkoutData.muscleGroups
          .cast<MuscleGroup?>()
          .firstWhere((g) => g!.id == _selectedId, orElse: () => null);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Front / Back toggle ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              _toggleBtn('Front', _isFront),
              _toggleBtn('Back', !_isFront),
            ]),
          ),
        ),

        // ── Instruction strip ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            _selectedId == null
                ? 'Tap a muscle to select  •  tap again to open exercises'
                : 'Tap again to open exercises  •  tap elsewhere to deselect',
            style: TextStyle(
                color: Colors.white.withOpacity(0.35), fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),

        // ── Body figure — full width, no side panel ────────────────────
        Expanded(
          child: LayoutBuilder(builder: (ctx, constraints) {
            // Body fills ~55% of screen width, centered
            final maxH = constraints.maxHeight;
            final maxW = constraints.maxWidth;
            final h = maxH * 0.96;
            final w = (h * 0.46).clamp(0.0, maxW * 0.70);
            _bodySize = Size(w, h);
            _bodyOffset = Offset((maxW - w) / 2, (maxH - h) / 2);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _onTap(d.localPosition - _bodyOffset),
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: CustomPaint(
                        painter: _BodyPainter(
                          isFront: _isFront,
                          selectedId: _selectedId,
                          groups: WorkoutData.muscleGroups,
                          regions: _kRegions,
                        ),
                      ),
                    ),
                  ),
                  // Floating label for selected region
                  if (_selectedGroup != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: SizedBox(
                        width: maxW,
                        height: maxH,
                        child: _FloatingLabel(
                          group: _selectedGroup!,
                          regions: _kRegions,
                          isFront: _isFront,
                          bodySize: _bodySize,
                          bodyOffset: _bodyOffset,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),

        // ── Info panel ─────────────────────────────────────────────────
        SizeTransition(
          sizeFactor: _panelAnim,
          axisAlignment: -1,
          child: _selectedGroup != null
              ? _MuscleInfoPanel(
                  group: _selectedGroup!,
                  onOpen: () => _openExercises(_selectedId!),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _toggleBtn(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          final wantFront = label == 'Front';
          if (wantFront != _isFront) {
            setState(() {
              _isFront = wantFront;
              _selectedId = null;
              _panelCtrl.reverse();
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppTheme.seedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white38,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Floating label over selected region ──────────────────────────────────────
class _FloatingLabel extends StatelessWidget {
  final MuscleGroup group;
  final List<_Region> regions;
  final bool isFront;
  final Size bodySize;
  final Offset bodyOffset;

  const _FloatingLabel({
    required this.group,
    required this.regions,
    required this.isFront,
    required this.bodySize,
    required this.bodyOffset,
  });

  @override
  Widget build(BuildContext context) {
    final region = regions.cast<_Region?>().firstWhere(
        (r) => r!.groupId == group.id && (isFront ? r.front : r.back),
        orElse: () => null);
    if (region == null) return const SizedBox.shrink();

    final path = region.builders.first(bodySize);
    final center = path.getBounds().center;
    final absCenter = center + bodyOffset;

    return Stack(children: [
      Positioned(
        left: absCenter.dx - 58,
        top: absCenter.dy - 20,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          builder: (_, v, child) =>
              Opacity(opacity: v, child: Transform.scale(scale: 0.85 + 0.15 * v, child: child)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Color(group.color).withOpacity(0.92),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Color(group.color).withOpacity(0.50),
                    blurRadius: 12,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Text(
              group.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── Info panel ────────────────────────────────────────────────────────────────
class _MuscleInfoPanel extends StatelessWidget {
  final MuscleGroup group;
  final VoidCallback onOpen;

  const _MuscleInfoPanel({required this.group, required this.onOpen});

  static IconData _iconFor(String id) {
    switch (id) {
      case 'chest': return Icons.fitness_center;
      case 'back': return Icons.airline_seat_flat;
      case 'shoulders': return Icons.sports_gymnastics;
      case 'legs': return Icons.directions_walk;
      case 'arms': return Icons.fitness_center;
      case 'core': return Icons.radio_button_checked;
      case 'calves': return Icons.directions_run;
      case 'glutes': return Icons.sports_handball;
      case 'forearms': return Icons.back_hand;
      case 'cardio': return Icons.favorite;
      case 'trapezius': return Icons.keyboard_double_arrow_up;
      case 'neck': return Icons.self_improvement;
      case 'lower_back': return Icons.architecture;
      case 'hamstrings': return Icons.directions_walk;
      case 'quadriceps': return Icons.directions_run;
      case 'hip_flexors': return Icons.accessibility_new;
      case 'adductors': return Icons.compress;
      case 'abductors': return Icons.expand;
      case 'serratus': return Icons.waves;
      case 'obliques': return Icons.rotate_right;
      default: return Icons.sports_gymnastics;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(group.color);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.18), color.withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
              child: Icon(_iconFor(group.id), color: color, size: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(group.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 2),
            Text('${group.exercises.length} exercises · tap again to open',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 11)),
          ]),
        ),
        GestureDetector(
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Open',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Custom Painter — draws detailed anatomical figure + muscle region overlays
// ═══════════════════════════════════════════════════════════════════════════════
class _BodyPainter extends CustomPainter {
  final bool isFront;
  final String? selectedId;
  final List<MuscleGroup> groups;
  final List<_Region> regions;

  _BodyPainter({
    required this.isFront,
    required this.selectedId,
    required this.groups,
    required this.regions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawFullBody(canvas, size);
    _drawRegions(canvas, size);
    _drawAnatomyLines(canvas, size);
    _drawMuscleLabels(canvas, size);
  }

  // ── Draw complete anatomical body silhouette ───────────────────────────────
  void _drawFullBody(Canvas canvas, Size s) {
    final bodyFill = Paint()
      ..color = const Color(0xFF1A3035)
      ..style = PaintingStyle.fill;
    final bodyStroke = Paint()
      ..color = const Color(0xFF00897B).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final skinTone = Paint()
      ..color = const Color(0xFF1E3C40)
      ..style = PaintingStyle.fill;

    // Head
    final headPath = _buildHead(s);
    canvas.drawPath(headPath, bodyFill);
    canvas.drawPath(headPath, bodyStroke);

    // Neck
    final neckPath = _buildNeck(s);
    canvas.drawPath(neckPath, skinTone);
    canvas.drawPath(neckPath, bodyStroke);

    // Torso
    final torso = _buildTorso(s);
    canvas.drawPath(torso, bodyFill);
    canvas.drawPath(torso, bodyStroke);

    // Pelvis / hip area
    final hips = _buildHips(s);
    canvas.drawPath(hips, bodyFill);
    canvas.drawPath(hips, bodyStroke);

    // Left upper arm
    final lUpperArm = _buildLUpperArm(s);
    canvas.drawPath(lUpperArm, skinTone);
    canvas.drawPath(lUpperArm, bodyStroke);

    // Right upper arm
    final rUpperArm = _buildRUpperArm(s);
    canvas.drawPath(rUpperArm, skinTone);
    canvas.drawPath(rUpperArm, bodyStroke);

    // Left forearm
    final lForearm = _buildLForearm(s);
    canvas.drawPath(lForearm, skinTone);
    canvas.drawPath(lForearm, bodyStroke);

    // Right forearm
    final rForearm = _buildRForearm(s);
    canvas.drawPath(rForearm, skinTone);
    canvas.drawPath(rForearm, bodyStroke);

    // Hands
    _drawHand(canvas, s, left: true);
    _drawHand(canvas, s, left: false);

    // Left thigh
    final lThigh = _buildLThigh(s);
    canvas.drawPath(lThigh, skinTone);
    canvas.drawPath(lThigh, bodyStroke);

    // Right thigh
    final rThigh = _buildRThigh(s);
    canvas.drawPath(rThigh, skinTone);
    canvas.drawPath(rThigh, bodyStroke);

    // Left lower leg
    final lLeg = _buildLLowerLeg(s);
    canvas.drawPath(lLeg, skinTone);
    canvas.drawPath(lLeg, bodyStroke);

    // Right lower leg
    final rLeg = _buildRLowerLeg(s);
    canvas.drawPath(rLeg, skinTone);
    canvas.drawPath(rLeg, bodyStroke);

    // Feet
    _drawFoot(canvas, s, left: true);
    _drawFoot(canvas, s, left: false);

    if (isFront) {
      _drawFaceDetails(canvas, s);
    } else {
      _drawBackHairline(canvas, s);
    }
  }

  Path _buildHead(Size s) {
    final p = Path();
    // Oval head with slight jawline taper
    p.moveTo(0.500 * s.width, 0.008 * s.height);
    p.cubicTo(
        0.580 * s.width, 0.008 * s.height,
        0.640 * s.width, 0.038 * s.height,
        0.648 * s.width, 0.078 * s.height);
    p.cubicTo(
        0.655 * s.width, 0.110 * s.height,
        0.648 * s.width, 0.120 * s.height,
        0.635 * s.width, 0.130 * s.height);
    // Jaw
    p.quadraticBezierTo(
        0.610 * s.width, 0.140 * s.height,
        0.500 * s.width, 0.142 * s.height);
    p.quadraticBezierTo(
        0.390 * s.width, 0.140 * s.height,
        0.365 * s.width, 0.130 * s.height);
    p.cubicTo(
        0.352 * s.width, 0.120 * s.height,
        0.345 * s.width, 0.110 * s.height,
        0.352 * s.width, 0.078 * s.height);
    p.cubicTo(
        0.360 * s.width, 0.038 * s.height,
        0.420 * s.width, 0.008 * s.height,
        0.500 * s.width, 0.008 * s.height);
    p.close();
    return p;
  }

  Path _buildNeck(Size s) {
    final p = Path();
    p.moveTo(0.445 * s.width, 0.135 * s.height);
    p.quadraticBezierTo(0.455 * s.width, 0.158 * s.height,
        0.455 * s.width, 0.178 * s.height);
    p.lineTo(0.545 * s.width, 0.178 * s.height);
    p.quadraticBezierTo(0.545 * s.width, 0.158 * s.height,
        0.555 * s.width, 0.135 * s.height);
    p.close();
    return p;
  }

  Path _buildTorso(Size s) {
    final p = Path();
    if (isFront) {
      // Front torso with waist taper
      p.moveTo(0.330 * s.width, 0.178 * s.height);
      p.quadraticBezierTo(0.310 * s.width, 0.200 * s.height,
          0.270 * s.width, 0.250 * s.height);
      p.quadraticBezierTo(0.248 * s.width, 0.360 * s.height,
          0.260 * s.width, 0.445 * s.height);
      p.quadraticBezierTo(0.275 * s.width, 0.510 * s.height,
          0.310 * s.width, 0.545 * s.height);
      p.lineTo(0.690 * s.width, 0.545 * s.height);
      p.quadraticBezierTo(0.725 * s.width, 0.510 * s.height,
          0.740 * s.width, 0.445 * s.height);
      p.quadraticBezierTo(0.752 * s.width, 0.360 * s.height,
          0.730 * s.width, 0.250 * s.height);
      p.quadraticBezierTo(0.690 * s.width, 0.200 * s.height,
          0.670 * s.width, 0.178 * s.height);
      p.close();
    } else {
      // Back torso
      p.moveTo(0.300 * s.width, 0.178 * s.height);
      p.quadraticBezierTo(0.280 * s.width, 0.220 * s.height,
          0.272 * s.width, 0.310 * s.height);
      p.quadraticBezierTo(0.268 * s.width, 0.400 * s.height,
          0.278 * s.width, 0.495 * s.height);
      p.quadraticBezierTo(0.292 * s.width, 0.540 * s.height,
          0.320 * s.width, 0.555 * s.height);
      p.lineTo(0.680 * s.width, 0.555 * s.height);
      p.quadraticBezierTo(0.708 * s.width, 0.540 * s.height,
          0.722 * s.width, 0.495 * s.height);
      p.quadraticBezierTo(0.732 * s.width, 0.400 * s.height,
          0.728 * s.width, 0.310 * s.height);
      p.quadraticBezierTo(0.720 * s.width, 0.220 * s.height,
          0.700 * s.width, 0.178 * s.height);
      p.close();
    }
    return p;
  }

  Path _buildHips(Size s) {
    final p = Path();
    if (isFront) {
      p.moveTo(0.310 * s.width, 0.545 * s.height);
      p.lineTo(0.690 * s.width, 0.545 * s.height);
      p.quadraticBezierTo(0.720 * s.width, 0.580 * s.height,
          0.728 * s.width, 0.638 * s.height);
      p.quadraticBezierTo(0.560 * s.width, 0.660 * s.height,
          0.500 * s.width, 0.658 * s.height);
      p.quadraticBezierTo(0.440 * s.width, 0.660 * s.height,
          0.272 * s.width, 0.638 * s.height);
      p.quadraticBezierTo(0.280 * s.width, 0.580 * s.height,
          0.310 * s.width, 0.545 * s.height);
      p.close();
    } else {
      p.moveTo(0.320 * s.width, 0.555 * s.height);
      p.lineTo(0.680 * s.width, 0.555 * s.height);
      p.quadraticBezierTo(0.720 * s.width, 0.590 * s.height,
          0.730 * s.width, 0.650 * s.height);
      p.quadraticBezierTo(0.580 * s.width, 0.680 * s.height,
          0.500 * s.width, 0.678 * s.height);
      p.quadraticBezierTo(0.420 * s.width, 0.680 * s.height,
          0.270 * s.width, 0.650 * s.height);
      p.quadraticBezierTo(0.280 * s.width, 0.590 * s.height,
          0.320 * s.width, 0.555 * s.height);
      p.close();
    }
    return p;
  }

  Path _buildLUpperArm(Size s) {
    final p = Path();
    p.moveTo(0.190 * s.width, 0.290 * s.height);
    p.quadraticBezierTo(0.085 * s.width, 0.310 * s.height,
        0.082 * s.width, 0.455 * s.height);
    p.lineTo(0.158 * s.width, 0.460 * s.height);
    p.quadraticBezierTo(0.162 * s.width, 0.360 * s.height,
        0.200 * s.width, 0.305 * s.height);
    p.close();
    return p;
  }

  Path _buildRUpperArm(Size s) {
    final p = Path();
    p.moveTo(0.810 * s.width, 0.290 * s.height);
    p.quadraticBezierTo(0.915 * s.width, 0.310 * s.height,
        0.918 * s.width, 0.455 * s.height);
    p.lineTo(0.842 * s.width, 0.460 * s.height);
    p.quadraticBezierTo(0.838 * s.width, 0.360 * s.height,
        0.800 * s.width, 0.305 * s.height);
    p.close();
    return p;
  }

  Path _buildLForearm(Size s) {
    final p = Path();
    p.moveTo(0.082 * s.width, 0.455 * s.height);
    p.quadraticBezierTo(0.070 * s.width, 0.520 * s.height,
        0.078 * s.width, 0.585 * s.height);
    p.lineTo(0.148 * s.width, 0.585 * s.height);
    p.quadraticBezierTo(0.158 * s.width, 0.520 * s.height,
        0.158 * s.width, 0.460 * s.height);
    p.close();
    return p;
  }

  Path _buildRForearm(Size s) {
    final p = Path();
    p.moveTo(0.918 * s.width, 0.455 * s.height);
    p.quadraticBezierTo(0.930 * s.width, 0.520 * s.height,
        0.922 * s.width, 0.585 * s.height);
    p.lineTo(0.852 * s.width, 0.585 * s.height);
    p.quadraticBezierTo(0.842 * s.width, 0.520 * s.height,
        0.842 * s.width, 0.460 * s.height);
    p.close();
    return p;
  }

  void _drawHand(Canvas canvas, Size s, {required bool left}) {
    final fill = Paint()
      ..color = const Color(0xFF1A3035)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF00897B).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    final cx = left ? 0.112 * s.width : 0.888 * s.width;
    final cy = 0.608 * s.height;
    final rx = 0.040 * s.width;
    final ry = 0.028 * s.height;
    final rect = Rect.fromCenter(
        center: Offset(cx, cy), width: rx * 2, height: ry * 2);
    canvas.drawOval(rect, fill);
    canvas.drawOval(rect, stroke);
  }

  Path _buildLThigh(Size s) {
    final p = Path();
    p.moveTo(0.272 * s.width, 0.638 * s.height);
    p.quadraticBezierTo(0.250 * s.width, 0.680 * s.height,
        0.248 * s.width, 0.720 * s.height);
    p.quadraticBezierTo(0.252 * s.width, 0.780 * s.height,
        0.268 * s.width, 0.840 * s.height);
    p.lineTo(0.462 * s.width, 0.840 * s.height);
    p.quadraticBezierTo(0.470 * s.width, 0.780 * s.height,
        0.468 * s.width, 0.720 * s.height);
    p.quadraticBezierTo(0.462 * s.width, 0.660 * s.height,
        0.440 * s.width, 0.638 * s.height);
    p.close();
    return p;
  }

  Path _buildRThigh(Size s) {
    final p = Path();
    p.moveTo(0.728 * s.width, 0.638 * s.height);
    p.quadraticBezierTo(0.750 * s.width, 0.680 * s.height,
        0.752 * s.width, 0.720 * s.height);
    p.quadraticBezierTo(0.748 * s.width, 0.780 * s.height,
        0.732 * s.width, 0.840 * s.height);
    p.lineTo(0.538 * s.width, 0.840 * s.height);
    p.quadraticBezierTo(0.530 * s.width, 0.780 * s.height,
        0.532 * s.width, 0.720 * s.height);
    p.quadraticBezierTo(0.538 * s.width, 0.660 * s.height,
        0.560 * s.width, 0.638 * s.height);
    p.close();
    return p;
  }

  Path _buildLLowerLeg(Size s) {
    final p = Path();
    p.moveTo(0.268 * s.width, 0.840 * s.height);
    // Calf bulge
    p.quadraticBezierTo(0.248 * s.width, 0.880 * s.height,
        0.265 * s.width, 0.930 * s.height);
    p.quadraticBezierTo(0.278 * s.width, 0.960 * s.height,
        0.305 * s.width, 0.970 * s.height);
    p.quadraticBezierTo(0.345 * s.width, 0.978 * s.height,
        0.380 * s.width, 0.972 * s.height);
    p.quadraticBezierTo(0.410 * s.width, 0.965 * s.height,
        0.428 * s.width, 0.940 * s.height);
    p.quadraticBezierTo(0.448 * s.width, 0.885 * s.height,
        0.462 * s.width, 0.840 * s.height);
    p.close();
    return p;
  }

  Path _buildRLowerLeg(Size s) {
    final p = Path();
    p.moveTo(0.732 * s.width, 0.840 * s.height);
    p.quadraticBezierTo(0.752 * s.width, 0.880 * s.height,
        0.735 * s.width, 0.930 * s.height);
    p.quadraticBezierTo(0.722 * s.width, 0.960 * s.height,
        0.695 * s.width, 0.970 * s.height);
    p.quadraticBezierTo(0.655 * s.width, 0.978 * s.height,
        0.620 * s.width, 0.972 * s.height);
    p.quadraticBezierTo(0.590 * s.width, 0.965 * s.height,
        0.572 * s.width, 0.940 * s.height);
    p.quadraticBezierTo(0.552 * s.width, 0.885 * s.height,
        0.538 * s.width, 0.840 * s.height);
    p.close();
    return p;
  }

  void _drawFoot(Canvas canvas, Size s, {required bool left}) {
    final fill = Paint()
      ..color = const Color(0xFF1A3035)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF00897B).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    final cx = left ? 0.348 * s.width : 0.652 * s.width;
    final cy = 0.988 * s.height;
    final p = Path();
    p.addOval(Rect.fromCenter(
        center: Offset(cx, cy),
        width: 0.130 * s.width,
        height: 0.022 * s.height));
    canvas.drawPath(p, fill);
    canvas.drawPath(p, stroke);
  }

  void _drawFaceDetails(Canvas canvas, Size s) {
    final dotPaint = Paint()
      ..color = const Color(0xFF00897B).withOpacity(0.30)
      ..style = PaintingStyle.fill;
    // Eyes
    canvas.drawCircle(
        Offset(0.468 * s.width, 0.062 * s.height), 0.012 * s.width, dotPaint);
    canvas.drawCircle(
        Offset(0.532 * s.width, 0.062 * s.height), 0.012 * s.width, dotPaint);
    // Nose line
    final nosePaint = Paint()
      ..color = const Color(0xFF00897B).withOpacity(0.20)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(0.500 * s.width, 0.072 * s.height),
        Offset(0.500 * s.width, 0.090 * s.height), nosePaint);
    // Mouth
    final mouthPath = Path();
    mouthPath.moveTo(0.470 * s.width, 0.105 * s.height);
    mouthPath.quadraticBezierTo(0.500 * s.width, 0.115 * s.height,
        0.530 * s.width, 0.105 * s.height);
    canvas.drawPath(mouthPath, nosePaint);
  }

  void _drawBackHairline(Canvas canvas, Size s) {
    final hairPaint = Paint()
      ..color = const Color(0xFF00897B).withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final p = Path();
    p.addOval(Rect.fromCenter(
        center: Offset(0.500 * s.width, 0.052 * s.height),
        width: 0.290 * s.width,
        height: 0.085 * s.height));
    canvas.drawPath(p, hairPaint);
  }

  // ── Muscle region overlays ─────────────────────────────────────────────────
  void _drawRegions(Canvas canvas, Size s) {
    final visible = regions.where((r) => isFront ? r.front : r.back);

    for (final region in visible) {
      final group = groups.cast<MuscleGroup?>().firstWhere(
          (g) => g!.id == region.groupId,
          orElse: () => null);
      if (group == null) continue;

      final isSelected = selectedId == region.groupId;
      final c = Color(group.color);

      final fillPaint = Paint()
        ..color = isSelected ? c.withOpacity(0.72) : c.withOpacity(0.28)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = isSelected ? c.withOpacity(1.0) : c.withOpacity(0.60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 1.6 : 0.8;

      for (final builder in region.builders) {
        final path = builder(s);
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);

        if (isSelected) {
          final glowPaint = Paint()
            ..color = c.withOpacity(0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
            ..style = PaintingStyle.fill;
          canvas.drawPath(path, glowPaint);
        }
      }
    }
  }

  // ── Anatomy definition lines ──────────────────────────────────────────────
  void _drawAnatomyLines(Canvas canvas, Size s) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    if (isFront) {
      // Sternum / centre line
      canvas.drawLine(
          Offset(0.500 * s.width, 0.178 * s.height),
          Offset(0.500 * s.width, 0.545 * s.height), linePaint);

      // Chest separation
      canvas.drawLine(
          Offset(0.305 * s.width, 0.338 * s.height),
          Offset(0.695 * s.width, 0.338 * s.height), linePaint);

      // Clavicle lines
      canvas.drawLine(
          Offset(0.330 * s.width, 0.185 * s.height),
          Offset(0.190 * s.width, 0.300 * s.height), linePaint);
      canvas.drawLine(
          Offset(0.670 * s.width, 0.185 * s.height),
          Offset(0.810 * s.width, 0.300 * s.height), linePaint);

      // Ab segments
      final abPaint = Paint()
        ..color = Colors.white.withOpacity(0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawLine(
          Offset(0.340 * s.width, 0.385 * s.height),
          Offset(0.660 * s.width, 0.385 * s.height), abPaint);
      canvas.drawLine(
          Offset(0.345 * s.width, 0.465 * s.height),
          Offset(0.655 * s.width, 0.465 * s.height), abPaint);

      // Knee lines
      final kneePaint = Paint()
        ..color = Colors.white.withOpacity(0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawLine(
          Offset(0.310 * s.width, 0.840 * s.height),
          Offset(0.462 * s.width, 0.840 * s.height), kneePaint);
      canvas.drawLine(
          Offset(0.538 * s.width, 0.840 * s.height),
          Offset(0.690 * s.width, 0.840 * s.height), kneePaint);
    } else {
      // Spine
      canvas.drawLine(
          Offset(0.500 * s.width, 0.178 * s.height),
          Offset(0.500 * s.width, 0.595 * s.height), linePaint);

      // Scapula lines
      final scapPaint = Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      // Left scapula outline
      final lScap = Path();
      lScap.moveTo(0.340 * s.width, 0.215 * s.height);
      lScap.quadraticBezierTo(0.290 * s.width, 0.265 * s.height,
          0.295 * s.width, 0.335 * s.height);
      lScap.quadraticBezierTo(0.340 * s.width, 0.370 * s.height,
          0.420 * s.width, 0.360 * s.height);
      canvas.drawPath(lScap, scapPaint);

      // Right scapula outline
      final rScap = Path();
      rScap.moveTo(0.660 * s.width, 0.215 * s.height);
      rScap.quadraticBezierTo(0.710 * s.width, 0.265 * s.height,
          0.705 * s.width, 0.335 * s.height);
      rScap.quadraticBezierTo(0.660 * s.width, 0.370 * s.height,
          0.580 * s.width, 0.360 * s.height);
      canvas.drawPath(rScap, scapPaint);

      // Glute separation
      canvas.drawLine(
          Offset(0.500 * s.width, 0.595 * s.height),
          Offset(0.500 * s.width, 0.745 * s.height), linePaint);

      // Knee lines
      final kneePaint = Paint()
        ..color = Colors.white.withOpacity(0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawLine(
          Offset(0.268 * s.width, 0.840 * s.height),
          Offset(0.462 * s.width, 0.840 * s.height), kneePaint);
      canvas.drawLine(
          Offset(0.538 * s.width, 0.840 * s.height),
          Offset(0.732 * s.width, 0.840 * s.height), kneePaint);
    }
  }

  // ── Small muscle labels drawn on the canvas ────────────────────────────────
  void _drawMuscleLabels(Canvas canvas, Size s) {
    // Only draw labels for non-selected, visible regions as tiny hints
    final labelPaint = TextPainter(textDirection: TextDirection.ltr);
    final visible = regions.where((r) => isFront ? r.front : r.back);

    for (final region in visible) {
      if (selectedId == region.groupId) continue; // floating label handles this
      final group = groups.cast<MuscleGroup?>().firstWhere(
          (g) => g!.id == region.groupId, orElse: () => null);
      if (group == null) continue;

      final path = region.builders.first(s);
      final bounds = path.getBounds();
      if (bounds.width < 0.04 * s.width) continue; // too small for a label

      final c = Color(group.color);
      labelPaint.text = TextSpan(
        text: group.name,
        style: TextStyle(
          color: c.withOpacity(0.70),
          fontSize: s.width * 0.028,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 3)],
        ),
      );
      labelPaint.layout();

      final center = bounds.center;
      final dx = center.dx - labelPaint.width / 2;
      final dy = center.dy - labelPaint.height / 2;
      labelPaint.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.isFront != isFront || old.selectedId != selectedId;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Presets Tab
// ═══════════════════════════════════════════════════════════════════════════════
class _PresetsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: WorkoutData.presets.length,
      itemBuilder: (_, i) => _PresetCard(preset: WorkoutData.presets[i]),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final WorkoutPreset preset;
  const _PresetCard({required this.preset});

  static IconData _iconForPreset(String presetId) {
    if (presetId.contains('chest') || presetId.contains('push')) {
      return Icons.fitness_center;
    } else if (presetId.contains('back') || presetId.contains('pull')) {
      return Icons.airline_seat_flat;
    } else if (presetId.contains('leg') || presetId.contains('lower') ||
        presetId.contains('quad') || presetId.contains('ham') ||
        presetId.contains('glute') || presetId.contains('hip')) {
      return Icons.directions_run;
    } else if (presetId.contains('arm') || presetId.contains('bicep') ||
        presetId.contains('tricep')) {
      return Icons.sports_handball;
    } else if (presetId.contains('core') || presetId.contains('ab')) {
      return Icons.radio_button_checked;
    } else if (presetId.contains('cardio') || presetId.contains('hiit')) {
      return Icons.favorite;
    } else if (presetId.contains('shoulder')) {
      return Icons.sports_gymnastics;
    } else if (presetId.contains('neck') || presetId.contains('trap')) {
      return Icons.self_improvement;
    } else if (presetId.contains('full') || presetId.contains('body') ||
        presetId.contains('athletic')) {
      return Icons.sports;
    }
    return Icons.fitness_center;
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(preset.color);
    final exercises = WorkoutData.exercisesForPreset(preset);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PresetWorkoutScreen(preset: preset),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color.withOpacity(0.20), color.withOpacity(0.05)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(_iconForPreset(preset.id), color: color, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(preset.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text('${preset.duration} · ${exercises.length} exercises',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ]),
            ),
            _DiffBadge(level: preset.level),
          ]),
          if (preset.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(preset.description,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 12,
                    height: 1.4)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: exercises
                .take(6)
                .map((e) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(e.name,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.play_arrow_rounded, color: color, size: 18),
                const SizedBox(width: 4),
                Text('Start Preset',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DiffBadge extends StatelessWidget {
  final String level;
  const _DiffBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final c = level == 'Beginner'
        ? const Color(0xFF66BB6A)
        : level == 'Intermediate'
            ? const Color(0xFFFFA726)
            : const Color(0xFFEF5350);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(level,
          style:
              TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
