import 'package:flutter/material.dart';

import '../../core/astrology.dart';
import '../../core/birthday_calculator.dart';
import '../../models/birthday.dart';
import '../../theme/app_theme.dart';

/// 由生日**自动推导**出来的信息：星座、生肖、农历。
///
/// 用户只需要填生日，其它都不用管。
class BirthdayFacts extends StatelessWidget {
  const BirthdayFacts({
    super.key,
    required this.birthday,
    required this.calculator,
    this.now,
    this.dense = true,
  });

  final Birthday birthday;
  final BirthdayCalculator calculator;

  /// 参考时间（不传就用当前时间）。测试里可以固定。
  final DateTime? now;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final DateTime reference = now ?? DateTime.now();
    final BirthdayOccurrence? occurrence = calculator.nextOccurrence(
      birthday,
      reference,
    );
    final List<_Fact> facts = <_Fact>[];

    if (occurrence != null) {
      facts.add(
        _Fact(
          Icons.auto_awesome_rounded,
          '星座',
          constellationOf(occurrence.date.month, occurrence.date.day),
        ),
      );
    }
    if (birthday.year != null) {
      facts.add(
        _Fact(Icons.pets_rounded, '生肖', '属${chineseZodiacOf(birthday.year!)}'),
      );
    }
    if (birthday.isLunar) {
      facts.add(_Fact(Icons.nightlight_round, '农历', birthday.shortLabel));
    } else if (occurrence != null) {
      final lunar = calculator.lunarDateOf(occurrence.date);
      if (lunar != null) {
        facts.add(_Fact(Icons.nightlight_round, '农历', lunar.label));
      }
    }

    if (facts.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final _Fact fact in facts) _FactChip(fact: fact, dense: dense),
      ],
    );
  }
}

class _Fact {
  const _Fact(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.fact, required this.dense});

  final _Fact fact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 12,
        vertical: dense ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(AppSizes.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(fact.icon, size: dense ? 14 : 16, color: AppColors.brandDark),
          const SizedBox(width: 5),
          Text(
            fact.label,
            style: TextStyle(
              fontSize: dense ? 11.5 : 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            fact.value,
            style: TextStyle(
              fontSize: dense ? 12.5 : 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.brandDark,
            ),
          ),
        ],
      ),
    );
  }
}
