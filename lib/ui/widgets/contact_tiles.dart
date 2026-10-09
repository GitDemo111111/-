import 'package:flutter/material.dart';

import '../../core/birthday_calculator.dart';
import '../../core/formatters.dart';
import '../../models/birthday.dart';
import '../../models/contact.dart';
import '../../theme/app_theme.dart';
import '../../theme/visuals.dart';
import 'common.dart';
import 'contact_avatar.dart';

/// 倒计时小标签，例如「3天后」。
class CountdownBadge extends StatelessWidget {
  const CountdownBadge({
    super.key,
    required this.daysUntil,
    this.dense = false,
  });

  final int daysUntil;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = countdownColor(daysUntil, theme);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppSizes.chipRadius),
      ),
      child: Text(
        relativeDayLabel(daysUntil),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: dense ? 11.5 : 12.5,
        ),
      ),
    );
  }
}

/// 「即将到来」列表里的卡片。
class UpcomingTile extends StatelessWidget {
  const UpcomingTile({super.key, required this.item, required this.onTap});

  final UpcomingBirthday item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Contact contact = item.contact;
    final bool isToday = item.isToday;

    return AppCard(
      onTap: onTap,
      color: isToday ? const Color(0xFFFFF1F5) : null,
      borderColor: isToday ? AppColors.celebrate.withValues(alpha: 0.4) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: <Widget>[
          ContactAvatar(contact: contact, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (contact.favorite)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.star_rounded,
                          size: 17,
                          color: Color(0xFFFFB020),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _subtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CountdownBadge(daysUntil: item.daysUntil),
              if (item.turningAge != null) ...<Widget>[
                const SizedBox(height: 5),
                Text(
                  ageLabel(item.turningAge!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    final List<String> parts = <String>[
      formatMonthDay(item.date),
      if (item.contact.relationshipLabel != null)
        item.contact.relationshipLabel!,
      item.contact.birthday?.isLunar == true ? '农历' : '',
    ];
    return parts.where((String e) => e.isNotEmpty).join(' · ');
  }
}

/// 联系人列表里的行。
class ContactTile extends StatelessWidget {
  const ContactTile({
    super.key,
    required this.contact,
    required this.onTap,
    this.daysUntil,
    this.turningAge,
  });

  final Contact contact;
  final VoidCallback onTap;
  final int? daysUntil;
  final int? turningAge;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? relation = contact.relationshipLabel;
    final birthday = contact.birthday;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          ContactAvatar(contact: contact, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (contact.favorite)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFFFB020),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _subtitle(relation, birthday),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (daysUntil != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CountdownBadge(daysUntil: daysUntil!, dense: true),
                if (turningAge != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      ageLabel(turningAge!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            )
          else
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    );
  }

  String _subtitle(String? relation, Birthday? birthday) {
    final List<String> parts = <String>[
      ?relation,
      ?birthday?.shortLabel,
      if (contact.hobbies.isNotEmpty) contact.hobbies.take(2).join('/'),
    ];
    if (parts.isEmpty) return '还没有填写生日';
    return parts.join(' · ');
  }
}
