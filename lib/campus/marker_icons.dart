import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    show BytesMapBitmap;
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import 'campus_data.dart';

/// Renders Phosphor icons into map marker bitmaps (circular badges and pins).
class MarkerIcons {
  static const _scale = 3.0; // render at 3x, display at logical size

  late final BitmapDescriptor stop;
  late final BitmapDescriptor stopActive;
  late final BitmapDescriptor user;
  late final BitmapDescriptor pickup;
  late final BitmapDescriptor pickupOutside;
  late final BitmapDescriptor destination;
  final Map<String, BitmapDescriptor> shuttles = {};
  final Map<FacilityType, BitmapDescriptor> facilities = {};

  static Future<MarkerIcons> load() async {
    final m = MarkerIcons();
    m.stop = await _badge(PhosphorIconsFill.signpost,
        fill: Colors.white, iconColor: AppColors.ink, border: AppColors.ink,
        size: 30);
    m.stopActive = await _badge(PhosphorIconsFill.signpost,
        fill: AppColors.violet, iconColor: Colors.white, size: 38);
    m.user = await _userDot();
    m.pickup = await _badge(PhosphorIconsFill.personSimpleWalk,
        fill: AppColors.violet, iconColor: Colors.white, size: 46, pin: true);
    m.pickupOutside = await _badge(PhosphorIconsFill.warning,
        fill: AppColors.warning, iconColor: Colors.white, size: 46, pin: true);
    m.destination = await _badge(PhosphorIconsFill.flagCheckered,
        fill: AppColors.ink, iconColor: Colors.white, size: 46, pin: true);
    for (final line in CampusData.lines) {
      m.shuttles[line.id] = await _badge(PhosphorIconsFill.navigationArrow,
          fill: line.color, iconColor: Colors.white, size: 40);
    }
    for (final type in FacilityType.values) {
      m.facilities[type] = await _badge(type.icon,
          fill: type.color, iconColor: Colors.white, size: 34);
    }
    return m;
  }

  static Future<BitmapDescriptor> _badge(
    IconData icon, {
    required Color fill,
    required Color iconColor,
    Color? border,
    required double size,
    bool pin = false,
  }) async {
    const margin = 8.0; // room for the shadow
    final width = size + margin * 2;
    final height = size + margin * 2 + (pin ? size * 0.3 : 0);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_scale);
    final center = Offset(width / 2, margin + size / 2);

    final shadow = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center.translate(0, 2), size / 2, shadow);

    if (pin) {
      final tip = Path()
        ..moveTo(center.dx - size * 0.16, center.dy + size * 0.42)
        ..lineTo(center.dx, center.dy + size * 0.78)
        ..lineTo(center.dx + size * 0.16, center.dy + size * 0.42)
        ..close();
      canvas.drawPath(tip, Paint()..color = Colors.white);
    }

    canvas.drawCircle(center, size / 2, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      size / 2 - (border != null ? 2 : 3),
      Paint()..color = fill,
    );
    if (border != null) {
      canvas.drawCircle(
        center,
        size / 2 - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = border,
      );
    }

    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.52,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: iconColor,
        ),
      ),
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );

    return _toDescriptor(recorder, width, height);
  }

  static Future<BitmapDescriptor> _userDot() async {
    const size = 56.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_scale);
    const c = Offset(size / 2, size / 2);
    canvas.drawCircle(c, 26, Paint()..color = AppColors.sky.withValues(alpha: 0.18));
    canvas.drawCircle(c, 11, Paint()..color = Colors.white);
    canvas.drawCircle(c, 8, Paint()..color = AppColors.sky);
    return _toDescriptor(recorder, size, size);
  }

  static Future<BitmapDescriptor> _toDescriptor(
    ui.PictureRecorder recorder,
    double width,
    double height,
  ) async {
    final image = await recorder
        .endRecording()
        .toImage((width * _scale).ceil(), (height * _scale).ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BytesMapBitmap(bytes!.buffer.asUint8List(), width: width);
  }
}
