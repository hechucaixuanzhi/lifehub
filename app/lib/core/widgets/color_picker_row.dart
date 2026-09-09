import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// 色点选择行（解决「Study/Exercise 新增颜色硬编码无选择器」）。
class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final Color selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final c in AppPalette.choices)
          InkWell(
            onTap: () => onSelect(c),
            customBorder: const CircleBorder(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c,
                border: Border.all(
                  color: c == selected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  if (c == selected)
                    BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6),
                ],
              ),
              child: c == selected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ),
      ],
    );
  }
}
