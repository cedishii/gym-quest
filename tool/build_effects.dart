// Prepares the battle effect textures.
//
// Sources (both CC0):
//  * Kenney "Smoke Particles" (https://kenney.nl/assets/smoke-particles):
//    explosion, flash and white puff textures, used as particles.
//  * Sinestesia "2D Explosion Animations #2"
//    (https://opengameart.org/node/74923): frame-by-frame explosion atlases
//    (8 x 8 frames), used for ultimate moves.
//
// Usage:
//   dart run tool/build_effects.dart <kenney_smoke-particles/PNG> <Free Explosion Animations 2/Half Sized>
//
// Writes assets/fx/burst/*.png and assets/fx/anim/<name>/NN.png.
import 'dart:io';

import 'package:image/image.dart' as img;

img.Image load(String path) =>
    img.decodePng(File(path).readAsBytesSync())!.convert(numChannels: 4);

void save(img.Image image, String path) {
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image));
}

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'usage: dart run tool/build_effects.dart <Kenney PNG dir> <Sinestesia Half Sized dir>',
    );
    exit(64);
  }
  final kenney = args[0];
  final atlases = args[1];

  // Particle textures (variants, not animations).
  void textures(
    String folder,
    String prefix,
    String name,
    int count,
    int width,
  ) {
    for (var i = 0; i < count; i++) {
      final src = load(
        '$kenney/$folder/$prefix${i.toString().padLeft(2, '0')}.png',
      );
      save(
        img.copyResize(
          src,
          width: width,
          interpolation: img.Interpolation.average,
        ),
        'assets/fx/burst/${name}_$i.png',
      );
    }
  }

  textures('Explosion', 'explosion', 'explosion', 6, 192);
  textures('Flash', 'flash', 'flash', 4, 192);
  textures('White puff', 'whitePuff', 'puff', 8, 160);

  // Frame animations: every second frame of the 8x8 atlas, centre-cropped.
  void animation(String atlas, String name) {
    final sheet = load('$atlases/$atlas');
    final frame = sheet.width ~/ 8;
    final crop = (frame * 0.75).round();
    var out = 0;
    for (var i = 0; i < 64; i += 2) {
      final x = (i % 8) * frame + (frame - crop) ~/ 2;
      final y = (i ~/ 8) * frame + (frame - crop) ~/ 2;
      final cell = img.copyCrop(sheet, x: x, y: y, width: crop, height: crop);
      save(
        img.copyResize(
          cell,
          width: 160,
          interpolation: img.Interpolation.average,
        ),
        'assets/fx/anim/$name/${(out++).toString().padLeft(2, '0')}.png',
      );
    }
    stdout.writeln('wrote $out frames for $name');
  }

  animation('1.png', 'blast');
  animation('3.png', 'nova');
}
