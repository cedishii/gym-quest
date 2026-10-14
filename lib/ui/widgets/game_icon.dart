import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/combat/element.dart';
import '../theme/tokens.dart';

/// A tinted game-icons.net icon from assets/icons (see tool/fetch_icons.py).
class GameIcon extends StatelessWidget {
  const GameIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color = Palette.text,
  });

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

String elementIcon(PetElement e) => switch (e) {
  PetElement.fire => 'el-fire',
  PetElement.water => 'el-water',
  PetElement.leaf => 'el-leaf',
  PetElement.rock => 'el-rock',
  PetElement.neutral => 'el-neutral',
};

/// Small element tag: icon + name in the element's colour.
class ElementBadge extends StatelessWidget {
  const ElementBadge(this.element, {super.key, this.compact = false});

  final PetElement element;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Palette.element(element);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(elementIcon(element), size: compact ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            element.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
