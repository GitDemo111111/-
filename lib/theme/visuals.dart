import 'package:flutter/material.dart';

import '../models/relationship.dart';

/// 关系/身份对应的图标，只属于 UI 层（模型层保持纯 Dart）。
IconData relationshipIcon(Relationship? relationship) {
  if (relationship == null) return Icons.person_outline_rounded;
  // 同组内再给几个显眼的角色单独配图标。
  switch (relationship) {
    case Relationship.father:
    case Relationship.mother:
      return Icons.family_restroom_rounded;
    case Relationship.grandpa:
    case Relationship.grandma:
    case Relationship.maternalGrandpa:
    case Relationship.maternalGrandma:
      return Icons.elderly_rounded;
    case Relationship.husband:
    case Relationship.wife:
      return Icons.favorite_rounded;
    case Relationship.son:
    case Relationship.daughter:
      return Icons.child_care_rounded;
    case Relationship.elderBrother:
    case Relationship.elderSister:
    case Relationship.youngerBrother:
    case Relationship.youngerSister:
      return Icons.people_alt_rounded;
    case Relationship.bestie:
      return Icons.volunteer_activism_rounded;
    case Relationship.buddy:
      return Icons.sports_esports_rounded;
    case Relationship.boss:
      return Icons.badge_rounded;
    default:
      break;
  }
  switch (relationship.group) {
    case RelationshipGroup.family:
      return Icons.home_rounded;
    case RelationshipGroup.relative:
      return Icons.diversity_3_rounded;
    case RelationshipGroup.friend:
      return Icons.emoji_people_rounded;
    case RelationshipGroup.colleague:
      return Icons.work_rounded;
    case RelationshipGroup.classmate:
      return Icons.school_rounded;
    case RelationshipGroup.other:
      switch (relationship) {
        case Relationship.partner:
          return Icons.favorite_border_rounded;
        case Relationship.client:
          return Icons.business_center_rounded;
        case Relationship.neighbor:
          return Icons.apartment_rounded;
        case Relationship.teacher:
          return Icons.menu_book_rounded;
        default:
          return Icons.person_rounded;
      }
  }
}

/// 关系分组对应的图标（筛选条用）。
IconData relationshipGroupIcon(RelationshipGroup group) {
  switch (group) {
    case RelationshipGroup.family:
      return Icons.home_rounded;
    case RelationshipGroup.relative:
      return Icons.diversity_3_rounded;
    case RelationshipGroup.friend:
      return Icons.emoji_people_rounded;
    case RelationshipGroup.colleague:
      return Icons.work_rounded;
    case RelationshipGroup.classmate:
      return Icons.school_rounded;
    case RelationshipGroup.other:
      return Icons.person_rounded;
  }
}

/// 根据生日远近返回一个「倒计时」的颜色。
Color countdownColor(int daysUntil, ThemeData theme) {
  if (daysUntil == 0) return theme.colorScheme.error;
  if (daysUntil <= 3) return const Color(0xFFFF8A3D);
  if (daysUntil <= 7) return theme.colorScheme.secondary;
  return theme.colorScheme.primary;
}
