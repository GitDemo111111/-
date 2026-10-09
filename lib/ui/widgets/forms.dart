import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 可选中的胶囊标签。
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? Colors.white : AppColors.textPrimary;
    final BorderRadius radius = BorderRadius.circular(AppSizes.chipRadius);
    return Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.brand : AppColors.surfaceAlt,
        borderRadius: radius,
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.outline,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 11 : 14,
              vertical: dense ? 6 : 9,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: dense ? 14 : 16, color: foreground),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: dense ? 12.5 : 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 爱好 / 标签选择器：内置选项 + 自定义添加。
class TagSelector extends StatelessWidget {
  const TagSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.onAdd,
    this.addLabel = '自定义',
    this.addKey,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  /// 添加自定义标签；为 `null` 时不显示添加按钮。
  final ValueChanged<String>? onAdd;

  /// 弹窗标题里用的名字，例如「爱好」。
  final String addLabel;

  /// 添加按钮的 key，方便测试精确定位（页面上可能有多个选择器）。
  final Key? addKey;

  @override
  Widget build(BuildContext context) {
    // 已选中的排前面，方便一眼看到自己选了什么。
    final List<String> ordered = <String>[
      ...options.where(selected.contains),
      ...options.where((String e) => !selected.contains(e)),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String option in ordered)
          SelectableChip(
            label: option,
            selected: selected.contains(option),
            onTap: () => onToggle(option),
          ),
        if (onAdd != null)
          SelectableChip(
            key: addKey,
            label: '自定义',
            selected: false,
            icon: Icons.add_rounded,
            onTap: () async {
              final String? value = await showTextInputDialog(
                context,
                title: '添加$addLabel',
                hint: '例如：攀岩',
              );
              if (value != null && value.trim().isNotEmpty) {
                onAdd!(value.trim());
              }
            },
          ),
      ],
    );
  }
}

/// 详情页里的一行信息。
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 18, color: AppColors.brand),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 62,
              child: Text(
                label,
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

/// 简单的文本输入弹窗。
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String? hint,
  String? initial,
  String confirmLabel = '确定',
}) {
  final TextEditingController controller = TextEditingController(
    text: initial ?? '',
  );
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (String value) =>
            Navigator.of(dialogContext).pop(value.trim()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
