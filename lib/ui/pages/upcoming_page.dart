import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/birthday_calculator.dart';
import '../../core/formatters.dart';
import '../../core/tips.dart';
import '../../models/app_settings.dart';
import '../../state/contact_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/contact_tiles.dart';
import 'tips_page.dart';

/// 「即将到来」首页。
class UpcomingPage extends StatelessWidget {
  const UpcomingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ContactController controller = context.watch<ContactController>();

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<UpcomingGroup> groups = controller.upcomingGroups;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.syncReminders,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: <Widget>[
              _Header(controller: controller),
              _TipCard(controller: controller),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (controller.contacts.isEmpty)
                      const EmptyState(
                        icon: Icons.cake_outlined,
                        title: '还没有联系人',
                        message:
                            '把家人朋友的生日记下来，\n生日前 3 天我会提醒你。\n\n'
                            '点右下角「添加」开始，\n或到「联系人」页用文本一次性导入。',
                      )
                    else if (groups.isEmpty)
                      const EmptyState(
                        icon: Icons.event_busy_outlined,
                        title: '还没有人生日',
                        message: '给联系人补上生日，就能看到倒计时了。',
                      )
                    else
                      for (final UpcomingGroup group in groups) ...<Widget>[
                        SectionHeader(
                          title: group.title,
                          subtitle: group.subtitle,
                        ),
                        for (final UpcomingBirthday item in group.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: UpcomingTile(
                              item: item,
                              onTap: () =>
                                  openContactDetail(context, item.contact.id),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // 每个页面的 FAB 都要有独立的 heroTag：底部导航用 IndexedStack 同时保留
        // 所有页面，默认 tag 相同会导致路由切换时 Hero 冲突而报错。
        heroTag: 'fab-upcoming',
        onPressed: () => openContactEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加'),
      ),
    );
  }
}

/// 选一条当前可见的提示。
///
/// 优先展示当天固定的那一条；如果它被「不再提示」了，
/// 就换成第一条还没被隐藏的；全都被隐藏时返回 null。
AppTip? _visibleTip(AppSettings settings, DateTime now) {
  final AppTip today = tipForDate(now);
  if (!settings.isTipHidden(today.id)) return today;
  for (final AppTip tip in kAppTips) {
    if (!settings.isTipHidden(tip.id)) return tip;
  }
  return null;
}

/// 首页顶部的「使用提示」卡片。
///
/// 点击整张卡片进入「使用提示」页；右侧的小叉只隐藏当前这一条，
/// 隐藏后卡片会自动换成下一条没被隐藏的提示，全部隐藏后整张卡片消失。
class _TipCard extends StatelessWidget {
  const _TipCard({required this.controller});

  final ContactController controller;

  @override
  Widget build(BuildContext context) {
    final SettingsController settingsController = context
        .watch<SettingsController>();
    final AppSettings settings = settingsController.settings;

    // 用户在设置里关掉了提示卡片，或者所有提示都被隐藏了，就什么都不显示。
    if (!settings.showTipCard) return const SizedBox.shrink();
    final AppTip? tip = _visibleTip(settings, controller.now);
    if (tip == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: AppCard(
        key: const Key('homeTipCard'),
        color: AppColors.brandSoft,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => const TipsPage(),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tip.icon, size: 18, color: AppColors.brand),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '使用提示 · ${tip.title}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                // 只隐藏这一条，不影响提示卡片的总开关。
                IconButton(
                  key: const Key('dismissTipButton'),
                  tooltip: '不再提示',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  iconSize: 18,
                  onPressed: () => settingsController.hideTip(tip.id),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              tip.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                '点击卡片查看全部提示 ›',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部渐变头图：日期 + 概览。
class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final ContactController controller;

  @override
  Widget build(BuildContext context) {
    final DateTime now = controller.now;
    final int today = controller.todayBirthdays.length;
    final int week = controller.upcomingWithinWeek.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.brand, AppColors.brandLight],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.cake_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 8),
              const Text(
                '生日管家',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '共 ${controller.totalContacts} 位',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatFullDateWithWeekday(now),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              _StatPill(value: '$today', label: '今天生日', highlight: today > 0),
              const SizedBox(width: 10),
              _StatPill(value: '$week', label: '7 天内'),
              const SizedBox(width: 10),
              _StatPill(
                value: '${controller.upcomingWithinMonthCount}',
                label: '30 天内',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: highlight
              ? Colors.white
              : Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                color: highlight ? AppColors.brand : Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: highlight
                    ? AppColors.brandDark
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
