import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/tips.dart';
import '../../models/app_settings.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

/// 「使用提示」页。
///
/// 可以在这里查看全部提示、控制首页是否显示提示卡片，
/// 也可以逐条「不再提示」，之后在设置里随时恢复。
class TipsPage extends StatelessWidget {
  const TipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController settingsController = context
        .watch<SettingsController>();
    final AppSettings settings = settingsController.settings;
    final int hiddenCount = settings.hiddenTipIds.length;

    return Scaffold(
      appBar: AppBar(title: const Text('使用提示')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            // 首页提示卡片的总开关。
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SwitchListTile.adaptive(
                key: const Key('showTipCardSwitch'),
                contentPadding: EdgeInsets.zero,
                value: settings.showTipCard,
                onChanged: (bool value) =>
                    settingsController.setShowTipCard(value),
                title: const Text(
                  '在首页显示提示卡片',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  '关掉后，「即将到来」页顶部不再出现使用提示',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SectionHeader(
              title: '全部提示',
              subtitle: hiddenCount == 0
                  ? '共 ${kAppTips.length} 条，点「不再提示」可以永久隐藏'
                  : '共 ${kAppTips.length} 条，已隐藏 $hiddenCount 条',
              trailing: hiddenCount == 0
                  ? null
                  : TextButton.icon(
                      key: const Key('restoreAllTipsButton'),
                      onPressed: settingsController.restoreHiddenTips,
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('恢复全部提示'),
                    ),
            ),
            for (final AppTip tip in kAppTips)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TipCard(
                  tip: tip,
                  hidden: settings.isTipHidden(tip.id),
                  onHide: () => settingsController.hideTip(tip.id),
                  onRestore: () =>
                      _restoreTip(settingsController, settings, tip.id),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 只恢复一条提示，其余保持隐藏。
  Future<void> _restoreTip(
    SettingsController settingsController,
    AppSettings settings,
    String id,
  ) {
    return settingsController.update(
      settings.copyWith(
        hiddenTipIds: settings.hiddenTipIds
            .where((String hiddenId) => hiddenId != id)
            .toList(),
      ),
    );
  }
}

/// 单条提示：图标 + 标题 + 正文 + 「不再提示 / 恢复」。
class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.tip,
    required this.hidden,
    required this.onHide,
    required this.onRestore,
  });

  final AppTip tip;
  final bool hidden;
  final VoidCallback onHide;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppCard(
      key: Key('tipCard-${tip.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: hidden ? AppColors.surfaceAlt : AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  tip.icon,
                  size: 20,
                  color: hidden ? AppColors.textSecondary : AppColors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    tip.title,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: hidden
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (hidden)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppSizes.chipRadius),
                  ),
                  child: const Text(
                    '已隐藏',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tip.body,
            style: text.bodyMedium?.copyWith(
              fontSize: 13,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: hidden
                ? TextButton.icon(
                    key: Key('restoreTip-${tip.id}'),
                    onPressed: onRestore,
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: const Text('恢复'),
                  )
                : TextButton.icon(
                    key: Key('hideTip-${tip.id}'),
                    onPressed: onHide,
                    icon: const Icon(Icons.visibility_off_outlined, size: 18),
                    label: const Text('不再提示'),
                  ),
          ),
        ],
      ),
    );
  }
}
