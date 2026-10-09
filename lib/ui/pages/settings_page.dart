import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_settings.dart';
import '../../services/backup_service.dart';
import '../../state/contact_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/forms.dart';

/// 应用的版本号（与 pubspec.yaml 保持一致）。
const String kAppVersion = '1.0.0';

/// 设置页。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController settingsController = context
        .watch<SettingsController>();
    final ContactController controller = context.watch<ContactController>();
    final AppSettings settings = settingsController.settings;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: <Widget>[
            const SectionHeader(title: '设置', subtitle: '提醒、显示与数据'),
            const SizedBox(height: 4),
            _Card(
              title: '提醒',
              children: <Widget>[
                SwitchListTile.adaptive(
                  key: const Key('globalNotificationSwitch'),
                  contentPadding: EdgeInsets.zero,
                  value: settings.notificationsEnabled,
                  onChanged: (bool value) =>
                      _toggleNotifications(context, controller, value),
                  title: const Text(
                    '开启生日提醒',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    '关闭后不再发送任何通知',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
                const Divider(height: 20),
                _SliderRow(
                  key: const Key('defaultDaysBeforeSlider'),
                  label: '默认提前',
                  valueLabel: settings.defaultReminder.daysBefore == 0
                      ? '当天'
                      : '${settings.defaultReminder.daysBefore} 天',
                  value: settings.defaultReminder.daysBefore.toDouble(),
                  onChanged: (double value) => settingsController.update(
                    settings.copyWith(
                      defaultReminder: settings.defaultReminder.copyWith(
                        daysBefore: value.round(),
                      ),
                    ),
                  ),
                ),
                SwitchListTile.adaptive(
                  key: const Key('defaultOnDaySwitch'),
                  contentPadding: EdgeInsets.zero,
                  value: settings.defaultReminder.notifyOnDay,
                  onChanged: (bool value) => settingsController.update(
                    settings.copyWith(
                      defaultReminder: settings.defaultReminder.copyWith(
                        notifyOnDay: value,
                      ),
                    ),
                  ),
                  title: const Text(
                    '生日当天也提醒',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () =>
                      _pickDefaultTime(context, settingsController, settings),
                  leading: const Icon(
                    Icons.access_time_rounded,
                    color: AppColors.brand,
                  ),
                  title: const Text(
                    '默认提醒时间',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Text(
                    settings.defaultReminder.timeLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brand,
                    ),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settings.notificationsEnabled
                            ? '已为 ${controller.scheduledReminders.length} 次生日排好提醒'
                            : '提醒已关闭',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Card(
              title: '显示',
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    '列表排序方式',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final ContactSortMode mode in ContactSortMode.values)
                      SelectableChip(
                        key: Key('sortMode-${mode.name}'),
                        label: mode.label,
                        dense: true,
                        selected: settings.sortMode == mode,
                        onTap: () => settingsController.update(
                          settings.copyWith(sortMode: mode),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  key: const Key('showLunarSwitch'),
                  contentPadding: EdgeInsets.zero,
                  value: settings.showLunarInfo,
                  onChanged: (bool value) => settingsController.update(
                    settings.copyWith(showLunarInfo: value),
                  ),
                  title: const Text(
                    '显示农历信息',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SwitchListTile.adaptive(
                  key: const Key('groupUpcomingSwitch'),
                  contentPadding: EdgeInsets.zero,
                  value: settings.groupUpcoming,
                  onChanged: (bool value) => settingsController.update(
                    settings.copyWith(groupUpcoming: value),
                  ),
                  title: const Text(
                    '「即将到来」按时间分组',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Card(
              title: '数据',
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.insights_rounded,
                      size: 18,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '共 ${controller.totalContacts} 位联系人，'
                      '${controller.contactsWithBirthday} 位有生日',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('exportButton'),
                        onPressed: () => _showExportDialog(
                          context,
                          controller,
                          settingsController,
                        ),
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text('导出备份'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('importButton'),
                        onPressed: () => _showImportDialog(context, controller),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('导入备份'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  key: const Key('clearAllButton'),
                  onPressed: controller.contacts.isEmpty
                      ? null
                      : () => _clearAll(context, controller),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('清空所有联系人'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Card(
              title: '关于',
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.cake_rounded, color: AppColors.brand, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '生日管家 v$kAppVersion',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '把重要的人的生日和关键信息记下来，'
                  '默认在生日前 3 天和生日当天提醒你。'
                  '数据全部保存在手机本地，不会上传。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (kIsWeb) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.brandDark,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Web 预览版：数据保存在浏览器本地（localStorage），'
                            '换浏览器或清缓存会丢失；'
                            '生日提醒需要安装手机版才会真正弹出通知。',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: AppColors.brandDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleNotifications(
    BuildContext context,
    ContactController controller,
    bool value,
  ) async {
    final SettingsController settingsController = context
        .read<SettingsController>();
    await settingsController.patch(notificationsEnabled: value);
    if (!value || !context.mounted) return;
    final bool granted = await controller.requestNotificationPermission();
    if (!granted && context.mounted) {
      showAppSnackBar(context, '没有拿到通知权限，请到系统设置里为「生日管家」开启通知');
    }
  }

  Future<void> _pickDefaultTime(
    BuildContext context,
    SettingsController settingsController,
    AppSettings settings,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.defaultReminder.hour,
        minute: settings.defaultReminder.minute,
      ),
      helpText: '默认提醒时间',
    );
    if (picked == null) return;
    await settingsController.update(
      settings.copyWith(
        defaultReminder: settings.defaultReminder.copyWith(
          hour: picked.hour,
          minute: picked.minute,
        ),
      ),
    );
  }

  Future<void> _showExportDialog(
    BuildContext context,
    ContactController controller,
    SettingsController settingsController,
  ) async {
    final String json = const BackupService().exportToJson(
      contacts: controller.contacts,
      settings: settingsController.settings,
      now: controller.now,
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('导出备份'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            key: const Key('copyBackupButton'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              if (context.mounted) {
                showAppSnackBar(context, '备份内容已复制到剪贴板');
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('复制'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportDialog(
    BuildContext context,
    ContactController controller,
  ) async {
    final _ImportResult? result = await showDialog<_ImportResult>(
      context: context,
      builder: (BuildContext _) => const _ImportDialog(),
    );
    if (result == null || !context.mounted) return;

    if (result.replace) {
      await controller.replaceAll(result.payload.contacts);
    } else {
      await controller.mergeAll(result.payload.contacts);
    }
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      '已${result.replace ? '覆盖' : '合并'}导入 ${result.payload.contacts.length} 位联系人',
    );
  }

  Future<void> _clearAll(
    BuildContext context,
    ContactController controller,
  ) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: '清空所有联系人',
      message: '这会删除全部联系人及其提醒，且无法恢复。建议先导出备份。',
      confirmLabel: '清空',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await controller.clearAll();
    if (!context.mounted) return;
    showAppSnackBar(context, '已清空所有联系人');
  }
}

class _ImportResult {
  const _ImportResult({required this.payload, required this.replace});

  final BackupPayload payload;
  final bool replace;
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final TextEditingController _text = TextEditingController();
  BackupPayload? _payload;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _parse() {
    try {
      final BackupPayload payload = const BackupService().parse(_text.text);
      setState(() {
        _payload = payload;
        _error = null;
      });
    } on FormatException catch (error) {
      setState(() {
        _payload = null;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final BackupPayload? payload = _payload;
    return AlertDialog(
      title: const Text('导入备份'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '把之前导出的 JSON 内容粘贴到下面',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('importTextField'),
              controller: _text,
              maxLines: 6,
              minLines: 4,
              decoration: const InputDecoration(
                hintText: '{"format":"birthdayKeeper", ...}',
              ),
              onChanged: (String _) {
                // 必须每次都 setState：否则「解析」按钮的可用状态不会刷新，
                // 用户粘贴完内容后按钮仍然是灰的。
                setState(() {
                  _payload = null;
                  _error = null;
                });
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            if (payload != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '解析成功：${payload.contacts.length} 位联系人',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        if (payload == null)
          FilledButton(
            key: const Key('parseBackupButton'),
            onPressed: _text.text.trim().isEmpty ? null : _parse,
            child: const Text('解析'),
          )
        else ...<Widget>[
          TextButton(
            key: const Key('mergeImportButton'),
            onPressed: () => Navigator.of(
              context,
            ).pop(_ImportResult(payload: payload, replace: false)),
            child: const Text('合并'),
          ),
          FilledButton(
            key: const Key('replaceImportButton'),
            onPressed: () => Navigator.of(
              context,
            ).pop(_ImportResult(payload: payload, replace: true)),
            child: const Text('覆盖'),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.outline),
      ),
      // ListTile / SwitchListTile 需要最近的 Material 祖先来绘制水波纹和背景。
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 30,
            divisions: 30,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            valueLabel,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.brand,
            ),
          ),
        ),
      ],
    );
  }
}
