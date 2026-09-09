import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 分区小标题（对齐原型 sec-label：13sp/muted/600）。
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(text, style: AppTypography.sectionLabel),
    );
  }
}
