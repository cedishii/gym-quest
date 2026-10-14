// Trims and downsizes the anime portraits used for gym leaders and trainers.
//
// Source: "Anime Girl and Boy Portraits" by stevenburrow, CC0
// https://opengameart.org/content/anime-girl-and-boy-portraits
//
// Usage:
//   dart run tool/prepare_leaders.dart <AllAnime dir with Sample1..8.png>
import 'dart:io';

import 'package:image/image.dart' as img;

/// Output name -> source sample number. Leaders are matched to an element
/// by their colours; the remaining portraits are regular trainers.
const portraits = {
  'leader_fire': 4,
  'leader_water': 7,
  'leader_leaf': 5,
  'leader_rock': 8,
  'leader_neutral': 1,
  'trainer_a': 2,
  'trainer_b': 3,
  'trainer_c': 6,
};

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/prepare_leaders.dart <AllAnime dir>');
    exit(64);
  }
  final outDir = Directory('assets/leaders')..createSync(recursive: true);
  for (final entry in portraits.entries) {
    final source = File('${args.first}/Sample${entry.value}.png');
    final decoded = img.decodePng(source.readAsBytesSync())!;
    final trimmed = img.trim(decoded, mode: img.TrimMode.transparent);
    final resized = img.copyResize(
      trimmed,
      height: 560,
      interpolation: img.Interpolation.cubic,
    );
    File('${outDir.path}/${entry.key}.png')
        .writeAsBytesSync(img.encodePng(resized));
    stdout.writeln('wrote ${entry.key}.png');
  }
}
