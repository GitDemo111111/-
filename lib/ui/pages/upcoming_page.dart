import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/birthday_calculator.dart';
import '../../core/formatters.dart';
import '../../state/contact_controller.dart';
import '../../theme/app_theme.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/contact_tiles.dart';

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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (controller.contacts.isEmpty)
                      EmptyState(
                        icon: Icons.cake_outlined,
                        title: '还没有联系人',
                        message: '把家人朋友的生日记下来，\n生日前 3 天我会提醒你。',
                        action: FilledButton.icon(
                          onPressed: () => openContactEditor(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('添加第一位联系人'),
                        ),
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
