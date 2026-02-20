import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────
enum AvatarHairStyle { wildCurly, spiky, buzz, topknot, wavyBig }
enum AvatarAccessoryType { none, roundGlasses, thirdEye, starPatch, boltScar }

/// Seated / resting poses — drawn anatomically upright
enum AvatarPose {
  crissXLegs,   // sitting cross-legged, hands on knees
  chinRest,     // leaning forward, chin resting in both hands
  peaceOut,     // cross-legged, one arm raised with peace sign
  bellyProp,    // lying on belly, propped on elbows, chin on hands
  armsLocked,   // sitting cross-legged, arms crossed over chest
}

// ─────────────────────────────────────────────────────────────────────────────
// 5 androgynous, zany characters
// ─────────────────────────────────────────────────────────────────────────────
class AvatarCharacter {
  final int id;
  final String vibe;
  final Color skinTone;
  final Color hairColor;
  final Color bgFrom;
  final Color bgTo;
  final AvatarHairStyle hairStyle;
  final AvatarAccessoryType accessory;
  final Color accessoryColor;
  final AvatarPose pose;

  const AvatarCharacter({
    required this.id,
    required this.vibe,
    required this.skinTone,
    required this.hairColor,
    required this.bgFrom,
    required this.bgTo,
    required this.hairStyle,
    required this.accessory,
    required this.accessoryColor,
    required this.pose,
  });
}

const List<AvatarCharacter> kAvatarCharacters = [
  // 0 — Cosmic ✦ criss-cross, third eye
  AvatarCharacter(
    id: 0, vibe: 'Cosmic',
    skinTone: Color(0xFFD4A05A), hairColor: Color(0xFF7B2FBE),
    bgFrom: Color(0xFF6A0572), bgTo: Color(0xFF200040),
    hairStyle: AvatarHairStyle.wildCurly,
    accessory: AvatarAccessoryType.thirdEye, accessoryColor: Color(0xFFFFD700),
    pose: AvatarPose.crissXLegs,
  ),
  // 1 — Blaze 🔥 chin in hands, bolt scar
  AvatarCharacter(
    id: 1, vibe: 'Wildfire',
    skinTone: Color(0xFFB07040), hairColor: Color(0xFFFF4500),
    bgFrom: Color(0xFFFF6D00), bgTo: Color(0xFF7F0000),
    hairStyle: AvatarHairStyle.spiky,
    accessory: AvatarAccessoryType.boltScar, accessoryColor: Color(0xFFFFE040),
    pose: AvatarPose.chinRest,
  ),
  // 2 — Glitch ⚡ peace sign, round glasses
  AvatarCharacter(
    id: 2, vibe: 'Glitch',
    skinTone: Color(0xFFF0C8A0), hairColor: Color(0xFF00E5FF),
    bgFrom: Color(0xFF00B0FF), bgTo: Color(0xFF002171),
    hairStyle: AvatarHairStyle.buzz,
    accessory: AvatarAccessoryType.roundGlasses, accessoryColor: Color(0xFF00E5FF),
    pose: AvatarPose.peaceOut,
  ),
  // 3 — Mochi ☁️ belly-prop, star patch
  AvatarCharacter(
    id: 3, vibe: 'Dreamy',
    skinTone: Color(0xFFFFDBAC), hairColor: Color(0xFFFF80AB),
    bgFrom: Color(0xFFF48FB1), bgTo: Color(0xFF880E4F),
    hairStyle: AvatarHairStyle.topknot,
    accessory: AvatarAccessoryType.starPatch, accessoryColor: Color(0xFFFFD740),
    pose: AvatarPose.bellyProp,
  ),
  // 4 — Riot ⚡ arms crossed, no extra accessory
  AvatarCharacter(
    id: 4, vibe: 'Riot',
    skinTone: Color(0xFFD4A078), hairColor: Color(0xFF76FF03),
    bgFrom: Color(0xFF33691E), bgTo: Color(0xFF1A237E),
    hairStyle: AvatarHairStyle.wavyBig,
    accessory: AvatarAccessoryType.none, accessoryColor: Colors.transparent,
    pose: AvatarPose.armsLocked,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// AvatarFacePainter — draws face-only (badges) OR full posed body
// ─────────────────────────────────────────────────────────────────────────────
class AvatarFacePainter extends CustomPainter {
  final AvatarCharacter character;
  final bool showBody;

  const AvatarFacePainter(this.character, {this.showBody = false});

  // ── Helpers ──────────────────────────────────────────────────────────
  Paint _clothPaint(Size size, double cx, double topY) => Paint()
    ..shader = LinearGradient(
      colors: [character.bgFrom, character.bgTo],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, topY, size.width, size.height - topY));

  RRect _rr(double l, double t, double r, double b, double radius) =>
      RRect.fromRectAndRadius(Rect.fromLTRB(l, t, r, b), Radius.circular(radius));

  RRect _rrc(double cx, double cy, double w, double h, double radius) =>
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
          Radius.circular(radius));

  // ── Main paint ───────────────────────────────────────────────────────
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = showBody ? size.height * 0.26 : size.height / 2;
    final r  = showBody ? size.width * 0.22 : size.width * 0.42;

    if (showBody) _paintBody(canvas, size, cx, cy, r);

    // Background gradient circle (head area)
    canvas.drawCircle(Offset(cx, cy), r * 1.18,
      Paint()..shader = LinearGradient(
        colors: [character.bgFrom, character.bgTo],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 1.18)));

    // Hair back
    _drawHairBack(canvas, cx, cy, r);

    // Skin face
    canvas.drawCircle(Offset(cx, cy + r * 0.06), r * 0.72,
        Paint()..color = character.skinTone);

    // Neck + shoulders (only in face-only mode; body mode draws its own)
    if (!showBody) {
      _drawNeckShoulder(canvas, cx, cy, r);
    }

    // Eyes
    _drawEye(canvas, Offset(cx - r * 0.23, cy - r * 0.04), r * 0.10);
    _drawEye(canvas, Offset(cx + r * 0.23, cy - r * 0.04), r * 0.10);

    // Brows
    _drawBrow(canvas, cx, cy, r, left: true);
    _drawBrow(canvas, cx, cy, r, left: false);

    // Nose
    final np = Paint()
      ..color = character.skinTone.withValues(alpha: 0.55)
      ..strokeWidth = r * 0.04 ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final nosePath = Path()
      ..moveTo(cx, cy - r * 0.01)
      ..lineTo(cx - r * 0.07, cy + r * 0.14)
      ..arcToPoint(Offset(cx + r * 0.07, cy + r * 0.14),
          radius: Radius.circular(r * 0.07), clockwise: false);
    canvas.drawPath(nosePath, np);

    // Smile + teeth
    canvas.drawRRect(_rrc(cx, cy + r * 0.30, r * 0.38, r * 0.18, r * 0.06),
        Paint()..color = const Color(0xFFFFFDE7));
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy + r * 0.22), width: r * 0.48, height: r * 0.32),
      0.15, math.pi - 0.3, false,
      Paint()..color = const Color(0xFF8B2020)
        ..strokeWidth = r * 0.055 ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke);

    // Hair front
    _drawHairFront(canvas, cx, cy, r);

    // Accessory
    _drawAccessory(canvas, cx, cy, r);
  }

  void _drawNeckShoulder(Canvas canvas, double cx, double cy, double r) {
    final skin = Paint()..color = character.skinTone;
    canvas.drawRRect(_rrc(cx, cy + r * 0.90, r * 0.32, r * 0.38, 8), skin);
    final sp = Path()
      ..moveTo(cx - r * 0.7, cy + r * 1.18)
      ..quadraticBezierTo(cx - r * 0.38, cy + r * 0.90, cx - r * 0.17, cy + r * 0.96)
      ..lineTo(cx + r * 0.17, cy + r * 0.96)
      ..quadraticBezierTo(cx + r * 0.38, cy + r * 0.90, cx + r * 0.7, cy + r * 1.18)
      ..close();
    canvas.drawPath(sp, Paint()..color =
        Color.lerp(character.bgFrom, Colors.white, 0.35)!);
  }

  // ── Body poses ───────────────────────────────────────────────────────
  void _paintBody(Canvas canvas, Size size, double cx, double headCy, double r) {
    final sc  = size.width / 120.0;
    final cp  = _clothPaint(size, cx, headCy + r);
    final leg = Paint()..color = Color.lerp(character.bgTo, Colors.black, 0.28)!;
    final sho = Paint()..color = Color.lerp(character.hairColor, Colors.black, 0.42)!;
    final skin = Paint()..color = character.skinTone;

    switch (character.pose) {
      case AvatarPose.crissXLegs:
        _poseCrissX(canvas, sc, cx, headCy, r, cp, leg, sho, skin);
      case AvatarPose.chinRest:
        _poseChinRest(canvas, sc, cx, headCy, r, cp, leg, sho, skin);
      case AvatarPose.peaceOut:
        _posePeaceOut(canvas, sc, cx, headCy, r, cp, leg, sho, skin);
      case AvatarPose.bellyProp:
        _poseBellyProp(canvas, sc, cx, headCy, r, cp, leg, sho, skin);
      case AvatarPose.armsLocked:
        _poseArmsLocked(canvas, sc, cx, headCy, r, cp, leg, sho, skin);
    }
  }

  // ── Pose 1: criss-cross legs, hands resting on knees ─────────────────
  void _poseCrissX(Canvas c, double sc, double cx, double hcy, double r,
      Paint cp, Paint leg, Paint sho, Paint skin) {
    // Torso
    c.drawRRect(_rrc(cx, hcy + r * 2.2, sc * 52, sc * 40, sc * 11), cp);
    // Wide lap (the two crossed legs viewed from front)
    c.drawRRect(_rr(cx - sc * 44, hcy + r * 3.5, cx + sc * 44,
        hcy + r * 4.8, sc * 10), leg);
    // Left knee bump
    c.drawRRect(_rrc(cx - sc * 30, hcy + r * 3.9, sc * 32, sc * 22, sc * 9), leg);
    // Right knee bump
    c.drawRRect(_rrc(cx + sc * 30, hcy + r * 3.9, sc * 32, sc * 22, sc * 9), leg);
    // Shoes peeking out bottom corners
    c.drawRRect(_rrc(cx - sc * 38, hcy + r * 4.85, sc * 22, sc * 14, sc * 6), sho);
    c.drawRRect(_rrc(cx + sc * 38, hcy + r * 4.85, sc * 22, sc * 14, sc * 6), sho);
    // Arms (resting on knees, short forearm down)
    c.drawRRect(_rrc(cx - sc * 24, hcy + r * 3.05, sc * 14, sc * 30, sc * 7), cp);
    c.drawRRect(_rrc(cx + sc * 24, hcy + r * 3.05, sc * 14, sc * 30, sc * 7), cp);
    // Hands on knees
    c.drawCircle(Offset(cx - sc * 24, hcy + r * 4.0), sc * 9, skin);
    c.drawCircle(Offset(cx + sc * 24, hcy + r * 4.0), sc * 9, skin);
  }

  // ── Pose 2: leaning forward, chin resting in cupped hands ─────────────
  void _poseChinRest(Canvas c, double sc, double cx, double hcy, double r,
      Paint cp, Paint leg, Paint sho, Paint skin) {
    // Cross-legged base
    c.drawRRect(_rr(cx - sc * 40, hcy + r * 3.3, cx + sc * 40,
        hcy + r * 4.6, sc * 9), leg);
    c.drawRRect(_rrc(cx - sc * 27, hcy + r * 3.7, sc * 30, sc * 20, sc * 8), leg);
    c.drawRRect(_rrc(cx + sc * 27, hcy + r * 3.7, sc * 30, sc * 20, sc * 8), leg);
    c.drawRRect(_rrc(cx - sc * 36, hcy + r * 4.65, sc * 20, sc * 12, sc * 5), sho);
    c.drawRRect(_rrc(cx + sc * 36, hcy + r * 4.65, sc * 20, sc * 12, sc * 5), sho);
    // Torso (slightly forward lean = taller/narrower)
    c.drawRRect(_rrc(cx, hcy + r * 2.15, sc * 48, sc * 38, sc * 10), cp);
    // Forearms angling up from elbows (on knees) to hands under chin
    // Left forearm
    _drawAngledArm(c, Offset(cx - sc * 24, hcy + r * 3.4),
        Offset(cx - sc * 12, hcy + r * 1.3), sc * 11, cp);
    // Right forearm
    _drawAngledArm(c, Offset(cx + sc * 24, hcy + r * 3.4),
        Offset(cx + sc * 12, hcy + r * 1.3), sc * 11, cp);
    // Cupped hands under chin
    c.drawOval(
        Rect.fromCenter(center: Offset(cx, hcy + r * 1.08),
            width: sc * 32, height: sc * 14),
        skin);
    // Knuckle detail
    for (final i in [-1, 0, 1]) {
      c.drawCircle(Offset(cx + i * sc * 8, hcy + r * 1.02), sc * 3.5,
          Paint()..color = character.skinTone.withValues(alpha: 0.6));
    }
  }

  // ── Pose 3: sitting cross-legged, one arm raised with peace sign ──────
  void _posePeaceOut(Canvas c, double sc, double cx, double hcy, double r,
      Paint cp, Paint leg, Paint sho, Paint skin) {
    // Cross-legged base
    c.drawRRect(_rr(cx - sc * 42, hcy + r * 3.4, cx + sc * 42,
        hcy + r * 4.7, sc * 10), leg);
    c.drawRRect(_rrc(cx - sc * 28, hcy + r * 3.8, sc * 30, sc * 20, sc * 8), leg);
    c.drawRRect(_rrc(cx + sc * 28, hcy + r * 3.8, sc * 30, sc * 20, sc * 8), leg);
    c.drawRRect(_rrc(cx - sc * 38, hcy + r * 4.75, sc * 20, sc * 12, sc * 5), sho);
    c.drawRRect(_rrc(cx + sc * 38, hcy + r * 4.75, sc * 20, sc * 12, sc * 5), sho);
    // Torso
    c.drawRRect(_rrc(cx, hcy + r * 2.2, sc * 52, sc * 40, sc * 11), cp);
    // Left arm — resting down on left knee
    c.drawRRect(_rrc(cx - sc * 24, hcy + r * 3.1, sc * 13, sc * 28, sc * 6), cp);
    c.drawCircle(Offset(cx - sc * 24, hcy + r * 4.1), sc * 8, skin);
    // Right arm — raised up-right (upper arm + forearm)
    _drawAngledArm(c, Offset(cx + sc * 22, hcy + r * 1.8),
        Offset(cx + sc * 38, hcy + r * 0.3), sc * 12, cp);
    // Peace sign hand (two fingers as V)
    final handCx = cx + sc * 42;
    final handCy = hcy + r * 0.0;
    // Palm
    c.drawOval(
        Rect.fromCenter(center: Offset(handCx, handCy + sc * 6),
            width: sc * 14, height: sc * 12),
        skin);
    // Index finger
    c.drawRRect(_rrc(handCx - sc * 4, handCy - sc * 6, sc * 6, sc * 16, sc * 3), skin);
    // Middle finger
    c.drawRRect(_rrc(handCx + sc * 4, handCy - sc * 7, sc * 6, sc * 18, sc * 3), skin);
  }

  // ── Pose 4: lying on belly, propped on elbows, chin on hands ──────────
  void _poseBellyProp(Canvas c, double sc, double cx, double hcy, double r,
      Paint cp, Paint leg, Paint sho, Paint skin) {
    // Body lying flat (horizontal shape at bottom)
    c.drawRRect(_rrc(cx, hcy + r * 4.2, sc * 88, sc * 28, sc * 14), cp);
    // Feet / shoes at far right
    c.drawRRect(_rrc(cx + sc * 38, hcy + r * 4.2, sc * 20, sc * 16, sc * 7), sho);
    // Elbows propped on "surface" (near bottom of head area)
    c.drawRRect(_rrc(cx - sc * 22, hcy + r * 2.7, sc * 18, sc * 14, sc * 7), cp);
    c.drawRRect(_rrc(cx + sc * 22, hcy + r * 2.7, sc * 18, sc * 14, sc * 7), cp);
    // Forearms going upward to support chin
    _drawAngledArm(c, Offset(cx - sc * 22, hcy + r * 2.7),
        Offset(cx - sc * 10, hcy + r * 1.2), sc * 12, cp);
    _drawAngledArm(c, Offset(cx + sc * 22, hcy + r * 2.7),
        Offset(cx + sc * 10, hcy + r * 1.2), sc * 12, cp);
    // Cupped hands
    c.drawOval(
        Rect.fromCenter(center: Offset(cx, hcy + r * 1.05),
            width: sc * 34, height: sc * 14),
        skin);
  }

  // ── Pose 5: sitting cross-legged, arms folded / crossed over chest ────
  void _poseArmsLocked(Canvas c, double sc, double cx, double hcy, double r,
      Paint cp, Paint leg, Paint sho, Paint skin) {
    // Cross-legged base
    c.drawRRect(_rr(cx - sc * 42, hcy + r * 3.4, cx + sc * 42,
        hcy + r * 4.65, sc * 10), leg);
    c.drawRRect(_rrc(cx - sc * 28, hcy + r * 3.8, sc * 30, sc * 20, sc * 8), leg);
    c.drawRRect(_rrc(cx + sc * 28, hcy + r * 3.8, sc * 30, sc * 20, sc * 8), leg);
    c.drawRRect(_rrc(cx - sc * 38, hcy + r * 4.72, sc * 20, sc * 12, sc * 5), sho);
    c.drawRRect(_rrc(cx + sc * 38, hcy + r * 4.72, sc * 20, sc * 12, sc * 5), sho);
    // Torso
    c.drawRRect(_rrc(cx, hcy + r * 2.2, sc * 52, sc * 40, sc * 11), cp);
    // Crossed arms (two bands over the chest forming an X)
    // Left arm going right: a thick diagonal rounded rect
    _drawAngledArm(c, Offset(cx - sc * 25, hcy + r * 1.85),
        Offset(cx + sc * 14, hcy + r * 2.7), sc * 14, cp);
    // Right arm going left (on top)
    _drawAngledArm(c, Offset(cx + sc * 25, hcy + r * 1.85),
        Offset(cx - sc * 14, hcy + r * 2.7), sc * 14, cp);
    // Fist knuckles visible at each side
    c.drawCircle(Offset(cx - sc * 18, hcy + r * 2.7), sc * 8, skin);
    c.drawCircle(Offset(cx + sc * 18, hcy + r * 2.7), sc * 8, skin);
  }

  // Utility: draw a thick rounded "arm" as a filled capsule between two points
  void _drawAngledArm(Canvas c, Offset from, Offset to, double thickness, Paint p) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final angle = math.atan2(dy, dx);
    final len = math.sqrt(dx * dx + dy * dy);
    final midX = (from.dx + to.dx) / 2;
    final midY = (from.dy + to.dy) / 2;

    c.save();
    c.translate(midX, midY);
    c.rotate(angle);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: len, height: thickness),
        Radius.circular(thickness / 2),
      ),
      p,
    );
    c.restore();
  }

  // ── Eye ──────────────────────────────────────────────────────────────
  void _drawEye(Canvas canvas, Offset c, double radius) {
    canvas.drawCircle(c, radius * 1.15, Paint()..color = const Color(0xFFFFFCF5));
    canvas.drawCircle(c, radius * 0.74, Paint()..color = const Color(0xFF3E2723));
    canvas.drawCircle(c, radius * 0.40, Paint()..color = const Color(0xFF111111));
    canvas.drawCircle(Offset(c.dx + radius * 0.3, c.dy - radius * 0.3), radius * 0.24,
        Paint()..color = Colors.white);
    final lp = Paint()..color = const Color(0xFF111111)
      ..strokeWidth = radius * 0.20 ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(c.dx + i * radius * 0.48, c.dy - radius * 0.88),
        Offset(c.dx + i * radius * 0.56, c.dy - radius * 1.4), lp);
    }
  }

  // ── Eyebrow ───────────────────────────────────────────────────────────
  void _drawBrow(Canvas canvas, double cx, double cy, double r,
      {required bool left}) {
    final sign = left ? -1.0 : 1.0;
    final bx = cx + sign * r * 0.22;
    final bp = Paint()..color = character.hairColor
      ..strokeWidth = r * 0.065 ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(bx - sign * r * 0.14, cy - r * 0.22)
      ..quadraticBezierTo(bx, cy - r * 0.30, bx + sign * r * 0.14, cy - r * 0.22);
    canvas.drawPath(path, bp);
  }

  // ── Hair back ─────────────────────────────────────────────────────────
  void _drawHairBack(Canvas canvas, double cx, double cy, double r) {
    final p = Paint()..color = character.hairColor;
    switch (character.hairStyle) {
      case AvatarHairStyle.wildCurly:
        for (var i = 0; i < 14; i++) {
          final a = (i / 14) * 2 * math.pi;
          canvas.drawCircle(
            Offset(cx + math.cos(a) * r * 0.73, cy - r * 0.10 + math.sin(a) * r * 0.73),
            r * 0.20, p);
        }
        canvas.drawCircle(Offset(cx, cy - r * 0.10), r * 0.70, p);
      case AvatarHairStyle.spiky:
        canvas.drawCircle(Offset(cx, cy - r * 0.20), r * 0.68, p);
        for (var i = -2; i <= 2; i++) {
          final sx = cx + i * r * 0.26;
          final spike = Path()
            ..moveTo(sx - r * 0.12, cy - r * 0.55)
            ..lineTo(sx, cy - r * 1.1 - i.abs() * r * 0.08)
            ..lineTo(sx + r * 0.12, cy - r * 0.55)
            ..close();
          canvas.drawPath(spike, p);
        }
      case AvatarHairStyle.buzz:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy - r * 0.34),
                width: r * 1.36, height: r * 0.88),
            Radius.circular(r * 0.55)),
          p);
      case AvatarHairStyle.topknot:
        canvas.drawCircle(Offset(cx, cy - r * 0.18), r * 0.70, p);
        canvas.drawCircle(Offset(cx, cy - r * 0.90), r * 0.32, p);
      case AvatarHairStyle.wavyBig:
        canvas.drawCircle(Offset(cx, cy - r * 0.20), r * 0.72, p);
        for (var i = 0; i < 6; i++) {
          canvas.drawCircle(
              Offset(cx - r * 0.68 + i * r * 0.30, cy - r * 0.65), r * 0.18, p);
        }
        canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx - r * 0.76, cy + r * 0.28),
                width: r * 0.28, height: r * 0.80),
            Radius.circular(r * 0.14)), p);
        canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx + r * 0.76, cy + r * 0.28),
                width: r * 0.28, height: r * 0.80),
            Radius.circular(r * 0.14)), p);
    }
  }

  // ── Hair front ────────────────────────────────────────────────────────
  void _drawHairFront(Canvas canvas, double cx, double cy, double r) {
    final p = Paint()..color = character.hairColor;
    if (character.hairStyle == AvatarHairStyle.buzz ||
        character.hairStyle == AvatarHairStyle.spiky) {
      final path = Path()
        ..moveTo(cx - r * 0.66, cy - r * 0.12)
        ..quadraticBezierTo(cx, cy - r * 0.86, cx + r * 0.66, cy - r * 0.12)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  // ── Accessory ─────────────────────────────────────────────────────────
  void _drawAccessory(Canvas canvas, double cx, double cy, double r) {
    final p = Paint()..color = character.accessoryColor;
    switch (character.accessory) {
      case AvatarAccessoryType.roundGlasses:
        final gp = Paint()..color = character.accessoryColor
          ..strokeWidth = r * 0.055 ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset(cx - r * 0.23, cy - r * 0.04), r * 0.17, gp);
        canvas.drawCircle(Offset(cx + r * 0.23, cy - r * 0.04), r * 0.17, gp);
        canvas.drawLine(Offset(cx - r * 0.06, cy - r * 0.04),
            Offset(cx + r * 0.06, cy - r * 0.04), gp);
        canvas.drawLine(Offset(cx - r * 0.40, cy - r * 0.04),
            Offset(cx - r * 0.56, cy + r * 0.04), gp);
        canvas.drawLine(Offset(cx + r * 0.40, cy - r * 0.04),
            Offset(cx + r * 0.56, cy + r * 0.04), gp);
      case AvatarAccessoryType.thirdEye:
        canvas.drawCircle(Offset(cx, cy - r * 0.42), r * 0.09, p);
        canvas.drawCircle(Offset(cx, cy - r * 0.42), r * 0.05,
            Paint()..color = Colors.white);
        canvas.drawCircle(Offset(cx, cy - r * 0.42), r * 0.14,
          Paint()..color = character.accessoryColor.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      case AvatarAccessoryType.starPatch:
        _drawStar(canvas, Offset(cx - r * 0.23, cy - r * 0.04),
            r * 0.17, character.accessoryColor);
      case AvatarAccessoryType.boltScar:
        final bolt = Path()
          ..moveTo(cx + r * 0.22, cy - r * 0.30)
          ..lineTo(cx + r * 0.08, cy + r * 0.02)
          ..lineTo(cx + r * 0.22, cy + r * 0.04)
          ..lineTo(cx + r * 0.06, cy + r * 0.32);
        canvas.drawPath(bolt, Paint()..color = character.accessoryColor
          ..strokeWidth = r * 0.08 ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);
      case AvatarAccessoryType.none:
        break;
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? radius : radius * 0.45;
      final angle = (i * math.pi / 5) - math.pi / 2;
      final pt = Offset(center.dx + rad * math.cos(angle),
          center.dy + rad * math.sin(angle));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.82));
  }

  @override
  bool shouldRepaint(AvatarFacePainter old) =>
      old.character.id != character.id || old.showBody != showBody;
}

// ─────────────────────────────────────────────────────────────────────────────
// AvatarWidget
// ─────────────────────────────────────────────────────────────────────────────
class AvatarWidget extends StatelessWidget {
  final AvatarCharacter character;
  final double size;
  final bool showRing;
  final bool showBody;

  const AvatarWidget({
    super.key,
    required this.character,
    this.size = 52,
    this.showRing = false,
    this.showBody = false,
  });

  @override
  Widget build(BuildContext context) {
    final painter = AvatarFacePainter(character, showBody: showBody);
    if (showBody) {
      return CustomPaint(size: Size(size, size), painter: painter);
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showRing ? Border.all(color: character.bgFrom, width: 2.5) : null,
        boxShadow: showRing
            ? [BoxShadow(color: character.bgFrom.withValues(alpha: 0.45),
                  blurRadius: 12, spreadRadius: 1)]
            : null,
      ),
      child: ClipOval(
        child: CustomPaint(size: Size(size, size), painter: painter),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AvatarSelectorWidget
// ─────────────────────────────────────────────────────────────────────────────
class AvatarSelectorWidget extends StatefulWidget {
  final String userName;
  final double size;
  final bool showLabel;
  final Function(int avatarId)? onAvatarSelected;

  const AvatarSelectorWidget({
    super.key, required this.userName,
    this.size = 56, this.showLabel = true, this.onAvatarSelected,
  });

  static Future<int> getSavedAvatarId(String userName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('avatar_${userName.toLowerCase()}') ?? 0;
  }

  static Future<void> saveAvatarId(String userName, int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('avatar_${userName.toLowerCase()}', id);
  }

  @override
  State<AvatarSelectorWidget> createState() => _AvatarSelectorWidgetState();
}

class _AvatarSelectorWidgetState extends State<AvatarSelectorWidget>
    with SingleTickerProviderStateMixin {
  int _selectedId = 0;
  bool _open = false;
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 380), vsync: this);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _load();
  }

  Future<void> _load() async {
    final id = await AvatarSelectorWidget.getSavedAvatarId(widget.userName);
    if (mounted) setState(() => _selectedId = id);
  }

  Future<void> _pick(int id) async {
    setState(() { _selectedId = id; _open = false; });
    _ctrl.reverse();
    await AvatarSelectorWidget.saveAvatarId(widget.userName, id);
    widget.onAvatarSelected?.call(id);
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final selected = kAvatarCharacters[_selectedId];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _toggle,
              child: AnimatedScale(
                scale: _open ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: AvatarWidget(character: selected, size: widget.size, showRing: true),
              ),
            ),
            if (widget.showLabel) ...[
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.userName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [selected.bgFrom, selected.bgTo]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(selected.vibe,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                          color: Colors.white, letterSpacing: 0.8)),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _toggle,
                  child: Text(_open ? 'done ↑' : 'swap avatar ↓',
                      style: TextStyle(fontSize: 11,
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline)),
                ),
              ]),
            ],
          ],
        ),
        SizeTransition(
          sizeFactor: _anim,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _ctrl, curve: const Interval(0.2, 1.0)),
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: kAvatarCharacters.map((c) {
                  final isSel = c.id == _selectedId;
                  return GestureDetector(
                    onTap: () => _pick(c.id),
                    child: AnimatedScale(
                      scale: isSel ? 1.14 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        AvatarWidget(character: c, size: 44, showRing: isSel),
                        const SizedBox(height: 5),
                        Text(c.vibe, style: TextStyle(
                          fontSize: 9,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? c.bgFrom : Colors.grey[500],
                          letterSpacing: 0.5,
                        )),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AvatarBadge
// ─────────────────────────────────────────────────────────────────────────────
class AvatarBadge extends StatefulWidget {
  final String userName;
  final double size;
  const AvatarBadge({super.key, required this.userName, this.size = 36});

  @override
  State<AvatarBadge> createState() => _AvatarBadgeState();
}

class _AvatarBadgeState extends State<AvatarBadge> {
  int _id = 0;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final id = await AvatarSelectorWidget.getSavedAvatarId(widget.userName);
    if (mounted) setState(() => _id = id);
  }
  @override
  Widget build(BuildContext context) =>
      AvatarWidget(character: kAvatarCharacters[_id], size: widget.size);
}

// ─────────────────────────────────────────────────────────────────────────────
// FloatingAvatarWidget — seated character that bounces in and idles.
// Rendered between the profile card and calendar card in the dashboard.
// When the key changes (new avatar selected), a fresh entry animation plays.
// ─────────────────────────────────────────────────────────────────────────────

// Idle personality per character
class _IdleP {
  final Duration period;
  final double yAmp;   // bob px
  final double rAmp;   // tiny tilt radians
  final double xAmp;
  const _IdleP({required this.period, required this.yAmp,
      required this.rAmp, this.xAmp = 0});
}

const _kIdle = [
  _IdleP(period: Duration(milliseconds: 2800), yAmp: 5,  rAmp: 0.04),          // Cosmic
  _IdleP(period: Duration(milliseconds: 640),  yAmp: 9,  rAmp: 0.08, xAmp: 1), // Wildfire
  _IdleP(period: Duration(milliseconds: 470),  yAmp: 4,  rAmp: 0.09, xAmp: 2), // Glitch
  _IdleP(period: Duration(milliseconds: 4100), yAmp: 3,  rAmp: 0.03),           // Dreamy
  _IdleP(period: Duration(milliseconds: 510),  yAmp: 10, rAmp: 0.10),           // Riot
];

Offset _floatOffset(int id, double t) {
  final p = _kIdle[id];
  final sin = math.sin(t * math.pi);
  return switch (id) {
    2 => Offset(math.sin((t * 6).floorToDouble() / 6 * 31.4) * p.xAmp,
                -p.yAmp * (t * 6).floorToDouble() / 6),
    _ => Offset(p.xAmp * math.sin(t * math.pi * 0.5), -p.yAmp * sin),
  };
}

double _floatRot(int id, double t) {
  final p = _kIdle[id];
  return switch (id) {
    2 => math.sin((t * 6).floorToDouble() / 6 * 47.1) * p.rAmp,
    4 => -p.rAmp * math.pow(math.sin(t * math.pi * 2), 2).toDouble(),
    _ => math.sin(t * math.pi) * p.rAmp,
  };
}

class FloatingAvatarWidget extends StatefulWidget {
  final AvatarCharacter character;
  final double size;

  const FloatingAvatarWidget({
    super.key,
    required this.character,
    this.size = 100,
  });

  @override
  State<FloatingAvatarWidget> createState() => _FloatingAvatarState();
}

class _FloatingAvatarState extends State<FloatingAvatarWidget>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double>   _entryY;     // slide up from below
  late Animation<double>   _entryFade;
  late Animation<double>   _entryScale;
  late AnimationController _idleCtrl;

  @override
  void initState() {
    super.initState();
    _buildControllers();
    _entryCtrl.forward();
  }

  void _buildControllers() {
    _entryCtrl = AnimationController(
        duration: const Duration(milliseconds: 680), vsync: this);
    _entryY = Tween<double>(begin: 60, end: 0).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.0, 0.78, curve: Curves.easeOutBack)));
    _entryFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.0, 0.44, curve: Curves.easeIn)));
    _entryScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.55, end: 1.08), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0),  weight: 35),
    ]).animate(_entryCtrl);

    final p = _kIdle[widget.character.id.clamp(0, _kIdle.length - 1)];
    _idleCtrl = AnimationController(duration: p.period, vsync: this);
    _entryCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) _idleCtrl.repeat();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _idleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.character.id.clamp(0, _kIdle.length - 1);
    return AnimatedBuilder(
      animation: Listenable.merge([_entryCtrl, _idleCtrl]),
      builder: (context, child) {
        final idle = _idleCtrl.value;
        final off  = _floatOffset(id, idle);
        final rot  = _floatRot(id, idle);
        return Transform.translate(
          offset: Offset(off.dx, _entryY.value + off.dy),
          child: Opacity(
            opacity: _entryFade.value.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: rot,
              child: Transform.scale(
                scale: _entryScale.value,
                child: child,
              ),
            ),
          ),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: widget.character.bgTo.withValues(alpha: 0.45),
              blurRadius: 22, spreadRadius: 2, offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 8, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: AvatarFacePainter(widget.character, showBody: true),
        ),
      ),
    );
  }
}
