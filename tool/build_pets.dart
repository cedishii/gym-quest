// Assembles the five pet sprites from Kenney's Monster Builder Pack
// (https://kenney.nl/assets/monster-builder-pack, CC0).
//
// Usage:
//   dart run tool/build_pets.dart <path to kenney_monster-builder-pack/PNG/Default>
//
// Writes assets/pets/<element>.png. The parts are layered in this order:
// legs, arms, head details, body, face. Right-side limbs/details are the
// left-side image mirrored.
import 'dart:io';

import 'package:image/image.dart' as img;

class PetDesign {
  const PetDesign({
    required this.file,
    required this.body,
    required this.arm,
    required this.leg,
    required this.detail,
    required this.eyes,
    required this.mouth,
    this.nose,
    this.cyclops = false,
    this.armLift = 0.24,
    this.detailSpread = 0.30,
  });

  final String file;
  final String body;
  final String arm;
  final String leg;
  final String detail;
  final String eyes;
  final String mouth;
  final String? nose;
  final bool cyclops;
  final double armLift;
  final double detailSpread;
}

const designs = [
  PetDesign(
    file: 'fire',
    body: 'body_redA',
    arm: 'arm_redA',
    leg: 'leg_redA',
    detail: 'detail_red_horn_small',
    eyes: 'eye_human_red',
    mouth: 'mouthC',
  ),
  PetDesign(
    file: 'water',
    body: 'body_blueD',
    arm: 'arm_blueE',
    leg: 'leg_blueD',
    detail: 'detail_blue_ear_round',
    eyes: 'eye_human_blue',
    mouth: 'mouthB',
    detailSpread: 0.34,
  ),
  PetDesign(
    file: 'leaf',
    body: 'body_greenF',
    arm: 'arm_greenB',
    leg: 'leg_greenB',
    detail: 'detail_green_antenna_small',
    eyes: 'eye_human_green',
    mouth: 'mouth_closed_happy',
    cyclops: true,
    detailSpread: 0.22,
  ),
  PetDesign(
    file: 'rock',
    body: 'body_darkB',
    arm: 'arm_darkD',
    leg: 'leg_darkE',
    detail: 'detail_dark_horn_large',
    eyes: 'eye_yellow',
    mouth: 'mouth_closed_teeth',
    nose: 'nose_brown',
    armLift: 0.30,
  ),
  PetDesign(
    file: 'neutral',
    body: 'body_yellowC',
    arm: 'arm_yellowA',
    leg: 'leg_yellowA',
    detail: 'detail_yellow_ear',
    eyes: 'eye_cute_light',
    mouth: 'mouthA',
    cyclops: true,
    detailSpread: 0.26,
  ),
];

late String partsDir;

img.Image part(String name) {
  final bytes = File('$partsDir/$name.png').readAsBytesSync();
  final decoded = img.decodePng(bytes);
  if (decoded == null) throw StateError('cannot decode $name.png');
  return decoded.convert(numChannels: 4);
}

img.Image mirrored(String name) => img.flipHorizontal(part(name));

void place(img.Image canvas, img.Image src, num x, num y) {
  img.compositeImage(canvas, src, dstX: x.round(), dstY: y.round());
}

img.Image build(PetDesign d) {
  const size = 640;
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  final body = part(d.body);
  final bx = (size - body.width) / 2;
  const by = 140.0;
  final cx = size / 2;
  final bottom = by + body.height;

  // Limbs are drawn before the body so the shoulder/hip joints hide behind
  // it. The source arm/leg images point right (a right-side limb); the left
  // side uses the mirrored image.
  final leg = part(d.leg);
  final legY = bottom - 48;
  place(canvas, leg, cx + body.width * 0.17 - leg.width * 0.40, legY);
  place(
    canvas,
    mirrored(d.leg),
    cx - body.width * 0.17 - leg.width * 0.60,
    legY,
  );

  final arm = part(d.arm);
  final armY = by + body.height * d.armLift - arm.height * 0.12;
  place(canvas, arm, bx + body.width - 34 - arm.width * 0.35, armY);
  place(canvas, mirrored(d.arm), bx + 34 - arm.width * 0.65, armY);

  // Head details sit behind the top of the body.
  final detail = part(d.detail);
  final detailY = by - detail.height + 18;
  place(
    canvas,
    detail,
    cx - body.width * d.detailSpread - detail.width / 2,
    detailY,
  );
  place(
    canvas,
    mirrored(d.detail),
    cx + body.width * d.detailSpread - detail.width / 2,
    detailY,
  );

  place(canvas, body, bx, by);

  // Face.
  final eye = part(d.eyes);
  final eyeY = by + body.height * 0.30 - eye.height / 2;
  if (d.cyclops) {
    final big = img.copyResize(
      eye,
      width: (eye.width * 1.35).round(),
      interpolation: img.Interpolation.cubic,
    );
    place(canvas, big, cx - big.width / 2, eyeY - 8);
  } else {
    place(canvas, eye, cx - body.width * 0.20 - eye.width / 2, eyeY);
    place(
      canvas,
      mirrored(d.eyes),
      cx + body.width * 0.20 - eye.width / 2,
      eyeY,
    );
  }
  if (d.nose != null) {
    final nose = part(d.nose!);
    place(
      canvas,
      nose,
      cx - nose.width / 2,
      by + body.height * 0.48 - nose.height / 2,
    );
  }
  final mouth = part(d.mouth);
  place(
    canvas,
    mouth,
    cx - mouth.width / 2,
    by + body.height * 0.64 - mouth.height / 2,
  );

  final trimmed = outline(
    shade(img.trim(canvas, mode: img.TrimMode.transparent)),
  );
  // Pad to a square so every pet scales the same way in the UI.
  final side =
      (trimmed.width > trimmed.height ? trimmed.width : trimmed.height) + 24;
  final out = img.Image(width: side, height: side, numChannels: 4);
  place(out, trimmed, (side - trimmed.width) / 2, side - trimmed.height - 8);
  return out;
}

// ------------------------------------------------------------- depth --
// Kenney's parts are flat-coloured. These passes add volume (CC0 allows
// modification): light from the top-left, shadow toward the bottom, a soft
// rim light, and a dark outline so the pet reads on any background.

/// Top-to-bottom light falloff plus a left-to-right tint, and a rim light
/// along the top-left edges.
img.Image shade(img.Image src) {
  final out = img.Image.from(src);
  final w = src.width, h = src.height;
  bool solid(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && src.getPixel(x, y).a > 40;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = src.getPixel(x, y);
      if (p.a == 0) continue;
      final ty = y / h, tx = x / w;
      // 1.12 at the top-left down to ~0.62 at the bottom-right.
      var f = 1.12 - 0.42 * ty * ty - 0.10 * tx;
      // Rim light: pixels whose upper-left neighbours are empty.
      if (!solid(x - 4, y - 4) || !solid(x, y - 5)) f += 0.22;
      // Contact shadow where parts overlap (just below a transparent gap).
      out.setPixelRgba(
        x,
        y,
        (p.r * f).clamp(0, 255).toInt(),
        (p.g * f).clamp(0, 255).toInt(),
        (p.b * f).clamp(0, 255).toInt(),
        p.a.toInt(),
      );
    }
  }
  return out;
}

/// Adds a dark outline (the sprite's own average colour, darkened) around
/// every opaque pixel.
img.Image outline(img.Image src, {int thickness = 4}) {
  const pad = 6;
  final w = src.width + pad * 2, h = src.height + pad * 2;
  var r = 0.0, g = 0.0, b = 0.0, n = 0;
  for (final p in src) {
    if (p.a < 200) continue;
    r += p.r;
    g += p.g;
    b += p.b;
    n++;
  }
  final ink = n == 0
      ? img.ColorRgba8(20, 16, 30, 255)
      : img.ColorRgba8(
          (r / n * 0.28).round(),
          (g / n * 0.28).round(),
          (b / n * 0.28).round(),
          255,
        );
  final out = img.Image(width: w, height: h, numChannels: 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var hit = false;
      for (var dy = -thickness; dy <= thickness && !hit; dy++) {
        for (var dx = -thickness; dx <= thickness && !hit; dx++) {
          if (dx * dx + dy * dy > thickness * thickness) continue;
          final sx = x - pad + dx, sy = y - pad + dy;
          if (sx >= 0 &&
              sy >= 0 &&
              sx < src.width &&
              sy < src.height &&
              src.getPixel(sx, sy).a > 60) {
            hit = true;
          }
        }
      }
      if (hit) out.setPixel(x, y, ink);
    }
  }
  img.compositeImage(out, src, dstX: pad, dstY: pad);
  return out;
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'usage: dart run tool/build_pets.dart <Monster Builder PNG/Default dir>',
    );
    exit(64);
  }
  partsDir = args.first;
  final outDir = Directory('assets/pets')..createSync(recursive: true);
  for (final design in designs) {
    final file = File('${outDir.path}/${design.file}.png');
    file.writeAsBytesSync(img.encodePng(build(design)));
    stdout.writeln('wrote ${file.path}');
  }
}
