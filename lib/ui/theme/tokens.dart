import 'package:flutter/material.dart';

import '../../domain/combat/element.dart';
import '../../domain/inventory/items.dart';

/// Design tokens: one dark "night adventure" palette used everywhere.
class Palette {
  const Palette._();

  static const background = Color(0xFF12121F);
  static const backgroundDeep = Color(0xFF0B0B16);
  static const surface = Color(0xFF1C1C30);
  static const surfaceHigh = Color(0xFF26263F);
  static const border = Color(0xFF34345A);
  static const text = Color(0xFFF2F0FF);
  static const textDim = Color(0xFFA9A6C9);
  static const textFaint = Color(0xFF6E6B91);

  static const gold = Color(0xFFFFC94A);
  static const goldDeep = Color(0xFFE59A1C);
  static const violet = Color(0xFF7C5CFF);
  static const xp = Color(0xFF59C3FF);
  static const hp = Color(0xFF4ADE80);
  static const danger = Color(0xFFFF5A6E);
  static const warning = Color(0xFFFFA94D);

  static const protein = Color(0xFFFF7A9C);
  static const carbs = Color(0xFF59C3FF);
  static const fat = Color(0xFFFFC94A);

  static Color element(PetElement e) => switch (e) {
    PetElement.fire => const Color(0xFFFF6B3D),
    PetElement.water => const Color(0xFF3DB7FF),
    PetElement.leaf => const Color(0xFF5BD66A),
    PetElement.rock => const Color(0xFFC9A26B),
    PetElement.neutral => const Color(0xFFC7C2E8),
  };

  /// Two-stop background gradient for an element's region/battle backdrop.
  static List<Color> backdrop(PetElement e) => switch (e) {
    PetElement.fire => const [Color(0xFF3A1210), Color(0xFF14090F)],
    PetElement.water => const [Color(0xFF0E2A44), Color(0xFF0A1022)],
    PetElement.leaf => const [Color(0xFF123522), Color(0xFF0A1712)],
    PetElement.rock => const [Color(0xFF3A2E1E), Color(0xFF15110C)],
    PetElement.neutral => const [Color(0xFF2B2550), Color(0xFF100E22)],
  };

  static Color rarity(Rarity r) => switch (r) {
    Rarity.common => const Color(0xFFB8B5D6),
    Rarity.rare => const Color(0xFF59C3FF),
    Rarity.epic => const Color(0xFFC77DFF),
  };
}

class Space {
  const Space._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class Radii {
  const Radii._();

  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
}

const fontFamily = 'Fredoka';
