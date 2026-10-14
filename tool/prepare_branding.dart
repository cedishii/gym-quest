// Builds the app logo and launcher icon images from the source crest
// (branding/Elemental Mountain Training Crest.png, the app's own artwork).
//
// Usage:
//   dart run tool/prepare_branding.dart
//   dart run flutter_launcher_icons
//
// Writes:
//   assets/branding/logo.png                     in-app logo (512 px)
//   assets/branding/icon_square.png              legacy/iOS launcher icon
//   assets/branding/icon_adaptive_foreground.png Android adaptive icon layer
import 'dart:io';

import 'package:image/image.dart' as img;

const source = 'branding/Elemental Mountain Training Crest.png';

void save(img.Image image, String path) {
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image));
  stdout.writeln('wrote $path');
}

/// [logo] scaled to [fraction] of a [side] x [side] black canvas.
img.Image onCanvas(img.Image logo, int side, double fraction) {
  final canvas = img.Image(width: side, height: side, numChannels: 4)
    ..clear(img.ColorRgba8(0, 0, 0, 255));
  final size = (side * fraction).round();
  final scaled = img.copyResize(
    logo,
    width: size,
    height: size,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    canvas,
    scaled,
    dstX: (side - size) ~/ 2,
    dstY: (side - size) ~/ 2,
  );
  return canvas;
}

void main() {
  final logo = img
      .decodePng(File(source).readAsBytesSync())!
      .convert(numChannels: 4);
  save(
    img.copyResize(logo, width: 512, interpolation: img.Interpolation.cubic),
    'assets/branding/logo.png',
  );
  // The crest touches its square's edges, so leave a little margin.
  save(onCanvas(logo, 1024, 0.94), 'assets/branding/icon_square.png');
  // Adaptive icons are masked to roughly the middle 66%, so the whole
  // crest must fit inside that.
  save(
    onCanvas(logo, 1024, 0.64),
    'assets/branding/icon_adaptive_foreground.png',
  );
}
