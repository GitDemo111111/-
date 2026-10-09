import 'package:flutter/material.dart';

import '../models/relationship.dart';

/// 关系/身份对应的图标，只属于 UI 层（模型层保持纯 Dart）。
IconData relationshipIcon(Relationship? relationship) {
  switch (relationship) {
    case Relationship.family:
      return Icons.home_rounded;
    case Relationship.relative:
      return Icons.diversity_3_rounded;
    case Relationship.friend:
      return Icons.emoji_people_rounded;
    case Relationship.colleague:
      return Icons.work_rounded;
    case Relationship.classmate:
      return Icons.school_rounded;
    case Relationship.partner:
      return Icons.favorite_rounded;
    case Relationship.client:
      return Icons.business_center_rounded;
    case Relationship.neighbor:
      return Icons.apartment_rounded;
    case Relationship.teacher:
      return Icons.menu_book_rounded;
    case Relationship.other:
      return Icons.person_rounded;
    case null:
      return Icons.person_outline_rounded;
  }
}

/// 根据生日远近返回一个「倒计时」的颜色。
Color countdownColor(int daysUntil, ThemeData theme) {
  if (daysUntil == 0) return theme.colorScheme.error;
  if (daysUntil <= 3) return const Color(0xFFFF8A3D);
  if (daysUntil <= 7) return theme.colorScheme.secondary;
  return theme.colorScheme.primary;
}
